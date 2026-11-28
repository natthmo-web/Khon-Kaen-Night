import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/generated/app_localizations.dart';

class KhonKaenNightApp extends ConsumerWidget {
  const KhonKaenNightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    ref.watch(realtimeSyncProvider);
    return MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.dark(locale),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => DefaultTextHeightBehavior(
        textHeightBehavior: const TextHeightBehavior(applyHeightToFirstAscent: true, applyHeightToLastDescent: true),
        child: child ?? const SizedBox.shrink(),
      ),
      onGenerateTitle: (c) => AppLocalizations.of(c).appName,
    );
  }
}
