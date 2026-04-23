// venues_repository.dart — Supabase CRUD for venues + bookings
import '../models/venue.dart';
import '../services/supabase.dart';

class VenuesRepository {
  Future<List<Venue>> listAll({int limit = 50}) async {
    final rows = await supabase
        .from('venues')
        .select()
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Venue.fromMap)
        .toList();
  }

  Future<List<Venue>> listBySport(String sportType, {int limit = 50}) async {
    final rows = await supabase
        .from('venues')
        .select()
        .eq('status', 'active')
        .eq('sport_type', sportType)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Venue.fromMap)
        .toList();
  }

  Future<Venue> fetch(String id) async {
    final row = await supabase.from('venues').select().eq('id', id).single();
    return Venue.fromMap(row);
  }

  Future<List<Venue>> listByOwner(String ownerId, {int limit = 50}) async {
    final rows = await supabase
        .from('venues')
        .select()
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Venue.fromMap)
        .toList();
  }

  Future<List<Venue>> listByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await supabase
        .from('venues')
        .select()
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Venue.fromMap)
        .toList();
  }

  Future<String> create(Map<String, dynamic> payload) async {
    final row = await supabase
        .from('venues')
        .insert(payload)
        .select()
        .single();
    return row['id'] as String;
  }

  Future<void> update(String id, Map<String, dynamic> payload) async {
    await supabase.from('venues').update(payload).eq('id', id);
  }

  Future<void> delete(String id) async {
    await supabase.from('venues').delete().eq('id', id);
  }

  // ── Bookings ──

  Future<List<VenueBooking>> bookingsForVenue(
    String venueId, {
    DateTime? date,
    int limit = 50,
  }) async {
    var query = supabase
        .from('venue_bookings')
        .select()
        .eq('venue_id', venueId);
    if (date != null) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      query = query.eq('date', dateStr);
    }
    final rows = await query
        .order('date', ascending: true)
        .order('start_time', ascending: true)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(VenueBooking.fromMap)
        .toList();
  }

  Future<List<VenueBooking>> bookingsByUser(
    String userId, {
    int limit = 50,
  }) async {
    final rows = await supabase
        .from('venue_bookings')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(VenueBooking.fromMap)
        .toList();
  }

  Future<String> createBooking(Map<String, dynamic> payload) async {
    final row = await supabase
        .from('venue_bookings')
        .insert(payload)
        .select()
        .single();
    return row['id'] as String;
  }

  Future<void> updateBookingStatus(String id, String status) async {
    await supabase
        .from('venue_bookings')
        .update({'status': status})
        .eq('id', id);
  }

  Future<void> cancelBooking(String id) async {
    await updateBookingStatus(id, 'cancelled');
  }

  /// Bookings for venues owned by [ownerId] (venue manager view).
  Future<List<VenueBooking>> bookingsForOwner(
    String ownerId, {
    int limit = 100,
  }) async {
    final venueRows = await supabase
        .from('venues')
        .select('id')
        .eq('owner_id', ownerId);
    final venueIds = (venueRows as List)
        .map((r) => (r as Map)['id'] as String)
        .toList();
    if (venueIds.isEmpty) return [];
    final rows = await supabase
        .from('venue_bookings')
        .select()
        .inFilter('venue_id', venueIds)
        .order('date', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(VenueBooking.fromMap)
        .toList();
  }
}
