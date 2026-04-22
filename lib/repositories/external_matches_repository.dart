import '../models/external_match.dart';
import '../services/supabase.dart';

class ExternalMatchesRepository {
  Future<List<ExternalMatch>> listAll() async {
    final rows = await supabase
        .from('external_matches')
        .select()
        .order('kick_off', ascending: true);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ExternalMatch.fromMap)
        .toList();
  }

  Future<List<ExternalMatch>> listLive() async {
    final rows = await supabase
        .from('external_matches')
        .select()
        .eq('is_live', true)
        .order('kick_off');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ExternalMatch.fromMap)
        .toList();
  }
}
