// profiles_repository.dart — CRUD for profiles table
import '../models/match_history.dart';
import '../models/player_profile.dart';
import '../models/profile.dart';
import '../models/teammate.dart';
import '../services/supabase.dart';

class ProfilesRepository {
  Future<Profile?> fetch(String uid) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  Future<Profile?> fetchCurrent() async {
    final uid = currentUserId;
    if (uid == null) return null;
    return fetch(uid);
  }

  Future<void> update(String uid, Map<String, dynamic> payload) async {
    // Filter nulls so we don't stomp server values.
    final cleaned = <String, dynamic>{
      for (final e in payload.entries)
        if (e.value != null) e.key: e.value,
    };
    if (cleaned.isEmpty) return;
    await supabase.from('profiles').update(cleaned).eq('id', uid);
  }

  Future<void> upsertOnSignup({
    required String uid,
    required String name,
    String? handle,
  }) async {
    await supabase.from('profiles').upsert({
      'id': uid,
      'name': name,
      'handle': ?handle,
    });
  }

  /// Look up a profile by its unique `handle`. Returns null if not found.
  Future<Profile?> fetchByHandle(String handle) async {
    final row = await supabase
        .from('profiles')
        .select()
        .eq('handle', handle)
        .maybeSingle();
    if (row == null) return null;
    return Profile.fromMap(row);
  }

  /// Full player profile: base profile + stats + attributes + honors.
  Future<PlayerProfile?> fetchFullProfile(String uid) async {
    final results = await Future.wait([
      supabase.from('profiles').select().eq('id', uid).maybeSingle(),
      supabase.from('player_stats').select().eq('user_id', uid).maybeSingle(),
      supabase
          .from('player_attributes')
          .select()
          .eq('user_id', uid)
          .maybeSingle(),
      supabase
          .from('player_honors')
          .select()
          .eq('user_id', uid)
          .order('year', ascending: false),
    ]);

    final profileRow = results[0] as Map<String, dynamic>?;
    if (profileRow == null) return null;

    final statsRow = results[1] as Map<String, dynamic>?;
    final attrsRow = results[2] as Map<String, dynamic>?;
    final honorsRows = results[3] as List;

    final attrs = <String, int>{};
    if (attrsRow != null) {
      for (final key in [
        'speed',
        'shooting',
        'passing',
        'defense',
        'stamina',
        'technique',
      ]) {
        if (attrsRow[key] != null) attrs[key] = (attrsRow[key] as num).toInt();
      }
    }

    return PlayerProfile(
      profile: Profile.fromMap(profileRow),
      stats: PlayerStats.fromMap(statsRow),
      attrs: attrs,
      honors: honorsRows
          .cast<Map<String, dynamic>>()
          .map(PlayerHonor.fromMap)
          .toList(),
    );
  }

  /// Teammates derived from shared pickup participation.
  Future<List<Teammate>> teammates(String userId) async {
    final rows = await supabase
        .from('my_teammates')
        .select()
        .eq('me', userId)
        .order('matches', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Teammate.fromMap)
        .toList();
  }

  /// Match history via RPC.
  Future<List<MatchHistoryEntry>> matchHistory(String userId) async {
    final rows =
        await supabase.rpc('my_match_history', params: {'p_user_id': userId});
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(MatchHistoryEntry.fromMap)
        .toList();
  }
}
