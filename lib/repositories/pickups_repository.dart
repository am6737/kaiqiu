// pickups_repository.dart — thin wrapper around Supabase queries
import '../models/pickup.dart';
import '../services/supabase.dart';

class PickupsRepository {
  /// List upcoming pickups, soonest first. Optionally filter by status.
  Future<List<Pickup>> listUpcoming({
    PickupStatus? status,
    int limit = 50,
  }) async {
    var query = supabase.from('pickups').select();
    if (status != null) {
      query = query.eq('status', status.name);
    }
    final rows = await query
        .gte('start_at', DateTime.now().toUtc().toIso8601String())
        .order('start_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Pickup.fromMap)
        .toList();
  }

  /// List all pickups including past, for displaying seed/mock data that
  /// may have timestamps in the past after a while. Soonest first.
  Future<List<Pickup>> listAll({int limit = 50}) async {
    final rows = await supabase
        .from('pickups')
        .select()
        .order('start_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Pickup.fromMap)
        .toList();
  }

  Future<Pickup> fetch(String id) async {
    final row =
        await supabase.from('pickups').select().eq('id', id).single();
    return Pickup.fromMap(row);
  }

  Future<List<PickupSlot>> slotsFor(String pickupId) async {
    final rows =
        await supabase.from('pickup_slots').select().eq('pickup_id', pickupId);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PickupSlot.fromMap)
        .toList();
  }

  /// Join a pickup at [position]. Throws on conflict (slot taken).
  Future<void> join({
    required String pickupId,
    required String userId,
    required String position,
    required int x,
    required int y,
  }) async {
    await supabase.from('pickup_slots').insert({
      'pickup_id': pickupId,
      'user_id': userId,
      'position': position,
      'x': x,
      'y': y,
    });
  }

  Future<void> leave({required String slotId}) async {
    await supabase.from('pickup_slots').delete().eq('id', slotId);
  }
}
