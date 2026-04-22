// providers.dart — Riverpod providers (Supabase-backed).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/event.dart';
import 'models/external_match.dart';
import 'models/feed.dart';
import 'models/live_match.dart';
import 'models/match_history.dart';
import 'models/message.dart';
import 'models/notification_item.dart';
import 'models/pickup.dart';
import 'models/pickup_filter.dart';
import 'models/player_profile.dart';
import 'models/profile.dart';
import 'models/teammate.dart';
import 'repositories/events_repository.dart';
import 'repositories/external_matches_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/feed_repository.dart';
import 'repositories/feedback_repository.dart';
import 'repositories/goals_repository.dart';
import 'repositories/messages_repository.dart';
import 'repositories/notifications_repository.dart';
import 'repositories/pickups_repository.dart';
import 'repositories/predictions_repository.dart';
import 'repositories/profiles_repository.dart';
import 'repositories/ratings_repository.dart';
import 'repositories/reminders_repository.dart';
import 'repositories/user_teams_repository.dart';
import 'services/local_storage.dart';
import 'services/supabase.dart';

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
final feedRepoProvider = Provider((_) => FeedRepository());
final externalMatchesRepoProvider =
    Provider((_) => ExternalMatchesRepository());
final notificationsRepoProvider =
    Provider((_) => NotificationsRepository());

// ─────────────────────────────────────────────────────────────
// Local storage tick — bump whenever LocalStore changes so widgets
// watching this provider rebuild.
// ─────────────────────────────────────────────────────────────
final localStoreProvider = ChangeNotifierProvider<LocalStoreNotifier>(
  (_) => localStoreNotifier,
);

// ─────────────────────────────────────────────────────────────
// Live data providers (replacing former mock providers)
// ─────────────────────────────────────────────────────────────
final feedsProvider = FutureProvider<List<FeedItem>>((ref) async {
  return ref.read(feedRepoProvider).buildFeed();
});

final liveNowProvider = FutureProvider<List<LiveMatch>>((ref) async {
  final rows = await supabase
      .from('matches')
      .select('id, event_id, team_a_label, team_b_label, score_a, score_b, minute, viewers, poster_url')
      .eq('is_live', true)
      .order('viewers', ascending: false);
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map(LiveMatch.fromMap)
      .toList();
});

final wcMatchesProvider = FutureProvider<List<ExternalMatch>>((ref) async {
  return ref.read(externalMatchesRepoProvider).listAll();
});

final teammatesProvider = FutureProvider<List<Teammate>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(profilesRepoProvider).teammates(uid);
});

final historyProvider = FutureProvider<List<MatchHistoryEntry>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(profilesRepoProvider).matchHistory(uid);
});

final notificationsProvider =
    FutureProvider<List<NotificationItem>>((ref) async {
  return ref.read(notificationsRepoProvider).listMine();
});

final notificationsUnreadProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationsRepoProvider).unreadCount();
});

final latestUnratedMatchProvider = FutureProvider<String?>((ref) async {
  final uid = currentUserId;
  if (uid == null) return null;
  final rows = await supabase
      .from('matches')
      .select('id')
      .eq('done', true)
      .order('played_at', ascending: false)
      .limit(1);
  if (rows.isEmpty) return null;
  return rows[0]['id'] as String?;
});

final hotTagsProvider = FutureProvider<List<String>>((ref) async {
  final rows = await supabase
      .from('hot_tags')
      .select('label')
      .eq('active', true)
      .order('sort_order');
  return (rows as List)
      .cast<Map<String, dynamic>>()
      .map((m) => m['label'] as String)
      .toList();
});

final eventTeamsCountProvider =
    FutureProvider.family<int, String>((ref, eventId) async {
  final rows = await supabase
      .from('event_teams_count')
      .select('teams_registered')
      .eq('event_id', eventId)
      .maybeSingle();
  if (rows == null) return 0;
  return (rows['teams_registered'] as num?)?.toInt() ?? 0;
});

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

/// `true` if any conversation has `unread > 0`. Used for inbox unread dot.
final messagesUnreadProvider = Provider<bool>((ref) {
  final async = ref.watch(conversationsProvider);
  return async.maybeWhen(
    data: (list) => list.any((c) => c.unread > 0),
    orElse: () => false,
  );
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

/// Profile of the peer (the non-me member) of a 1v1 DM conversation.
/// Returns null for group conversations or if the peer profile isn't found.
final dmPeerProfileProvider =
    FutureProvider.family.autoDispose<Profile?, String>((ref, convId) async {
  final peerId = await ref.read(messagesRepoProvider).fetchDmPeerId(convId);
  if (peerId == null) return null;
  return ref.watch(profileByIdProvider(peerId).future);
});

/// Look up a single conversation by its id from the cached conversations
/// list. Returns null while [conversationsProvider] is still loading or if
/// no match is found.
final conversationByIdProvider =
    Provider.family.autoDispose<ConversationRow?, String>((ref, convId) {
  final list = ref.watch(conversationsProvider).valueOrNull;
  if (list == null) return null;
  for (final c in list) {
    if (c.id == convId) return c;
  }
  return null;
});

/// Current user's full profile from Supabase (profile + stats + attrs + honors).
final myProfileProvider = FutureProvider<PlayerProfile?>((ref) async {
  ref.watch(localStoreProvider);
  final uid = currentUserId;
  if (uid == null) return null;
  return ref.read(profilesRepoProvider).fetchFullProfile(uid);
});

/// Number of users the current user follows (local cache).
final followingCountProvider = Provider<int>((ref) {
  ref.watch(localStoreProvider);
  return LocalStore.followedUsers.length;
});

/// Number of users who follow the current user (Supabase RPC).
final followersCountProvider = FutureProvider<int>((ref) async {
  ref.watch(localStoreProvider);
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null) return 0;
  try {
    final result = await supabase.rpc(
      'followers_count',
      params: {'target_name': profile.name},
    );
    return (result as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

// ── Home Tab Providers ──────────────────────────────────

/// 推荐 Tab — mixed feed of all content types
final recommendFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  return ref.read(feedRepoProvider).buildRecommendFeed();
});

/// 发现 Tab — posts (with activity) + articles
final discoverFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  return ref.read(feedRepoProvider).buildDiscoverFeed();
});

/// 赛事 Tab — events grouped by status
final eventsByStatusProvider =
    FutureProvider<Map<String, List<FeedEvent>>>((ref) async {
  return ref.read(feedRepoProvider).eventsByStatus();
});

/// 约球 Tab — pickup filter state
final pickupFilterProvider = StateProvider<PickupFilter>(
  (_) => const PickupFilter(),
);

/// 约球 Tab — filtered pickup list (reacts to filter changes)
final filteredPickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final filter = ref.watch(pickupFilterProvider);
  return ref.read(pickupsRepoProvider).listFiltered(filter);
});
