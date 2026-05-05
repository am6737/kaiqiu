// providers.dart — Riverpod providers (Supabase-backed).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

import 'models/article.dart';
import 'models/comment.dart';
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
import 'models/venue.dart';
import 'repositories/comments_repository.dart';
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
import 'repositories/likes_repository.dart';
import 'repositories/livekit_repository.dart';
import 'models/livekit_token.dart';
import 'repositories/reminders_repository.dart';
import 'repositories/user_teams_repository.dart';
import 'repositories/articles_repository.dart';
import 'repositories/posts_repository.dart';
import 'repositories/venues_repository.dart';
import 'services/amap_search_service.dart';
import 'services/local_storage.dart';
import 'services/location.dart';
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
final commentsRepoProvider = Provider((_) => CommentsRepository());
final externalMatchesRepoProvider =
    Provider((_) => ExternalMatchesRepository());
final notificationsRepoProvider =
    Provider((_) => NotificationsRepository());
final likesRepoProvider = Provider((_) => LikesRepository());
final livekitRepoProvider = Provider((_) => LiveKitRepository());
final amapSearchProvider = Provider((_) => AmapSearchService());
final venuesRepoProvider = Provider((_) => VenuesRepository());
final postsRepoProvider = Provider((_) => PostsRepository());
final articlesRepoProvider = Provider((_) => ArticlesRepository());

final likedPostIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(likesRepoProvider).likedIds('post');
});

final likedArticleIdsProvider = FutureProvider<Set<String>>((ref) async {
  return ref.read(likesRepoProvider).likedIds('article');
});

final favoriteArticleIdsProvider = FutureProvider<Set<String>>((ref) async {
  final ids = await ref.read(favoritesRepoProvider).list(FavoriteEntity.article);
  return ids.toSet();
});

final likedRatingIdsProvider = FutureProvider.family<Set<String>, String>((ref, matchId) async {
  return ref.read(ratingsRepoProvider).likedRatingIds(matchId);
});

// ─────────────────────────────────────────────────────────────
// Local storage tick — bump whenever LocalStore changes so widgets
// watching this provider rebuild.
// ─────────────────────────────────────────────────────────────
final localStoreProvider = ChangeNotifierProvider<LocalStoreNotifier>(
  (_) => localStoreNotifier,
);

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
    StreamProvider<List<NotificationItem>>((ref) {
  return ref.read(notificationsRepoProvider).streamMine();
});

final notificationsUnreadProvider = Provider<int>((ref) {
  final async = ref.watch(notificationsProvider);
  return async.maybeWhen(
    data: (list) => list.where((n) => !n.read).length,
    orElse: () => 0,
  );
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

final eventTeamsProvider =
    FutureProvider.family<List<TeamRow>, String>((ref, eventId) async {
  return ref.read(eventsRepoProvider).listTeams(eventId);
});

final isUserRegisteredProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final uid = currentUserId;
  if (uid == null) return false;
  return ref.read(eventsRepoProvider).isUserRegistered(eventId, uid);
});

final userTeamIdProvider =
    FutureProvider.family<String?, String>((ref, eventId) async {
  final uid = currentUserId;
  if (uid == null) return null;
  return ref.read(eventsRepoProvider).getUserTeamId(eventId, uid);
});

final teamDetailProvider =
    FutureProvider.family<TeamRow, String>((ref, teamId) async {
  return ref.read(eventsRepoProvider).fetchTeamDetail(teamId);
});

final teamMembersProvider =
    FutureProvider.family<List<TeamMember>, String>((ref, teamId) async {
  return ref.read(eventsRepoProvider).listTeamMembers(teamId);
});

final profileSearchProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().length < 2) return [];
  return ref.read(eventsRepoProvider).searchProfiles(query);
});

final individualRegistrationsProvider =
    FutureProvider.family<List<IndividualRegistration>, String>((ref, eventId) async {
  return ref.read(eventsRepoProvider).listIndividualRegistrations(eventId);
});

final isUserIndividuallyRegisteredProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final uid = currentUserId;
  if (uid == null) return false;
  return ref.read(eventsRepoProvider).isUserIndividuallyRegistered(eventId, uid);
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

/// All pickups in the selected city, from Supabase. Sorted by start_at.
final livePickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final city = ref.watch(cityProvider);
  return ref.read(pickupsRepoProvider).listAll(city: city);
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

/// Selected (but not yet confirmed) position on the formation.
/// Value is (position, x, y) or null when nothing is selected.
final selectedSlotProvider =
    StateProvider.family<(String, int, int)?, String>((ref, pickupId) => null);

/// Conversations the current user belongs to (Messages tab root).
/// Uses Realtime to auto-refresh when new messages arrive.
final conversationsProvider = StreamProvider<List<ConversationRow>>((ref) {
  return ref.read(messagesRepoProvider).streamConversations();
});

/// `true` if any conversation has `unread > 0`. Used for inbox unread dot.
final messagesUnreadProvider = Provider<bool>((ref) {
  final async = ref.watch(conversationsProvider);
  return async.maybeWhen(
    data: (list) => list.any((c) => c.unread > 0),
    orElse: () => false,
  );
});

/// Global stream of new messages from other users (for in-app notifications).
final globalNewMessageProvider = StreamProvider<Message>((ref) {
  return ref.read(messagesRepoProvider).streamGlobalNewMessages();
});

/// Currently active chat conversation id. Set by ChatScreen to suppress
/// in-app notifications for the conversation the user is already viewing.
final activeConvIdProvider = StateProvider<String?>((ref) => null);

/// Live stream of messages in a conversation (Realtime).
final chatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  convId,
) {
  return ref.read(messagesRepoProvider).streamMessages(convId);
});

/// Featured / hot events for the top carousel. Combines ongoing + registering,
/// sorted by most teams registered (popularity proxy), limited to 4.
final featuredEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repo = ref.read(eventsRepoProvider);
  final city = ref.watch(cityProvider);
  final ongoing = await repo.listByStatus(EventStatus.ongoing, city: city);
  final registering = await repo.listByStatus(EventStatus.registering, city: city);
  final all = [...ongoing, ...registering];
  all.sort((a, b) => (b.teamsMax ?? 0).compareTo(a.teamsMax ?? 0));
  return all.take(4).toList();
});

/// Events filtered by status (Events Hub tab). Sorted newest first.
final liveEventsProvider = FutureProvider.family<List<Event>, EventStatus>((
  ref,
  status,
) async {
  final city = ref.watch(cityProvider);
  return ref.read(eventsRepoProvider).listByStatus(status, city: city);
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

/// LiveKit token for a match room.
final livekitTokenProvider =
    FutureProvider.family<LiveKitToken, String>((ref, matchId) async {
  return ref.read(livekitRepoProvider).getToken(matchId);
});

/// Real-time match updates via Supabase Realtime (score, status, minute).
final matchRealtimeProvider =
    StreamProvider.family<Match, String>((ref, matchId) {
  return supabase
      .from('matches')
      .stream(primaryKey: ['id'])
      .eq('id', matchId)
      .map((rows) => Match.fromMap(rows.first));
});

/// Live matches for a given event (status='live').
final liveMatchesForEventProvider =
    FutureProvider.family<List<Match>, String>((ref, eventId) async {
  return ref.read(eventsRepoProvider).liveMatchesForEvent(eventId);
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

final myRegisteredEventsProvider = FutureProvider<List<Event>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(eventsRepoProvider).listRegisteredByUser(uid);
});

final myFavoriteEventsProvider = FutureProvider<List<Event>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  final ids = await ref.read(favoritesRepoProvider).list(FavoriteEntity.event);
  if (ids.isEmpty) return [];
  return ref.read(eventsRepoProvider).listByIds(ids);
});

final myFavoritePickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  final ids = await ref.read(favoritesRepoProvider).list(FavoriteEntity.pickup);
  if (ids.isEmpty) return [];
  return ref.read(pickupsRepoProvider).listByIds(ids);
});

/// 我的动态 — all posts authored by current user.
final myActivitiesProvider = FutureProvider<List<FeedActivity>>((ref) async {
  return ref.read(feedRepoProvider).myActivities();
});

/// 我的文章 — articles authored by current user.
final myArticlesProvider = FutureProvider<List<FeedArticle>>((ref) async {
  return ref.read(feedRepoProvider).myArticles();
});

final userFollowingCountProvider =
    FutureProvider.family.autoDispose<int, String>((ref, userId) async {
  try {
    final rows = await supabase
        .from('favorites')
        .select('id')
        .eq('user_id', userId)
        .eq('entity_type', 'user');
    return (rows as List).length;
  } catch (_) {
    return 0;
  }
});

final userFollowersCountProvider =
    FutureProvider.family.autoDispose<int, String>((ref, userId) async {
  try {
    final result = await supabase.rpc(
      'followers_count',
      params: {'target_id': userId},
    );
    return (result as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

final userPickupsProvider =
    FutureProvider.family.autoDispose<List<({Pickup pickup, bool isHost})>, String>(
        (ref, userId) async {
  final repo = ref.read(pickupsRepoProvider);
  final results = await Future.wait([
    repo.listByHost(userId, limit: 10),
    repo.listJoinedBy(userId, limit: 10),
  ]);
  final hosted = results[0];
  final joined = results[1];
  final hostedIds = hosted.map((p) => p.id).toSet();
  final items = <({Pickup pickup, bool isHost})>[
    for (final p in hosted) (pickup: p, isHost: true),
    for (final p in joined)
      if (!hostedIds.contains(p.id)) (pickup: p, isHost: false),
  ];
  items.sort((a, b) => b.pickup.startAt.compareTo(a.pickup.startAt));
  return items;
});

final userActivitiesProvider =
    FutureProvider.family.autoDispose<List<FeedActivity>, String>(
        (ref, userId) async {
  return ref.read(feedRepoProvider).userActivities(userId, limit: 50);
});

final userArticlesProvider =
    FutureProvider.family.autoDispose<List<FeedArticle>, String>(
        (ref, userId) async {
  return ref.read(feedRepoProvider).userArticles(userId, limit: 50);
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

/// Any user's full profile (profile + stats + attrs + honors) by id.
final fullProfileByIdProvider =
    FutureProvider.family.autoDispose<PlayerProfile?, String>((ref, uid) async {
  return ref.read(profilesRepoProvider).fetchFullProfile(uid);
});

/// Current user's full profile from Supabase (profile + stats + attrs + honors).
final myProfileProvider = FutureProvider<PlayerProfile?>((ref) async {
  ref.watch(localStoreProvider);
  final uid = currentUserId;
  if (uid == null) return null;
  return ref.read(profilesRepoProvider).fetchFullProfile(uid);
});

/// Number of users the current user follows.
final followingCountProvider = FutureProvider<int>((ref) async {
  final uid = currentUserId;
  if (uid == null) return 0;
  return ref.read(favoritesRepoProvider).list(FavoriteEntity.user).then((l) => l.length);
});

/// Number of users who follow the current user.
final followersCountProvider = FutureProvider<int>((ref) async {
  final uid = currentUserId;
  if (uid == null) return 0;
  try {
    final result = await supabase.rpc(
      'followers_count',
      params: {'target_id': uid},
    );
    return (result as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

/// List of user IDs the current user follows.
final myFollowingListProvider = FutureProvider<List<String>>((ref) async {
  return ref.read(favoritesRepoProvider).list(FavoriteEntity.user);
});

/// Users who follow the current user: (id, name) pairs.
final myFollowersListProvider =
    FutureProvider<List<({String id, String name})>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  try {
    final rows = await supabase.rpc(
      'followers_list',
      params: {'target_id': uid},
    );
    return (rows as List)
        .map((r) => (
              id: r['follower_id'] as String,
              name: r['follower_name'] as String,
            ))
        .toList();
  } catch (_) {
    return [];
  }
});

/// Whether the current user is following [targetId].
final isFollowingProvider =
    FutureProvider.family.autoDispose<bool, String>((ref, targetId) async {
  final uid = currentUserId;
  if (uid == null) return false;
  try {
    final result = await supabase.rpc(
      'is_following',
      params: {'target_id': targetId},
    );
    return result as bool? ?? false;
  } catch (_) {
    return false;
  }
});

// ── Home Tab Providers ──────────────────────────────────

/// 推荐 Tab — mixed feed of all content types, filtered by city
final recommendFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final city = ref.watch(cityProvider);
  return ref.read(feedRepoProvider).buildRecommendFeed(city: city);
});

/// 发现 Tab — posts (with activity) + articles, filtered by city
final discoverFeedProvider = FutureProvider<List<FeedItem>>((ref) async {
  final city = ref.watch(cityProvider);
  return ref.read(feedRepoProvider).buildDiscoverFeed(city: city);
});

/// Single article detail by id.
final articleDetailProvider = FutureProvider.family<Article, String>((
  ref,
  id,
) async {
  final row = await supabase.from('articles').select().eq('id', id).single();
  return Article.fromMap(row);
});

/// Single post detail by id (posts + activity fields).
final postDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, id) async {
  final row = await supabase
      .from('posts')
      .select('*, author:profiles!author_id(name, avatar_url)')
      .eq('id', id)
      .single();
  return row;
});

/// Comments for a given target (article or post).
final commentsProvider =
    FutureProvider.family<List<Comment>, ({String type, String id})>((
  ref,
  target,
) async {
  return ref
      .read(commentsRepoProvider)
      .listFor(targetType: target.type, targetId: target.id);
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

/// 约球 Tab — filtered pickup list (reacts to filter + city changes)
final filteredPickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final filter = ref.watch(pickupFilterProvider);
  final city = ref.watch(cityProvider);
  return ref.read(pickupsRepoProvider).listFiltered(filter, city: city);
});

/// User device position (for distance calc)
final userPositionProvider = FutureProvider((ref) async {
  return LocationService().currentPosition();
});

// ─────────────────────────────────────────────────────────────
// Venue providers (场馆)
// ─────────────────────────────────────────────────────────────

final liveVenuesProvider = FutureProvider<List<Venue>>((ref) async {
  final city = ref.watch(cityProvider);
  return ref.read(venuesRepoProvider).listAll(city: city);
});

final venueDetailProvider = FutureProvider.family<Venue, String>((
  ref,
  id,
) async {
  return ref.read(venuesRepoProvider).fetch(id);
});

final venueBookingsProvider =
    FutureProvider.family<List<VenueBooking>, ({String venueId, DateTime? date})>((
  ref,
  params,
) async {
  return ref
      .read(venuesRepoProvider)
      .bookingsForVenue(params.venueId, date: params.date);
});

final myVenuesProvider = FutureProvider<List<Venue>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(venuesRepoProvider).listByOwner(uid);
});

final myBookingsProvider = FutureProvider<List<VenueBooking>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(venuesRepoProvider).bookingsByUser(uid);
});

final venueOwnerBookingsProvider =
    FutureProvider<List<VenueBooking>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return [];
  return ref.read(venuesRepoProvider).bookingsForOwner(uid);
});

// ─────────────────────────────────────────────────────────────
// Live stream (LiveKit) — room survives page navigation
// ─────────────────────────────────────────────────────────────

class LiveStreamManager extends ChangeNotifier {
  Room? _room;

  bool get isActive => _room != null;
  Room? get room => _room;

  void setRoom(Room room) {
    _room = room;
    notifyListeners();
  }

  Future<void> stop() async {
    await _room?.disconnect();
    _room = null;
    notifyListeners();
  }
}

final liveStreamProvider = ChangeNotifierProvider<LiveStreamManager>(
  (_) => LiveStreamManager(),
);

