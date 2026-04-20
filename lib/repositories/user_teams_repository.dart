// user_teams_repository.dart — 用户自建"我的队伍"（table: user_teams + user_team_members）
import '../services/local_storage.dart';
import '../services/supabase.dart';

class UserTeam {
  final String id;
  final String ownerId;
  final String name;
  final String? city;
  final String? sub;
  final DateTime createdAt;

  UserTeam({
    required this.id,
    required this.ownerId,
    required this.name,
    this.city,
    this.sub,
    required this.createdAt,
  });

  factory UserTeam.fromMap(Map<String, dynamic> m) => UserTeam(
    id: m['id'] as String,
    ownerId: (m['owner_id'] ?? '') as String,
    name: m['name'] as String,
    city: m['city'] as String?,
    sub: m['sub'] as String?,
    createdAt:
        DateTime.tryParse(m['created_at'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
  );

  Map<String, dynamic> toLocalMap() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'city': city,
    'sub': sub,
    'created_at': createdAt.toIso8601String(),
  };
}

class UserTeamsRepository {
  /// Teams owned by the current user. Falls back to LocalStore when offline.
  Future<List<UserTeam>> listMine() async {
    final uid = currentUserId;
    if (uid == null) return _fromLocalStore();
    try {
      final rows = await supabase
          .from('user_teams')
          .select()
          .eq('owner_id', uid)
          .order('created_at', ascending: false);
      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(UserTeam.fromMap)
          .toList();
      return list;
    } catch (_) {
      return _fromLocalStore();
    }
  }

  List<UserTeam> _fromLocalStore() {
    return LocalStore.myTeams.map((m) {
      return UserTeam(
        id:
            (m['id'] as String?) ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        ownerId: (m['owner_id'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        city: m['city'] as String?,
        sub: m['sub'] as String?,
        createdAt:
            DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
  }

  /// Create a new team. Mirrors to LocalStore on success.
  Future<UserTeam> create({
    required String name,
    String? city,
    String? sub,
  }) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        final row = await supabase
            .from('user_teams')
            .insert({
              'owner_id': uid,
              'name': name,
              'city': ?city,
              'sub': ?sub,
            })
            .select()
            .single();
        final team = UserTeam.fromMap(row);
        await LocalStore.addTeam(team.toLocalMap());
        return team;
      } catch (_) {
        // fall through to local-only
      }
    }
    final local = UserTeam(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      ownerId: uid ?? '',
      name: name,
      city: city,
      sub: sub,
      createdAt: DateTime.now(),
    );
    await LocalStore.addTeam(local.toLocalMap());
    return local;
  }

  Future<void> delete(String id) async {
    final uid = currentUserId;
    if (uid != null && !id.startsWith('local-')) {
      try {
        await supabase
            .from('user_teams')
            .delete()
            .eq('id', id)
            .eq('owner_id', uid);
      } catch (_) {
        // ignore; still clear locally
      }
    }
    await LocalStore.removeTeam(id);
  }

  Future<void> addMember({
    required String teamId,
    required String userId,
    String role = 'member',
  }) async {
    await supabase.from('user_team_members').insert({
      'team_id': teamId,
      'user_id': userId,
      'role': role,
    });
  }

  Future<void> leave({required String teamId, required String userId}) async {
    await supabase
        .from('user_team_members')
        .delete()
        .eq('team_id', teamId)
        .eq('user_id', userId);
  }
}
