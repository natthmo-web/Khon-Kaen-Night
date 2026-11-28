import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/glass.dart';
import '../../l10n/generated/app_localizations.dart';
import 'auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.from});

  /// Where to go after signing in.
  final String? from;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _message;
  bool _isError = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit(AppLocalizations l) async {
    final demo = ref.read(demoModeProvider);
    final email = _email.text.trim();
    if (!email.contains('@')) return _fail(l.errRequired);
    if (!demo && _password.text.length < 8) return _fail(l.passwordShort);
    if (_signUp && _name.text.trim().isEmpty) return _fail(l.errRequired);

    setState(() { _busy = true; _message = null; });
    final auth = ref.read(authControllerProvider.notifier);
    final code = _signUp
        ? await auth.signUp(email: email, password: _password.text, fullName: _name.text.trim())
        : await auth.signIn(email: email, password: _password.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (code == null) {
      context.go(widget.from ?? '/');
      return;
    }
    setState(() {
      _isError = code != 'check_email';
      _message = switch (code) {
        'invalid_credentials' => l.authInvalid,
        'check_email' => l.authCheckEmail,
        _ => l.errorLoading,
      };
    });
  }

  void _fail(String text) => setState(() { _isError = true; _message = text; });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final demo = ref.watch(demoModeProvider);
    return Scaffold(
      appBar: AppBar(
        leading: GlassIconButton(
          icon: Icons.arrow_back,
          label: l.backLabel,
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(_signUp ? l.signUp : l.signIn, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          if (demo) ...[
            Text(l.authDemoHint, style: const TextStyle(color: AppColors.gold, height: 1.45)),
            const SizedBox(height: 16),
          ],
          if (_signUp) ...[
            GlassTextField(controller: _name, label: l.fullName),
            const SizedBox(height: 12),
          ],
          GlassTextField(controller: _email, label: l.email, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 12),
          GlassTextField(controller: _password, label: l.password, obscureText: true),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!, style: TextStyle(color: _isError ? AppColors.error : AppColors.gold, height: 1.45)),
          ],
          const SizedBox(height: 20),
          GlassButton(label: _signUp ? l.signUp : l.signIn, loading: _busy, onPressed: () => _submit(l)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() { _signUp = !_signUp; _message = null; }),
            child: Text(_signUp ? l.haveAccount : l.noAccount),
          ),
        ]),
      ),
    );
  }
}
