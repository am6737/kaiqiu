import '../services/supabase.dart';

class LikesRepository {
  Future<bool> toggle(String targetType, String targetId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final existing = await supabase
        .from('likes')
        .select('id')
        .eq('user_id', uid)
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .maybeSingle();
    if (existing != null) {
      await supabase
          .from('likes')
          .delete()
          .eq('user_id', uid)
          .eq('target_type', targetType)
          .eq('target_id', targetId);
      return false;
    } else {
      await supabase.from('likes').insert({
        'user_id': uid,
        'target_type': targetType,
        'target_id': targetId,
      });
      return true;
    }
  }

  Future<bool> isLiked(String targetType, String targetId) async {
    final uid = currentUserId;
    if (uid == null) return false;
    final row = await supabase
        .from('likes')
        .select('id')
        .eq('user_id', uid)
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .maybeSingle();
    return row != null;
  }

  Future<Set<String>> likedIds(String targetType) async {
    final uid = currentUserId;
    if (uid == null) return {};
    final rows = await supabase
        .from('likes')
        .select('target_id')
        .eq('user_id', uid)
        .eq('target_type', targetType);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['target_id'] as String)
        .toSet();
  }
}
