import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/widgets/common.dart';
import '../../l10n/generated/app_localizations.dart';
import '../venues/presentation/venue_card.dart';

class VenuesHomeScreen extends ConsumerWidget {
  const VenuesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final venues = ref.watch(venuesProvider);
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(venuesProvider.future),
        child: venues.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ErrorView(onRetry: () => ref.invalidate(venuesProvider)),
          data: (items) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              if (ref.watch(demoModeProvider)) const Padding(padding: EdgeInsets.only(bottom: 12), child: DemoBanner()),
              Text(l.venuesTitle, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              if (items.isEmpty) EmptyState(icon: Icons.nightlife_outlined, message: l.emptyVenues),
              for (final venue in items) VenueCard(venue: venue, onTap: () => context.push('/venue/${venue.id}')),
            ],
          ),
        ),
      ),
    );
  }
}
