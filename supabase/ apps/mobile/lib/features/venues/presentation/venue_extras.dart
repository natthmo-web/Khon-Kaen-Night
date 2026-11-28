import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/venue.dart';

const _facilityTh = {
  'wifi': 'Wi-Fi',
  'parking': 'ที่จอดรถ',
  'outdoor': 'โซนกลางแจ้ง',
  'live_music': 'ดนตรีสด',
  'air_conditioned': 'เครื่องปรับอากาศ',
  'private_room': 'ห้องส่วนตัว',
  'smoking_area': 'โซนสูบบุหรี่',
  'dance_floor': 'ฟลอร์เต้นรำ',
};
const _facilityEn = {
  'wifi': 'Wi-Fi',
  'parking': 'Parking',
  'outdoor': 'Outdoor area',
  'live_music': 'Live music',
  'air_conditioned': 'Air conditioning',
  'private_room': 'Private room',
  'smoking_area': 'Smoking area',
  'dance_floor': 'Dance floor',
};

String facilityLabel(AppLocalizations l, String code) {
  final map = l.localeName.startsWith('th') ? _facilityTh : _facilityEn;
  final known = map[code];
  if (known != null) return known;
  final plain = code.replaceAll('_', ' ');
  return plain.isEmpty ? code : plain[0].toUpperCase() + plain.substring(1);
}

/// Call, LINE and directions shortcuts; shows only what the venue has filled in.
class VenueActionRow extends StatelessWidget {
  const VenueActionRow({super.key, required this.venue});
  final Venue venue;

  Future<void> _open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chips = <Widget>[
      if ((venue.phone ?? '').isNotEmpty)
        GlassChip(label: l.callVenue, onTap: () => _open(Uri(scheme: 'tel', path: venue.phone))),
      if ((venue.lineId ?? '').isNotEmpty)
        GlassChip(label: l.lineVenue, onTap: () => _open(Uri.parse('https://line.me/R/ti/p/~${Uri.encodeComponent(venue.lineId!)}'))),
      if (venue.latitude != null && venue.longitude != null)
        GlassChip(
          label: l.directions,
          onTap: () => _open(Uri.parse('https://www.google.com/maps/search/?api=1&query=${venue.latitude},${venue.longitude}')),
        ),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

/// Venues only have a cover image for now, so there is no gallery to show yet.
class VenueGallery extends StatelessWidget {
  const VenueGallery({super.key, required this.venue});
  final Venue venue;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

final venueReviewsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, venueId) async {
  if (ref.watch(demoModeProvider)) return const [];
  final rows = await Supabase.instance.client
      .from('venue_reviews')
      .select('rating, body, created_at')
      .eq('venue_id', venueId)
      .order('created_at', ascending: false)
      .limit(20);
  return [for (final row in rows) Map<String, dynamic>.from(row)];
});

class VenueReviews extends ConsumerWidget {
  const VenueReviews({super.key, required this.venueId});
  final String venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final reviews = ref.watch(venueReviewsProvider(venueId));
    return reviews.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        final t = Theme.of(context).textTheme;
        if (items.isEmpty) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.reviews, style: t.titleMedium),
            const SizedBox(height: 8),
            Text(l.noReviews, style: const TextStyle(color: AppColors.textSecondary)),
          ]);
        }
        final average = items.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / items.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(l.reviews, style: t.titleMedium),
            const SizedBox(width: 12),
            const Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
            const SizedBox(width: 4),
            Text(average.toStringAsFixed(1), style: const TextStyle(color: AppColors.gold)),
          ]),
          const SizedBox(height: 8),
          for (final r in items.take(5))
            if (((r['body'] as String?) ?? '').trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${r['rating']}★  ${r['body']}', style: const TextStyle(color: AppColors.textSecondary, height: 1.45)),
              ),
        ]);
      },
    );
  }
}
