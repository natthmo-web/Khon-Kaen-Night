import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/venue.dart';

const _categoryTh = {
  'pub': 'ผับ',
  'bar': 'บาร์',
  'nightclub': 'ไนท์คลับ',
  'lounge': 'เลานจ์',
  'live_music': 'ดนตรีสด',
  'restaurant': 'ร้านอาหาร',
  'entertainment': 'บันเทิง',
};
const _categoryEn = {
  'pub': 'Pub',
  'bar': 'Bar',
  'nightclub': 'Nightclub',
  'lounge': 'Lounge',
  'live_music': 'Live music',
  'restaurant': 'Restaurant',
  'entertainment': 'Entertainment',
};

String categoryLabel(AppLocalizations l, String category) {
  final map = l.localeName.startsWith('th') ? _categoryTh : _categoryEn;
  return map[category] ?? category;
}

/// Cover photo, or a dark gold gradient with the venue's initial when there is none.
class VenueCover extends StatelessWidget {
  const VenueCover({super.key, required this.venue, this.url});
  final Venue venue;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2233), Color(0xFF14121A)],
        ),
      ),
      child: Center(
        child: Text(
          String.fromCharCode(venue.name(lang).runes.first).toUpperCase(),
          style: TextStyle(fontSize: 64, fontWeight: FontWeight.w300, color: AppColors.gold.withAlpha(140)),
        ),
      ),
    );
    final u = url;
    if (u == null || u.isEmpty) return fallback;
    return Image.network(u, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
  }
}

class VenueCard extends StatelessWidget {
  const VenueCard({super.key, required this.venue, required this.onTap});
  final Venue venue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final price = venue.priceLevel == null ? null : '฿' * venue.priceLevel!;
    final hours = venue.hoursToday();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: const Color(0x1AFFFFFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(height: 150, width: double.infinity, child: VenueCover(venue: venue, url: venue.coverImageUrl)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(venue.name(lang), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  [categoryLabel(l, venue.category), if (venue.district != null) venue.district!, if (price != null) price].join(' · '),
                  style: const TextStyle(color: AppColors.gold, fontSize: 13),
                ),
                if (hours != null) ...[
                  const SizedBox(height: 6),
                  Text('${l.openingHours}: $hours', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
