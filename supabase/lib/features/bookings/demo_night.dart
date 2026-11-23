import 'package:flutter/foundation.dart';

import '../venues/domain/venue.dart';
import 'booking.dart';
import 'booking_rules.dart';

/// In-memory bookings and alerts for Demo Mode.
/// T2, T5 and T7 stay taken so the floor plan still shows both states.
class DemoNight extends ChangeNotifier {
  DemoNight() {
    final start = BookingRules.bangkok(DateTime.now().toUtc().add(const Duration(days: 2)), 21, 0);
    _bookings.add(BookingRecord(
      id: 'demo-seed',
      reference: 'KKN-DEMO0001',
      customerId: 'other-guest',
      customerName: 'Demo Guest',
      venueId: 'demo-1',
      venueName: 'Demo Neon Lounge',
      tableId: 'demo-1-t3',
      tableNumber: 'T3',
      startsAt: start,
      endsAt: start.add(const Duration(hours: 2)),
      guests: 2,
      status: 'pending',
    ));
    _bookings.add(BookingRecord(
      id: 'demo-seed-2',
      reference: 'KKN-DEMO0002',
      customerId: 'other-guest',
      customerName: 'Second Guest',
      venueId: 'demo-1',
      venueName: 'Demo Neon Lounge',
      tableId: 'demo-1-t4',
      tableNumber: 'T4',
      startsAt: start.add(const Duration(hours: 3)),
      endsAt: start.add(const Duration(hours: 5)),
      guests: 4,
      status: 'pending',
    ));
    _alert('demo-staff', 'booking_requested', 'demo-seed');
    _alert('demo-staff', 'booking_requested', 'demo-seed-2');
  }

  static const presetTaken = {'T2', 'T5', 'T7'};

  /// Mirrors platform_settings.pending_hold_minutes in Live mode.
  /// The two seeded requests have no hold, so staff always have something to act on.
  static const holdMinutes = 60;

  final _bookings = <BookingRecord>[];
  final _notes = <AppNotification>[];
  final _holds = <String, DateTime>{};
  var _n = 0;

  List<BookingRecord> get bookings {
    _sweep();
    return List.unmodifiable(_bookings);
  }

  List<AppNotification> notesFor(String userId) {
    _sweep();
    return _notes.where((n) => n.userId == userId).toList().reversed.toList();
  }

  /// Expires pending requests whose hold has run out and tells their customer.
  /// Does not notify listeners: it runs from reads, which can happen while a widget builds.
  void _sweep() {
    final now = DateTime.now();
    for (var i = 0; i < _bookings.length; i++) {
      final b = _bookings[i];
      final hold = _holds[b.id];
      if (b.status == 'pending' && hold != null && !hold.isAfter(now)) {
        _bookings[i] = _copy(b, status: 'expired');
        _holds.remove(b.id);
        _alert(b.customerId, 'booking_expired', b.id);
      }
    }
  }

  Set<String> availableIds(String venueId, List<VenueTable> tables, DateTime start, DateTime end, int guests) {
    _sweep();
    final held = {
      for (final b in _bookings)
        if (b.venueId == venueId &&
            (b.status == 'pending' || b.status == 'confirmed') &&
            BookingRules.overlaps(b.startsAt, b.endsAt, start, end))
          b.tableId,
    };
    return {
      for (final t in tables)
        if (t.capacity >= guests && !presetTaken.contains(t.number) && !held.contains(t.id)) t.id,
    };
  }

  BookingRecord create({
    required String customerId,
    required String customerName,
    required Venue venue,
    required VenueTable table,
    required DateTime start,
    required int guests,
    String? note,
  }) {
    final end = start.add(const Duration(hours: 2));
    if (!start.isAfter(DateTime.now())) throw BookingException('invalid_interval');
    if (guests < 1 || guests > table.capacity) throw BookingException('guest_count_exceeds_capacity');
    if (!venue.acceptsBookings) throw BookingException('trial_expired');
    if (!BookingRules.covers(venue.openingHours, start, end)) throw BookingException('venue_closed');
    if (presetTaken.contains(table.number) || !availableIds(venue.id, [table], start, end, guests).contains(table.id)) {
      throw BookingException('table_unavailable');
    }
    final row = BookingRecord(
      id: 'demo-${++_n}',
      reference: 'KKN-DEMO${_n.toString().padLeft(4, '0')}',
      customerId: customerId,
      customerName: customerName,
      venueId: venue.id,
      venueName: venue.nameEn ?? venue.nameTh ?? venue.slug,
      tableId: table.id,
      tableNumber: table.number,
      startsAt: start,
      endsAt: end,
      guests: guests,
      status: 'pending',
      note: note,
    );
    _bookings.add(row);
    _holds[row.id] = DateTime.now().add(const Duration(minutes: holdMinutes));
    _alert(customerId, 'booking_requested', row.id);
    _alert('demo-staff', 'booking_requested', row.id);
    notifyListeners();
    return row;
  }

  BookingRecord cancel({required String customerId, required String bookingId, DateTime? now}) {
    _sweep();
    final i = _bookings.indexWhere((b) => b.id == bookingId);
    if (i < 0 || _bookings[i].customerId != customerId) throw BookingException('booking_not_found');
    final code = BookingRules.cancelCode(status: _bookings[i].status, startsAt: _bookings[i].startsAt, now: now ?? DateTime.now());
    if (code.isNotEmpty) throw BookingException(code);
    final next = _copy(_bookings[i], status: 'cancelled');
    _bookings[i] = next;
    _holds.remove(bookingId);
    _alert(customerId, 'booking_cancelled', bookingId);
    notifyListeners();
    return next;
  }

  BookingRecord decide({required String actorVenueId, required String bookingId, required String status, String? reason}) {
    if (status != 'confirmed' && status != 'rejected') throw BookingException('invalid_status_transition');
    if (status == 'rejected' && (reason == null || reason.trim().isEmpty)) throw BookingException('rejection_reason_required');
    final i = _bookings.indexWhere((b) => b.id == bookingId);
    if (i < 0) throw BookingException('booking_not_found');
    final current = _bookings[i];
    if (current.venueId != actorVenueId) throw BookingException('forbidden');
    final hold = _holds[bookingId];
    if (current.status == 'pending' && hold != null && !hold.isAfter(DateTime.now())) {
      _sweep();
      notifyListeners();
      throw BookingException('booking_expired');
    }
    if (current.status != 'pending') throw BookingException('invalid_status_transition');
    final next = _copy(current, status: status, rejectionReason: status == 'rejected' ? reason!.trim() : null);
    _bookings[i] = next;
    _holds.remove(bookingId);
    _alert(current.customerId, 'booking_$status', bookingId);
    notifyListeners();
    return next;
  }

  void markRead(String userId, String id) {
    final i = _notes.indexWhere((n) => n.id == id && n.userId == userId);
    if (i < 0) return;
    _notes[i] = AppNotification(
      id: _notes[i].id,
      userId: userId,
      type: _notes[i].type,
      createdAt: _notes[i].createdAt,
      isRead: true,
      bookingId: _notes[i].bookingId,
    );
    notifyListeners();
  }

  void markAllRead(String userId) {
    for (var i = 0; i < _notes.length; i++) {
      if (_notes[i].userId == userId) {
        _notes[i] = AppNotification(
          id: _notes[i].id,
          userId: userId,
          type: _notes[i].type,
          createdAt: _notes[i].createdAt,
          isRead: true,
          bookingId: _notes[i].bookingId,
        );
      }
    }
    notifyListeners();
  }

  BookingRecord _copy(BookingRecord b, {required String status, String? rejectionReason}) => BookingRecord(
        id: b.id,
        reference: b.reference,
        customerId: b.customerId,
        customerName: b.customerName,
        venueId: b.venueId,
        venueName: b.venueName,
        tableId: b.tableId,
        tableNumber: b.tableNumber,
        startsAt: b.startsAt,
        endsAt: b.endsAt,
        guests: b.guests,
        status: status,
        rejectionReason: rejectionReason ?? b.rejectionReason,
        note: b.note,
      );

  void _alert(String userId, String type, String bookingId) {
    _notes.add(AppNotification(
      id: 'note-${++_n}',
      userId: userId,
      type: type,
      createdAt: DateTime.now(),
      bookingId: bookingId,
    ));
  }
}
