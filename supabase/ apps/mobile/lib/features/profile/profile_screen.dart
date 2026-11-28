import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/glass.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../saved/local_kit.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final user = ref.watch(authControllerProvider);
    final locale = ref.watch(localeProvider);
    final kit = ref.watch(localKitProvider);
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
        if (ref.watch(demoModeProvider)) const Padding(padding: EdgeInsets.only(bottom: 12), child: DemoBanner()),
        Text(l.navProfile, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        GlassCard(
          child: user == null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.guestProfile, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
                  const SizedBox(height: 12),
                  GlassButton(label: l.signIn, onPressed: () => context.push('/sign-in')),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.fullName ?? user.email, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
                  if (user.fullName != null && user.email.isNotEmpty)
                    Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  if (user.venueId != null) ...[
                    GlassButton(label: l.openStaffDesk, onPressed: () => context.push('/staff')),
                    const SizedBox(height: 8),
                  ],
                  GlassButton(
                    label: l.signOut,
                    secondary: true,
                    onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ]),
        ),
        const SizedBox(height: 16),
        GlassCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.language, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              GlassChip(
                label: l.langThai,
                selected: locale.languageCode == 'th',
                onTap: () => ref.read(localeProvider.notifier).set(const Locale('th')),
              ),
              GlassChip(
                label: l.langEnglish,
                selected: locale.languageCode == 'en',
                onTap: () => ref.read(localeProvider.notifier).set(const Locale('en')),
              ),
            ]),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.alertsOn),
              value: kit.alertsOn,
              activeColor: AppColors.gold,
              onChanged: (on) => ref.read(localKitProvider.notifier).setAlerts(on),
            ),
          ]),
        ),
      ]),
    );
  }
}
