import '../../bookings/demo_night.dart';
import '../domain/venue.dart';
import 'venue_repository.dart';

/// Sample venues for Demo Mode. Table ids follow '<venueId>-t<n>' and numbers 'T<n>' to match DemoNight.
class DemoVenueRepository implements VenueRepository {
  DemoVenueRepository(this.night);
  final DemoNight night;

  static Map<String, dynamic> _nightly(String open, String close) => {
        for (final day in ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'])
          day: [
            {'open': open, 'close': close},
          ],
      };

  List<Venue> get _venues {
    final now = DateTime.now();
    return [
      Venue(
        id: 'demo-1',
        slug: 'demo-neon-lounge',
        category: 'lounge',
        nameEn: 'Demo Neon Lounge',
        nameTh: 'ตัวอย่าง นีออน เลานจ์',
        descriptionEn: 'Sample lounge with DJ nights and sofa tables.',
        descriptionTh: 'เลานจ์ตัวอย่าง มีดีเจและโต๊ะโซฟา',
        district: 'Mueang Khon Kaen',
        priceLevel: 3,
        facilities: const ['air_conditioned', 'wifi', 'live_music'],
        openingHours: _nightly('17:00', '02:00'),
        plan: 'trial',
        trialEndsAt: now.add(const Duration(days: 10)),
      ),
      Venue(
        id: 'demo-2',
        slug: 'demo-isan-live-pub',
        category: 'live_music',
        nameEn: 'Demo Isan Live Pub',
        nameTh: 'ตัวอย่าง อีสาน ไลฟ์ผับ',
        descriptionEn: 'Sample pub with live Isan music every Friday.',
        descriptionTh: 'ผับตัวอย่าง ดนตรีสดสไตล์อีสานทุกวันศุกร์',
        district: 'Mueang Khon Kaen',
        priceLevel: 2,
        facilities: const ['live_music', 'outdoor', 'parking'],
        openingHours: _nightly('17:00', '02:00'),
        plan: 'active',
      ),
      Venue(
        id: 'demo-3',
        slug: 'demo-skyline-rooftop',
        category: 'bar',
        nameEn: 'Demo Skyline Rooftop Bar',
        nameTh: 'ตัวอย่าง สกายไลน์ รูฟท็อป บาร์',
        descriptionEn: 'Sample rooftop bar with a city view.',
        descriptionTh: 'บาร์ดาดฟ้าตัวอย่าง วิวเมือง',
        district: 'Mueang Khon Kaen',
        priceLevel: 3,
        facilities: const ['outdoor', 'wifi'],
        openingHours: _nightly('17:00', '02:00'),
        plan: 'trial',
        trialEndsAt: now.add(const Duration(days: 5)),
      ),
    ];
  }

  static List<VenueTable> _tables(String venueId) {
    // number, capacity, type, x, y, w, h, shape
    const spec = <(int, int, String, double, double, double, double, String)>[
      (1, 6, 'vip', 100, 100, 220, 120, 'rect'),
      (2, 4, 'standard', 380, 100, 150, 120, 'rect'),
      (3, 4, 'standard', 590, 100, 150, 120, 'rect'),
      (4, 6, 'sofa', 800, 100, 150, 160, 'rect'),
      (5, 2, 'standard', 100, 340, 110, 110, 'round'),
      (6, 8, 'vip', 300, 340, 260, 150, 'rect'),
      (7, 4, 'standard', 640, 340, 130, 130, 'round'),
      (8, 2, 'standard', 840, 340, 110, 110, 'oval'),
    ];
    return [
      for (final s in spec)
        VenueTable(
          id: '$venueId-t${s.$1}',
          number: 'T${s.$1}',
          capacity: s.$2,
          type: s.$3,
          x: s.$4,
          y: s.$5,
          w: s.$6,
          h: s.$7,
          rotation: 0,
          shape: s.$8,
        ),
    ];
  }

  @override
  Future<List<Venue>> fetchVenues() async => _venues;

  @override
  Future<Venue?> fetchVenue(String id) async => _venues.where((v) => v.id == id).firstOrNull;

  @override
  Future<FloorPlan?> fetchFloorPlan(String venueId) async {
    if (!_venues.any((v) => v.id == venueId)) return null;
    return FloorPlan(id: '$venueId-plan', canvasWidth: 1000, canvasHeight: 560, tables: _tables(venueId));
  }

  @override
  Future<Set<String>?> availableTableIds(String venueId, DateTime start, DateTime end, int guests) async =>
      night.availableIds(venueId, _tables(venueId), start, end, guests);
}
