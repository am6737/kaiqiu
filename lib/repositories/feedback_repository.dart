// feedback_repository.dart — 用户反馈
import '../services/local_storage.dart';
import '../services/supabase.dart';

class FeedbackRepository {
  /// Submit a feedback entry. Always mirrors to LocalStore history so the
  /// user sees their submission even offline.
  Future<void> submit({required String body, String? contact}) async {
    final uid = currentUserId;
    if (uid != null) {
      try {
        await supabase.from('feedback').insert({
          'user_id': uid,
          'body': body,
          if (contact != null && contact.isNotEmpty) 'contact': contact,
        });
      } catch (_) {
        // keep going — local history still gets it
      }
    }
    await LocalStore.pushFeedback(body);
  }
}
