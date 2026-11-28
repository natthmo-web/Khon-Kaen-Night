import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email, this.fullName, this.phone, this.venueId});
  final String id, email;
  final String? fullName, phone;

  /// Set for venue staff: the venue they belong to (first row of venue_members).
  final String? venueId;
}

/// Null state = signed out. Result codes of signIn/signUp: null = success, 'invalid_credentials',
/// 'check_email' (sign-up needs the inbox link first) or 'unknown'.
class AuthController extends Notifier<AuthUser?> {
  var _disposed = false;

  @override
  AuthUser? build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    if (RunMode.demo) return null;
    final auth = Supabase.instance.client.auth;
    final sub = auth.onAuthStateChange.listen((event) => _sync(event.session?.user));
    ref.onDispose(sub.cancel);
    final current = auth.currentUser;
    if (current == null) return null;
    Future<void>.microtask(() => _sync(current));
    return AuthUser(id: current.id, email: current.email ?? '');
  }

  Future<String?> signIn({required String email, required String password}) async {
    if (RunMode.demo) {
      _demoSignIn(email, null);
      return null;
    }
    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      await _sync(res.user);
      return null;
    } on AuthException {
      return 'invalid_credentials';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<String?> signUp({required String email, required String password, required String fullName}) async {
    if (RunMode.demo) {
      _demoSignIn(email, fullName);
      return null;
    }
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'preferred_language': ref.read(localeProvider).languageCode},
      );
      if (res.session == null) return 'check_email';
      await _sync(res.user);
      return null;
    } on AuthException {
      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<void> signOut() async {
    if (!RunMode.demo) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    state = null;
  }

  void _demoSignIn(String email, String? fullName) {
    final staff = email.toLowerCase().contains('staff');
    state = staff
        ? AuthUser(id: 'demo-staff', email: email, fullName: 'Demo Staff', venueId: 'demo-1')
        : AuthUser(id: 'demo-user', email: email, fullName: fullName ?? 'Demo User');
  }

  Future<void> _sync(User? user) async {
    if (_disposed) return;
    if (user == null) {
      state = null;
      return;
    }
    String? name, phone, venueId;
    try {
      final client = Supabase.instance.client;
      final profile = await client.from('profiles').select('full_name, phone').eq('id', user.id).maybeSingle();
      name = profile?['full_name'] as String?;
      phone = profile?['phone'] as String?;
      final member = await client.from('venue_members').select('venue_id').eq('user_id', user.id).limit(1);
      if (member.isNotEmpty) venueId = member.first['venue_id'] as String?;
    } catch (_) {
      // Keep going with what the session already tells us.
    }
    if (_disposed) return;
    state = AuthUser(id: user.id, email: user.email ?? '', fullName: name, phone: phone, venueId: venueId);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthUser?>(AuthController.new);
