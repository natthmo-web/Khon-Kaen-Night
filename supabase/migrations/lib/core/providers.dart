import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/auth_controller.dart';
import '../features/bookings/booking.dart';
import '../features/bookings/booking_repository.dart';
import '../features/bookings/demo_night.dart';
import '../features/venues/data/demo_venue_repository.dart';
import '../features/venues/data/supabase_venue_repository.dart';
import '../features/venues/data/venue_repository.dart';
import '../features/venues/domain/venue.dart';
import 'env.dart';

/// Set in main() after a live probe. True when no project is configured or the database cannot be reached.
class RunMode {
  static bool demo = !Env.hasSupabase;
}

final demoModeProvider = Provider<bool>((_) => RunMode.demo);

final demoNightProvider = ChangeNotifierProvider<DemoNight>((ref) => DemoNight());

final venueRepositoryProvider = Provider<VenueRepository>((ref) => ref.watch(demoModeProvider)
    ? DemoVenueRepository(ref.watch(demoNightProvider))
    : SupabaseVenueRepository(Supabase.instance.client));

final bookingRepositoryProvider = Provider<BookingRepository?>((ref) {
  final user = ref.watch(authControllerProvider);
  if (user == null) return null;
  // Keeps the live subscription running for as long as bookings or notifications are in use.
  ref.watch(realtimeSyncProvider);
  if (ref.watch(demoModeProvider)) {
    return DemoBookingRepository(ref.watch(demoNightProvider), user.id, user.fullName ?? user.email, staffVenueId: user.venueId);
  }
  return SupabaseBookingRepository(Supabase.instance.client);
});

final venuesProvider = FutureProvider.autoDispose<List<Venue>>((ref) => ref.watch(venueRepositoryProvider).fetchVenues());
final venueProvider = FutureProvider.autoDispose.family<Venue?, String>((ref, id) => ref.watch(venueRepositoryProvider).fetchVenue(id));
final floorPlanProvider =
    FutureProvider.autoDispose.family<FloorPlan?, String>((ref, id) => ref.watch(venueRepositoryProvider).fetchFloorPlan(id));

/// Placeholder window until the booking flow lets the customer choose date/time/guests.
final availabilityProvider = FutureProvider.autoDispose.family<Set<String>?, String>((ref, venueId) {
  final start = DateTime.now().add(const Duration(days: 1));
  return ref.watch(venueRepositoryProvider).availableTableIds(venueId, start, start.add(const Duration(hours: 2)), 1);
});

final availabilityWindowProvider = FutureProvider.autoDispose.family<Set<String>?, (String, DateTime, int)>((ref, args) {
  return ref.watch(venueRepositoryProvider).availableTableIds(args.$1, args.$2, args.$2.add(const Duration(hours: 2)), args.$3);
});

final myBookingsProvider = FutureProvider.autoDispose<List<BookingRecord>>((ref) async {
  ref.watch(demoNightProvider);
  return ref.watch(bookingRepositoryProvider)?.mine() ?? [];
});

final staffBookingsProvider = FutureProvider.autoDispose<List<BookingRecord>>((ref) async {
  ref.watch(demoNightProvider);
  final user = ref.watch(authControllerProvider);
  final repo = ref.watch(bookingRepositoryProvider);
  final venueId = user?.venueId;
  if (venueId == null || repo == null) return [];
  return repo.forStaff(venueId);
});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  ref.watch(demoNightProvider);
  return ref.watch(bookingRepositoryProvider)?.notifications() ?? [];
});

/// Live changes for the signed-in user (Live mode only).
/// Notifications are written in the same transaction as every booking change, so one stream
/// filtered by user_id keeps the bell, My Bookings and the staff list fresh without polling.
/// The channel is closed when the user signs out or changes.
final realtimeSyncProvider = Provider<void>((ref) {
  final user = ref.watch(authControllerProvider);
  if (user == null || ref.watch(demoModeProvider)) return;
  final client = Supabase.instance.client;
  Timer? debounce;

  void refresh() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      ref.invalidate(notificationsProvider);
      ref.invalidate(myBookingsProvider);
      ref.invalidate(staffBookingsProvider);
    });
  }

  final channel = client
      .channel('user-sync-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'notifications',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: user.id),
        callback: (_) => refresh(),
      )
      .subscribe();

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
});

/// Thai by default; the choice persists across restarts.
class LocaleController extends Notifier<Locale> {
  static const _key = 'language';

  @override
  Locale build() {
    _load();
    return const Locale('th');
  }

  Future<void> _load() async {
    final saved = (await SharedPreferences.getInstance()).getString(_key);
    if (saved == 'en' || saved == 'th') state = Locale(saved!);
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await (await SharedPreferences.getInstance()).setString(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
