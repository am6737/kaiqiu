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
    final row = await supabase.from('pickups').select().eq('id', id).single();
    return Pickup.fromMap(row);
  }

  Future<List<PickupSlot>> slotsFor(String pickupId) async {
    final rows = await supabase
        .from('pickup_slots')
        .select()
        .eq('pickup_id', pickupId);
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

  /// List pickups hosted by [userId]. Soonest first.
  Future<List<Pickup>> listByHost(String userId, {int limit = 50}) async {
    final rows = await supabase
        .from('pickups')
        .select()
        .eq('host_id', userId)
        .order('start_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Pickup.fromMap)
        .toList();
  }

  /// List pickups that [userId] has joined via pickup_slots.
  Future<List<Pickup>> listJoinedBy(String userId, {int limit = 50}) async {
    final slotRows = await supabase
        .from('pickup_slots')
        .select('pickup_id')
        .eq('user_id', userId);
    final ids = (slotRows as List)
        .map((r) => (r as Map)['pickup_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (ids.isEmpty) return [];
    final rows = await supabase
        .from('pickups')
        .select()
        .inFilter('id', ids)
        .order('start_at', ascending: true)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Pickup.fromMap)
        .toList();
  }

  /// Insert a pickup along with [totalSlots] empty `pickup_slots` rows laid
  /// out in the given [formation]. Returns the new pickup id.
  Future<String> createWithSlots({
    required Map<String, dynamic> payload,
    required int totalSlots,
    String formation = '4-3-3',
  }) async {
    final row = await supabase
        .from('pickups')
        .insert(payload)
        .select()
        .single();
    final id = row['id'] as String;
    final slots = _generateSlotCoords(formation, totalSlots)
        .map(
          (slot) => {
            'pickup_id': id,
            'position': slot.$1,
            'x': slot.$2,
            'y': slot.$3,
          },
        )
        .toList();
    if (slots.isNotEmpty) {
      await supabase.from('pickup_slots').insert(slots);
    }
    return id;
  }

  /// Returns a list of (position, x%, y%) tuples for the given formation.
  /// Supports 4-3-3, 4-4-2, 3-5-2 for 11-a-side; otherwise evenly distributes.
  static List<(String, int, int)> _generateSlotCoords(
    String formation,
    int total,
  ) {
    switch (formation) {
      case '4-3-3':
        return const [
          ('GK', 50, 92),
          ('LB', 18, 72),
          ('LCB', 38, 72),
          ('RCB', 62, 72),
          ('RB', 82, 72),
          ('LCM', 30, 52),
          ('CM', 50, 52),
          ('RCM', 70, 52),
          ('LW', 22, 28),
          ('ST', 50, 20),
          ('RW', 78, 28),
        ];
      case '4-4-2':
        return const [
          ('GK', 50, 92),
          ('LB', 18, 72),
          ('LCB', 38, 72),
          ('RCB', 62, 72),
          ('RB', 82, 72),
          ('LM', 18, 50),
          ('LCM', 40, 50),
          ('RCM', 60, 50),
          ('RM', 82, 50),
          ('LS', 38, 22),
          ('RS', 62, 22),
        ];
      case '3-5-2':
        return const [
          ('GK', 50, 92),
          ('LCB', 28, 72),
          ('CB', 50, 72),
          ('RCB', 72, 72),
          ('LWB', 15, 52),
          ('LCM', 35, 52),
          ('CM', 50, 52),
          ('RCM', 65, 52),
          ('RWB', 85, 52),
          ('LS', 38, 22),
          ('RS', 62, 22),
        ];
      default:
        final list = <(String, int, int)>[];
        for (int i = 0; i < total; i++) {
          final x = 10 + (80 * i ~/ (total - 1)).clamp(0, 80);
          final y = 30 + ((i * 60) ~/ total).clamp(0, 60);
          list.add(('P${i + 1}', x, y));
        }
        return list;
    }
  }
}
