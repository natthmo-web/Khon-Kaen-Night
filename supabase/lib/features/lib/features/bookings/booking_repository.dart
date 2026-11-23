import 'package:supabase_flutter/supabase_flutter.dart';

import '../venues/domain/venue.dart';
import 'booking.dart';
import 'demo_night.dart';

abstract class BookingRepository {
  Future<BookingRecord> create({
    required Venue venue,
    required VenueTable table,
    required DateTime start,
    required int guests,
    required String name,
    required String phone,
    String? note,
  });
  Future<List<BookingRecord>> mine();
  Future<List<BookingRecord>> forStaff(String venueId);
  Future<void> cancel(String id);
  Future<void> decide(String id, String status, {String? reason});
  Future<List<NightEvent>> events();
  Future<List<AppNotification>> notifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
}

class DemoBookingRepository implements BookingRepository {
  DemoBookingRepository(this.night, this.userId, this.userName, {this.staffVenueId});
  final DemoNight night;
  final String userId, userName;
  final String? staffVenueId;

  @override
  Future<BookingRecord> create({
    required Venue venue,
    required VenueTable table,
    required DateTime start,
    required int guests,
    required String name,
    required String phone,
    String? note,
  }) async =>
      night.create(customerId: userId, customerName: name, venue: venue, table: table, start: start, guests: guests, note: note);

  @override
  Future<List<BookingRecord>> mine() async => night.bookings.where((b) => b.customerId == userId).toList();

  @override
  Future<List<BookingRecord>> forStaff(String venueId) async =>
      night.bookings.where((b) => b.venueId == venueId).toList();

  @override
  Future<void> cancel(String id) async => night.cancel(customerId: userId, bookingId: id);

  @override
  Future<void> decide(String id, String status, {String? reason}) async {
    final venueId = staffVenueId;
    if (venueId == null) throw BookingException('forbidden');
    night.decide(actorVenueId: venueId, bookingId: id, status: status, reason: reason);
  }

  @override
  Future<List<NightEvent>> events() async {
    final now = DateTime.now().toUtc();
    return [
      NightEvent(id: 'e1', venueId: 'demo-1', venueName: 'Demo Neon Lounge', titleTh: 'ตัวอย่าง ดีเจไนท์', titleEn: 'Demo DJ Night', startsAt: now.add(const Duration(days: 7)), endsAt: now.add(const Duration(days: 7, hours: 5))),
      NightEvent(id: 'e2', venueId: 'demo-2', venueName: 'Demo Isan Live Pub', titleTh: 'ตัวอย่าง ดนตรีสด', titleEn: 'Demo Live Music Friday', startsAt: now.add(const Duration(days: 10))),
      NightEvent(id: 'e3', venueId: 'demo-3', venueName: 'Demo Skyline Rooftop Bar', titleTh: null, titleEn: 'Demo Rooftop Sunset Session', startsAt: now.add(const Duration(days: 14))),
    ];
  }

  @override
  Future<List<AppNotification>> notifications() async => night.notesFor(userId);

  @override
  Future<void> markRead(String id) async => night.markRead(userId, id);

  @override
  Future<void> markAllRead() async => night.markAllRead(userId);
}

class SupabaseBookingRepository implements BookingRepository {
  SupabaseBookingRepository(this._c);
  final SupabaseClient _c;

  String get _uid => _c.auth.currentUser!.id;

  static const _bookingColumns = '*, venues(name_en, name_th), venue_tables(table_number)';

  @override
  Future<BookingRecord> create({
    required Venue venue,
    required VenueTable table,
    required DateTime start,
    required int guests,
    required String name,
    required String phone,
    String? note,
  }) async {
    try {
      final raw = await _c.rpc('create_booking_request', params: {
        'p_table_id': table.id,
        'p_starts_at': start.toUtc().toIso8601String(),
        'p_ends_at': start.add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'p_guest_count': guests,
        'p_customer_name': name,
        'p_customer_phone': phone,
        'p_customer_note': note,
      });
      return _booking(raw as Map, venue.nameEn ?? venue.slug, table.number);
    } on PostgrestException catch (e) {
      throw BookingException(_code(e));
    }
  }

  /// The signed-in customer's own bookings, newest first. RLS also lets venue
  /// members and admins read other bookings, so the customer filter is required.
  @override
  Future<List<BookingRecord>> mine() async {
    final rows = await _c
        .from('bookings')
        .select(_bookingColumns)
        .eq('customer_id', _uid)
        .order('starts_at', ascending: false)
        .limit(50);
    return [for (final row in rows) _booking(row, null, null)];
  }

  /// Bookings for one venue from 7 days ago onward, oldest first, capped at 200.
  @override
  Future<List<BookingRecord>> forStaff(String venueId) async {
    final since = DateTime.now().toUtc().subtract(const Duration(days: 7)).toIso8601String();
    final rows = await _c
        .from('bookings')
        .select(_bookingColumns)
        .eq('venue_id', venueId)
        .gte('starts_at', since)
        .order('starts_at')
        .limit(200);
    return [for (final row in rows) _booking(row, null, null)];
  }

  @override
  Future<void> cancel(String id) async {
    try {
      await _c.rpc('cancel_booking', params: {'p_booking_id': id});
    } on PostgrestException catch (e) {
      throw BookingException(_code(e));
    }
  }

  @override
  Future<void> decide(String id, String status, {String? reason}) async {
    try {
      await _c.rpc('update_booking_status', params: {
        'p_booking_id': id,
        'p_new_status': status,
        'p_rejection_reason': reason,
      });
    } on PostgrestException catch (e) {
      throw BookingException(_code(e));
    }
  }

  @override
  Future<List<NightEvent>> events() async {
    final rows = await _c.from('events').select('*, venues(name_en, name_th)').eq('status', 'published').order('start_at');
    return [
      for (final row in rows)
        NightEvent(
          id: row['id'] as String,
          venueId: row['venue_id'] as String,
          venueName: _venueName(row['venues']) ?? '',
          titleTh: row['title_th'] as String?,
          titleEn: row['title_en'] as String?,
          startsAt: DateTime.parse(row['start_at'] as String).toLocal(),
          endsAt: row['end_at'] == null ? null : DateTime.parse(row['end_at'] as String).toLocal(),
        ),
    ];
  }

  @override
  Future<List<AppNotification>> notifications() async {
    final rows = await _c
        .from('notifications')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false)
        .limit(100);
    return [
      for (final row in rows)
        AppNotification(
          id: row['id'] as String,
          userId: row['user_id'] as String,
          type: row['type'] as String,
          createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
          isRead: row['is_read'] as bool? ?? false,
          bookingId: row['related_booking_id'] as String?,
        ),
    ];
  }

  @override
  Future<void> markRead(String id) async {
    await _c.from('notifications').update({'is_read': true}).eq('id', id).eq('user_id', _uid);
  }

  @override
  Future<void> markAllRead() async {
    await _c.from('notifications').update({'is_read': true}).eq('user_id', _uid).eq('is_read', false);
  }

  BookingRecord _booking(Map raw, String? venueName, String? tableNumber) {
    final venue = raw['venues'];
    final table = raw['venue_tables'];
    return BookingRecord(
      id: raw['id'] as String,
      reference: raw['booking_reference'] as String? ?? '',
      customerId: raw['customer_id'] as String,
      customerName: raw['customer_name'] as String? ?? '',
      venueId: raw['venue_id'] as String,
      venueName: venueName ?? _venueName(venue) ?? '',
      tableId: raw['table_id'] as String,
      tableNumber: tableNumber ?? (table is Map ? table['table_number'] as String? : null) ?? '',
      startsAt: DateTime.parse(raw['starts_at'] as String).toLocal(),
      endsAt: DateTime.parse(raw['ends_at'] as String).toLocal(),
      guests: (raw['guest_count'] as num).toInt(),
      status: raw['status'] as String,
      rejectionReason: raw['rejection_reason'] as String?,
      note: raw['customer_note'] as String?,
    );
  }

  String? _venueName(Object? venue) {
    if (venue is! Map) return null;
    final en = venue['name_en'] as String?;
    final th = venue['name_th'] as String?;
    if (en != null && en.isNotEmpty) return en;
    return th;
  }

  String _code(PostgrestException e) {
    final hay = '${e.code ?? ''} ${e.message}'.toLowerCase();
    const known = [
      'table_unavailable',
      'venue_closed',
      'guest_count_exceeds_capacity',
      'invalid_interval',
      'not_authenticated',
      'not_cancellable',
      'cancellation_window_closed',
      'rejection_reason_required',
      'forbidden',
      'booking_expired',
      'invalid_status_transition',
      'venue_not_available',
      'invalid_contact',
      'trial_expired',
    ];
    for (final key in known) {
      if (hay.contains(key)) return key;
    }
    if (e.code == '23P01') return 'table_unavailable';
    return 'unknown';
  }
}
