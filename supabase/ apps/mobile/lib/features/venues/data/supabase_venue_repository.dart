import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/venue.dart';
import 'venue_repository.dart';

class SupabaseVenueRepository implements VenueRepository {
  SupabaseVenueRepository(this._c);
  final SupabaseClient _c;

  @override
  Future<List<Venue>> fetchVenues() async {
    final rows = await _c.from('venues').select().eq('status', 'approved').order('created_at');
    return [for (final row in rows) Venue.fromJson(row)];
  }

  @override
  Future<Venue?> fetchVenue(String id) async {
    final row = await _c.from('venues').select().eq('id', id).maybeSingle();
    return row == null ? null : Venue.fromJson(row);
  }

  @override
  Future<FloorPlan?> fetchFloorPlan(String venueId) async {
    final plan = await _c
        .from('floor_plans')
        .select()
        .eq('venue_id', venueId)
        .eq('is_published', true)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    if (plan == null) return null;
    final tables = await _c
        .from('venue_tables')
        .select()
        .eq('floor_plan_id', plan['id'] as String)
        .eq('is_active', true)
        .order('table_number');
    return FloorPlan(
      id: plan['id'] as String,
      canvasWidth: (plan['canvas_width'] as num).toDouble(),
      canvasHeight: (plan['canvas_height'] as num).toDouble(),
      tables: [for (final t in tables) VenueTable.fromJson(t)],
    );
  }

  @override
  Future<Set<String>?> availableTableIds(String venueId, DateTime start, DateTime end, int guests) async {
    if (_c.auth.currentUser == null) return null;
    try {
      final rows = await _c.rpc('get_available_tables', params: {
        'p_venue_id': venueId,
        'p_starts_at': start.toUtc().toIso8601String(),
        'p_ends_at': end.toUtc().toIso8601String(),
        'p_guest_count': guests,
      });
      return {for (final row in (rows as List)) (row as Map)['id'] as String};
    } catch (_) {
      return null;
    }
  }
}
