// providers.dart — Riverpod providers.
// Mixed: some screens use MOCK (Home feed non-pickup items, events, profile),
// pickups now read from Supabase.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/mock.dart' as mock;
import 'models/event.dart';
import 'models/message.dart';
import 'models/pickup.dart';
import 'models/profile.dart';
import 'repositories/events_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/feedback_repository.dart';
import 'repositories/goals_repository.dart';
import 'repositories/messages_repository.dart';
import 'repositories/pickups_repository.dart';
import 'repositories/predictions_repository.dart';
import 'repositories/profiles_repository.dart';
import 'repositories/ratings_repository.dart';
import 'repositories/reminders_repository.dart';
import 'repositories/user_teams_repository.dart';
import 'services/local_storage.dart';
import 'services/supabase.dart';

// ─────────────────────────────────────────────────────────────
// Stable demo UUIDs — must match supabase/seed/demo.sql.
// ─────────────────────────────────────────────────────────────
const demoMatchId = '22222222-2222-2222-2222-222222222222';

// ─────────────────────────────────────────────────────────────
// Repositories
// ─────────────────────────────────────────────────────────────
final pickupsRepoProvider = Provider((_) => PickupsRepository());
final eventsRepoProvider = Provider((_) => EventsRepository());
final ratingsRepoProvider = Provider((_) => RatingsRepository());
final messagesRepoProvider = Provider((_) => MessagesRepository());
final profilesRepoProvider = Provider((_) => ProfilesRepository());
final userTeamsRepoProvider = Provider((_) => UserTeamsRepository());
final goalsRepoProvider = Provider((_) => GoalsRepository());
final predictionsRepoProvider = Provider((_) => PredictionsRepository());
final remindersRepoProvider = Provider((_) => RemindersRepository());
final favoritesRepoProvider = Provider((_) => FavoritesRepository());
final feedbackRepoProvider = Provider((_) => FeedbackRepository());

// ─────────────────────────────────────────────────────────────
// Local storage tick — bump whenever LocalStore changes so widgets
// watching this provider rebuild.
// ─────────────────────────────────────────────────────────────
final localStoreProvider = ChangeNotifierProvider<LocalStoreNotifier>(
  (_) => localStoreNotifier,
);

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
// City now backed by LocalStore so it persists across launches.
final cityProvider = StateProvider<String>((ref) {
  ref.watch(localStoreProvider);
  return LocalStore.city;
});

// ─────────────────────────────────────────────────────────────
// Live data providers (Supabase)
// ─────────────────────────────────────────────────────────────

/// All pickups in the city, from Supabase. Sorted by start_at.
final livePickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  return ref.read(pickupsRepoProvider).listAll();
});

/// Single pickup by id.
final pickupDetailProvider = FutureProvider.family<Pickup, String>((
  ref,
  id,
) async {
  return ref.read(pickupsRepoProvider).fetch(id);
});

/// Slots belonging to a pickup. Invalidate after a join/leave to refresh.
final pickupSlotsProvider = FutureProvider.family<List<PickupSlot>, String>((
  ref,
  id,
) async {
  return ref.read(pickupsRepoProvider).slotsFor(id);
});

/// Conversations the current user belongs to (Messages tab root).
final conversationsProvider = FutureProvider<List<ConversationRow>>((
  ref,
) async {
  return ref.read(messagesRepoProvider).listConversations();
});

/// Live stream of messages in a conversation (Realtime).
final chatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  convId,
) {
  return ref.read(messagesRepoProvider).streamMessages(convId);
});

/// Events filtered by status (Events Hub tab). Sorted newest first.
final liveEventsProvider = FutureProvider.family<List<Event>, EventStatus>((
  ref,
  status,
) async {
  return ref.read(eventsRepoProvider).listByStatus(status);
});

/// Single event detail by id.
final eventDetailProvider = FutureProvider.family<Event, String>((
  ref,
  id,
) async {
  return ref.read(eventsRepoProvider).fetch(id);
});

/// All matches of an event (bracket / standings source).
final eventMatchesProvider = FutureProvider.family<List<Match>, String>((
  ref,
  eventId,
) async {
  return ref.read(eventsRepoProvider).matchesFor(eventId);
});

/// Player rating leaderboard for an event (avg_score desc).
final eventPlayerRatingsProvider =
    FutureProvider.family<List<PlayerRatingRow>, String>((ref, id) async {
      return ref.read(eventsRepoProvider).playerRatingsForEvent(id);
    });

/// Per-match player rating leaderboard (aggregates raw ratings + goals).
final matchPlayerRatingsProvider =
    FutureProvider.family<List<PlayerRatingRow>, Match>((ref, match) async {
      return ref.read(eventsRepoProvider).playerRatingsForMatch(match);
    });

/// Event-scoped discussion conversation id (creates one if missing).
final eventChatConvProvider = FutureProvider.family<String, String>((
  ref,
  eventId,
) async {
  return ref.read(messagesRepoProvider).ensureEventConversation(eventId);
});

/// Live messages for an event's discussion — layered on top of
/// [eventChatConvProvider] so the convId is ensured first.
final eventChatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  eventId,
) async* {
  final convId = await ref.watch(eventChatConvProvider(eventId).future);
  yield* ref.read(messagesRepoProvider).streamMessages(convId);
});

// ─────────────────────────────────────────────────────────────
// My content providers (for /me/*)
// ─────────────────────────────────────────────────────────────

final myHostedPickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(pickupsRepoProvider).listByHost(uid);
});

final myJoinedPickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(pickupsRepoProvider).listJoinedBy(uid);
});

final myHostedEventsProvider = FutureProvider<List<Event>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(eventsRepoProvider).listByCreator(uid);
});

final myFavoriteEventsProvider = FutureProvider<List<Event>>((ref) async {
  ref.watch(localStoreProvider);
  final ids = LocalStore.favoriteEvents.toList();
  if (ids.isEmpty) return [];
  return ref.read(eventsRepoProvider).listByIds(ids);
});

final myFavoritePickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  ref.watch(localStoreProvider);
  final ids = LocalStore.favoritePickups;
  if (ids.isEmpty) return [];
  // Filter from the full list to avoid needing a dedicated RPC.
  final all = await ref.read(pickupsRepoProvider).listAll();
  return all.where((p) => ids.contains(p.id)).toList();
});

// ─────────────────────────────────────────────────────────────
// S3 providers (user_teams / goals / predictions / reminders / favorites)
// ─────────────────────────────────────────────────────────────

final myTeamsProvider = FutureProvider<List<UserTeam>>((ref) async {
  ref.watch(localStoreProvider);
  return ref.read(userTeamsRepoProvider).listMine();
});

final eventScorersProvider = FutureProvider.family<List<ScorerRow>, String>((
  ref,
  eventId,
) async {
  return ref.read(goalsRepoProvider).scorersForEvent(eventId);
});

final matchGoalsProvider = FutureProvider.family<List<GoalEvent>, String>((
  ref,
  matchId,
) async {
  return ref.read(goalsRepoProvider).listForMatch(matchId);
});

final myPredictionProvider = FutureProvider.family<Prediction?, String>((
  ref,
  matchId,
) async {
  ref.watch(localStoreProvider);
  return ref.read(predictionsRepoProvider).getMine(matchId);
});

final predictionDistProvider =
    FutureProvider.family<PredictionDistribution, String>((ref, matchId) async {
      return ref.read(predictionsRepoProvider).distribution(matchId);
    });

final myRemindersProvider = FutureProvider<List<MatchReminder>>((ref) async {
  ref.watch(localStoreProvider);
  return ref.read(remindersRepoProvider).listMine();
});

/// Fetch any profile by id (cached per id via autoDispose + family).
final profileByIdProvider = FutureProvider.family.autoDispose<Profile?, String>(
  (ref, id) async {
    return ref.read(profilesRepoProvider).fetch(id);
  },
);

/// Current user's profile — real fields from Supabase (name, handle, city,
/// position, height, foot), plus mock fallbacks for fields the DB doesn't
/// carry yet (rating / stats / attrs / honors — those need real match data).
final myProfileProvider = FutureProvider<mock.MockUser>((ref) async {
  ref.watch(localStoreProvider);
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
