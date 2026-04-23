// providers.dart — Riverpod providers (Supabase-backed).
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  if (uid == null) return _mockTeammates;
  final result = await ref.read(profilesRepoProvider).teammates(uid);
  return result.isEmpty ? _mockTeammates : result;
});

final historyProvider = FutureProvider<List<MatchHistoryEntry>>((ref) async {
  final uid = currentUserId;
  if (uid == null) return _mockHistory;
  final result = await ref.read(profilesRepoProvider).matchHistory(uid);
  return result.isEmpty ? _mockHistory : result;
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

final isUserRegisteredProvider =
    FutureProvider.family<bool, String>((ref, eventId) async {
  final uid = currentUserId;
  if (uid == null) return false;
  return ref.read(eventsRepoProvider).isUserRegistered(eventId, uid);
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

/// Selected (but not yet confirmed) position on the formation.
/// Value is (position, x, y) or null when nothing is selected.
final selectedSlotProvider =
    StateProvider.family<(String, int, int)?, String>((ref, pickupId) => null);

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

/// Featured / hot events for the top carousel. Combines ongoing + registering,
/// sorted by most teams registered (popularity proxy), limited to 4.
final featuredEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repo = ref.read(eventsRepoProvider);
  final ongoing = await repo.listByStatus(EventStatus.ongoing);
  final registering = await repo.listByStatus(EventStatus.registering);
  final all = [...ongoing, ...registering];
  all.sort((a, b) => (b.teamsMax ?? 0).compareTo(a.teamsMax ?? 0));
  return all.take(4).toList();
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
  if (uid == null) return _mockProfile;
  final result = await ref.read(profilesRepoProvider).fetchFullProfile(uid);
  return result ?? _mockProfile;
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

/// List of user names the current user follows.
final myFollowingListProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(localStoreProvider);
  return ref.read(favoritesRepoProvider).list(FavoriteEntity.user);
});

/// List of user names who follow the current user.
final myFollowersListProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(localStoreProvider);
  final profile = await ref.watch(myProfileProvider.future);
  if (profile == null) return [];
  try {
    final rows = await supabase.rpc(
      'followers_list',
      params: {'target_name': profile.name},
    );
    return (rows as List).map((r) => r['follower_name'] as String).toList();
  } catch (_) {
    return [];
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
      .select('*, author:profiles!author_id(name)')
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

/// 约球 Tab — filtered pickup list (reacts to filter changes)
final filteredPickupsProvider = FutureProvider<List<Pickup>>((ref) async {
  final filter = ref.watch(pickupFilterProvider);
  return ref.read(pickupsRepoProvider).listFiltered(filter);
});

/// User device position (for distance calc)
final userPositionProvider = FutureProvider((ref) async {
  return LocationService().currentPosition();
});

// ─────────────────────────────────────────────────────────────
// Venue providers (场馆)
// ─────────────────────────────────────────────────────────────

final liveVenuesProvider = FutureProvider<List<Venue>>((ref) async {
  return ref.read(venuesRepoProvider).listAll();
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
// Mock data (development fallback)
// ─────────────────────────────────────────────────────────────
final _mockProfile = PlayerProfile(
  profile: Profile(
    id: 'mock-001',
    name: '赵铁柱',
    handle: '@tiezhu',
    city: '深圳',
    district: '南山区',
    position: 'CAM',
    height: 178,
    foot: '右脚',
    createdAt: DateTime(2023, 3, 15),
  ),
  stats: const PlayerStats(matches: 47, goals: 18, assists: 23),
  attrs: const {
    '速度': 76,
    '射门': 68,
    '传球': 82,
    '防守': 55,
    '体能': 71,
    '技术': 85,
  },
  honors: const [
    PlayerHonor(year: '2025', title: '南山秋季联赛冠军', meta: '最佳助攻'),
    PlayerHonor(year: '2025', title: '龙岗村超 MVP'),
    PlayerHonor(year: '2024', title: '深圳业余杯季军', meta: '最佳阵容'),
  ],
);

const _mockTeammates = [
  Teammate(id: 't1', name: '王大锤', matches: 32),
  Teammate(id: 't2', name: '李小龙', matches: 28),
  Teammate(id: 't3', name: '陈七', matches: 21),
  Teammate(id: 't4', name: '张飞', matches: 17),
  Teammate(id: 't5', name: '刘备', matches: 14),
];

final _mockHistory = [
  MatchHistoryEntry(
    matchId: 'm1', playedAt: DateTime(2026, 4, 18),
    eventName: '南山秋季联赛', teamA: '铁柱FC', teamB: '龙岗联合',
    scoreA: 3, scoreB: 1, myGoals: 1, myAssists: 1,
  ),
  MatchHistoryEntry(
    matchId: 'm2', playedAt: DateTime(2026, 4, 11),
    eventName: '南山秋季联赛', teamA: '铁柱FC', teamB: '宝安飞虎',
    scoreA: 2, scoreB: 2, myGoals: 0, myAssists: 1,
  ),
  MatchHistoryEntry(
    matchId: 'm3', playedAt: DateTime(2026, 4, 4),
    eventName: '深圳业余杯', teamA: '铁柱FC', teamB: '福田猎豹',
    scoreA: 4, scoreB: 2, myGoals: 2, myAssists: 0,
  ),
  MatchHistoryEntry(
    matchId: 'm4', playedAt: DateTime(2026, 3, 28),
    eventName: '深圳业余杯', teamA: '光明闪电', teamB: '铁柱FC',
    scoreA: 1, scoreB: 2, myGoals: 1, myAssists: 1,
  ),
  MatchHistoryEntry(
    matchId: 'm5', playedAt: DateTime(2026, 3, 14),
    eventName: '龙岗村超', teamA: '铁柱FC', teamB: '坪山青年',
    scoreA: 0, scoreB: 1, myGoals: 0, myAssists: 0,
  ),
];
