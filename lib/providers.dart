// providers.dart — Riverpod providers.
// Mixed: some screens use MOCK (Home feed non-pickup items, events, profile),
// pickups now read from Supabase.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock.dart' as mock;
import 'models/event.dart';
import 'models/message.dart';
import 'models/pickup.dart';
import 'repositories/events_repository.dart';
import 'repositories/messages_repository.dart';
import 'repositories/pickups_repository.dart';
import 'repositories/ratings_repository.dart';
import 'services/supabase.dart';

// ─────────────────────────────────────────────────────────────
// Stable demo UUIDs — must match seed 03_demo_match.sql.
// ─────────────────────────────────────────────────────────────
const demoMatchId = '22222222-2222-2222-2222-222222222222';

// ─────────────────────────────────────────────────────────────
// Repositories
// ─────────────────────────────────────────────────────────────
final pickupsRepoProvider = Provider((_) => PickupsRepository());
final eventsRepoProvider = Provider((_) => EventsRepository());
final ratingsRepoProvider = Provider((_) => RatingsRepository());
final messagesRepoProvider = Provider((_) => MessagesRepository());

// ─────────────────────────────────────────────────────────────
// Mock data providers (prototype mode)
// ─────────────────────────────────────────────────────────────
final userProvider = Provider((_) => mock.user);
final pickupsProvider = Provider((_) => mock.pickups);
final eventsProvider = Provider((_) => mock.events);
final feedsProvider = Provider((_) => mock.feeds);
final liveNowProvider = Provider((_) => mock.liveNow);
final wcMatchesProvider = Provider((_) => mock.wcMatches);
final standingsProvider = Provider((_) => mock.standings);
final scorersProvider = Provider((_) => mock.scorers);
final bracketProvider = Provider((_) => mock.bracket);
final lineupProvider = Provider((_) => mock.lineup);
final teammatesProvider = Provider((_) => mock.teammates);
final historyProvider = Provider((_) => mock.history);
final messageThreadsProvider = Provider((_) => mock.messageThreads);
final hotRatedProvider = Provider((_) => mock.hotRated);

// Sport selection (for top bar)
final sportProvider = StateProvider<String>((_) => 'football');
final cityProvider = StateProvider<String>((_) => '深圳');

// ─────────────────────────────────────────────────────────────
// Live data providers (Supabase)
// ─────────────────────────────────────────────────────────────

/// All pickups in the city, from Supabase. Sorted by start_at.
final livePickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  return ref.read(pickupsRepoProvider).listAll();
});

/// Single pickup by id.
final pickupDetailProvider =
    FutureProvider.family<Pickup, String>((ref, id) async {
  return ref.read(pickupsRepoProvider).fetch(id);
});

/// Slots belonging to a pickup. Invalidate after a join/leave to refresh.
final pickupSlotsProvider =
    FutureProvider.family<List<PickupSlot>, String>((ref, id) async {
  return ref.read(pickupsRepoProvider).slotsFor(id);
});

/// Conversations the current user belongs to (Messages tab root).
final conversationsProvider =
    FutureProvider<List<ConversationRow>>((ref) async {
  return ref.read(messagesRepoProvider).listConversations();
});

/// Live stream of messages in a conversation (Realtime).
final chatMessagesProvider =
    StreamProvider.family<List<Message>, String>((ref, convId) {
  return ref.read(messagesRepoProvider).streamMessages(convId);
});

/// Events filtered by status (Events Hub tab). Sorted newest first.
final liveEventsProvider =
    FutureProvider.family<List<Event>, EventStatus>((ref, status) async {
  return ref.read(eventsRepoProvider).listByStatus(status);
});

/// Single event detail by id.
final eventDetailProvider =
    FutureProvider.family<Event, String>((ref, id) async {
  return ref.read(eventsRepoProvider).fetch(id);
});

/// All matches of an event (bracket / standings source).
final eventMatchesProvider =
    FutureProvider.family<List<Match>, String>((ref, eventId) async {
  return ref.read(eventsRepoProvider).matchesFor(eventId);
});

/// Player rating leaderboard for an event (avg_score desc).
final eventPlayerRatingsProvider =
    FutureProvider.family<List<PlayerRatingRow>, String>((ref, id) async {
  return ref.read(eventsRepoProvider).playerRatingsForEvent(id);
});

/// Current user's profile — real fields from Supabase (name, handle, city,
/// position, height, foot), plus mock fallbacks for fields the DB doesn't
/// carry yet (rating / stats / attrs / honors — those need real match data).
final myProfileProvider = FutureProvider<mock.MockUser>((ref) async {
  final uid = currentUserId;
  if (uid == null) return mock.user;

  final row = await supabase
      .from('profiles')
      .select()
      .eq('id', uid)
      .maybeSingle();
  if (row == null) return mock.user;

  return mock.MockUser(
    name: (row['name'] as String?) ?? '新球友',
    handle: (row['handle'] as String?) ?? '@${uid.substring(0, 6)}',
    city: (row['city'] as String?) ?? mock.user.city,
    district: (row['district'] as String?) ?? mock.user.district,
    position: (row['position'] as String?) ?? mock.user.position,
    positionFull: mock.user.positionFull, // mock
    rating: mock.user.rating, // mock
    height: (row['height'] as int?) ?? mock.user.height,
    foot: (row['foot'] as String?) ?? mock.user.foot,
    stats: mock.user.stats, // mock
    attrs: mock.user.attrs, // mock
    honors: mock.user.honors, // mock
  );
});
