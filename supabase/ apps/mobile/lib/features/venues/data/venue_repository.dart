import '../domain/venue.dart';

abstract class VenueRepository {
  Future<List<Venue>> fetchVenues();
  Future<Venue?> fetchVenue(String id);
  Future<FloorPlan?> fetchFloorPlan(String venueId);

  /// Ids of tables free for [start, end) and [guests]; null when availability cannot be known (signed out).
  Future<Set<String>?> availableTableIds(String venueId, DateTime start, DateTime end, int guests);
}
