// profiles_repository.dart — CRUD for profiles table
import '../models/profile.dart';
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
      if (handle != null) 'handle': handle,
    });
  }
}
