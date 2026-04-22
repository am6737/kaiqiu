import '../models/comment.dart';
import '../services/supabase.dart';

class CommentsRepository {
  Future<List<Comment>> listFor({
    required String targetType,
    required String targetId,
  }) async {
    final rows = await supabase
        .from('comments')
        .select()
        .eq('target_type', targetType)
        .eq('target_id', targetId)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Comment.fromMap)
        .toList();
  }

  Future<Comment> add({
    required String targetType,
    required String targetId,
    required String body,
  }) async {
    final uid = supabase.auth.currentUser?.id;
    final name =
        supabase.auth.currentUser?.userMetadata?['name'] as String? ?? '匿名球友';
    final row = await supabase
        .from('comments')
        .insert({
          'target_type': targetType,
          'target_id': targetId,
          'author_id': uid,
          'author_name': name,
          'body': body,
        })
        .select()
        .single();
    return Comment.fromMap(row);
  }

  Future<void> incrementArticleViews(String articleId) async {
    await supabase.rpc('increment_article_views', params: {
      'article_id': articleId,
    });
  }
}
