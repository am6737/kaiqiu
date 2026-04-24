import '../services/supabase.dart';

class PostsRepository {
  Future<void> create({
    required String body,
    List<String> tags = const [],
    int? matchCount,
    int? winCount,
    int? playDuration,
    String? venue,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('Not signed in');
    await supabase.from('posts').insert({
      'author_id': uid,
      'body': body,
      'tags': tags,
      if (matchCount != null) 'match_count': matchCount,
      if (winCount != null) 'win_count': winCount,
      if (playDuration != null) 'play_duration': playDuration,
      if (venue != null && venue.isNotEmpty) 'venue': venue,
    });
  }
}
