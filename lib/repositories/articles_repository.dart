import '../services/supabase.dart';

class ArticlesRepository {
  Future<void> create({
    required String title,
    required String body,
    String category = 'analysis',
    String? summary,
    String? city,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    await supabase.from('articles').insert({
      'author_id': uid,
      'title': title,
      'body': body,
      'category': category,
      if (summary != null && summary.isNotEmpty) 'summary': summary,
      if (city != null) 'city': city,
    });
  }
}
