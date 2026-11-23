import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../saved/local_kit.dart';

export '../../core/providers.dart' show notificationsProvider;

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Live updates come from realtimeSyncProvider; watching it here keeps it alive while this screen is open.
    ref.watch(realtimeSyncProvider);
    final rows = ref.watch(notificationsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: rows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorView(onRetry: () => ref.invalidate(notificationsProvider)),
          data: (items) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 120), children: [
            Row(children: [
              Expanded(child: Text(l.notifications, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600))),
              if (items.any((n) => !n.isRead))
                TextButton(
                  onPressed: () async {
                    await ref.read(bookingRepositoryProvider)?.markAllRead();
                    if (mounted) ref.invalidate(notificationsProvider);
                  },
                  child: Text(l.markAllRead),
                ),
            ]),
            if (!ref.watch(localKitProvider).alertsOn)
              Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(l.alertsPaused, style: const TextStyle(color: AppColors.gold, height: 1.45))),
            if (items.isEmpty) EmptyState(icon: Icons.notifications_none, message: l.emptyNotifications),
            for (final note in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_label(l, note.type), style: TextStyle(fontWeight: note.isRead ? FontWeight.w500 : FontWeight.w700)),
                trailing: note.isRead ? null : const Icon(Icons.circle, size: 8, color: AppColors.gold),
                onTap: () async {
                  await ref.read(bookingRepositoryProvider)?.markRead(note.id);
                  if (mounted) ref.invalidate(notificationsProvider);
                },
              ),
          ]),
        ),
      ),
    );
  }

  String _label(AppLocalizations l, String type) => switch (type) {
        'booking_requested' => l.notifRequested,
        'booking_confirmed' => l.notifConfirmed,
        'booking_rejected' => l.notifRejected,
        'booking_cancelled' => l.notifCancelled,
        'booking_expired' => l.notifExpired,
        _ => type,
      };
}
