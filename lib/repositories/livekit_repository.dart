import 'package:supabase_flutter/supabase_flutter.dart' show HttpMethod;

import '../models/livekit_token.dart';
import '../services/supabase.dart';

class LiveKitRepository {
  Future<LiveKitToken> getToken(String matchId) async {
    final res = await supabase.functions.invoke(
      'livekit-token',
      body: {'matchId': matchId},
    );
    if (res.status != 200) {
      throw Exception('Failed to get LiveKit token: ${res.data}');
    }
    return LiveKitToken.fromMap(res.data as Map<String, dynamic>);
  }

  Future<({int participantCount, bool isActive})> getRoomInfo(
    String matchId,
  ) async {
    final res = await supabase.functions.invoke(
      'room-info',
      method: HttpMethod.get,
      queryParameters: {'matchId': matchId},
    );
    if (res.status != 200) {
      return (participantCount: 0, isActive: false);
    }
    final data = res.data as Map<String, dynamic>;
    return (
      participantCount: (data['participantCount'] as int?) ?? 0,
      isActive: (data['isActive'] as bool?) ?? false,
    );
  }
}
