// events_repository.dart
import '../models/event.dart';
import '../services/supabase.dart';

class EventsRepository {
  Future<List<Event>> listByStatus(EventStatus status) async {
    final rows = await supabase
        .from('events')
        .select()
        .eq('status', status.name)
        .order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Event.fromMap)
        .toList();
  }

  Future<Event> fetch(String id) async {
    final row = await supabase.from('events').select().eq('id', id).single();
    return Event.fromMap(row);
  }

  Future<List<Match>> matchesFor(String eventId) async {
    final rows = await supabase
        .from('matches')
        .select()
        .eq('event_id', eventId)
        .order('played_at');
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Match.fromMap)
        .toList();
  }

  Future<Event> create(Map<String, dynamic> payload) async {
    final row = await supabase.from('events').insert(payload).select().single();
    return Event.fromMap(row);
  }

  /// Leaderboard: (avg_score, votes) per rated player for this event, joined
  /// with profile (id, name, position). Sorted by avg_score desc.
  Future<List<PlayerRatingRow>> playerRatingsForEvent(String eventId) async {
    final rows = await supabase
        .from('event_player_ratings')
        .select('avg_score, votes, ratee:profiles!ratee_id(id, name, position)')
        .eq('event_id', eventId)
        .order('avg_score', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(PlayerRatingRow.fromMap)
        .toList();
  }
}
