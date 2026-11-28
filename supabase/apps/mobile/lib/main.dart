import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Demo Mode unless a project is configured AND reachable.
  RunMode.demo = true;
  if (Env.hasSupabase) {
    try {
      await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
      await Supabase.instance.client.from('venues').select('id').limit(1).timeout(const Duration(seconds: 8));
      RunMode.demo = false;
    } catch (e) {
      debugPrint('Supabase probe failed, staying in Demo Mode: $e');
    }
  }

  runApp(const ProviderScope(child: KhonKaenNightApp()));
}
