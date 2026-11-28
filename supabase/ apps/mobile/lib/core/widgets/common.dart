import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../theme/tokens.dart';
import 'glass.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.errorLoading, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
          const SizedBox(height: 16),
          SizedBox(width: 160, child: GlassButton(label: l.retry, secondary: true, onPressed: onRetry)),
        ]),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(children: [
        Icon(icon, size: 40, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
      ]),
    );
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GlassCard(
      child: Row(children: [
        const Icon(Icons.science_outlined, color: AppColors.gold, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(l.demoBanner, style: const TextStyle(fontSize: 13, height: 1.4))),
      ]),
    );
  }
}
