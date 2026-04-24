// routes.dart — go_router config with auth redirect + 4-tab shell
import 'package:go_router/go_router.dart';

import 'features/article/article_detail_screen.dart';
import 'features/article/create_article_screen.dart';
import 'features/post/create_post_screen.dart';
import 'features/auth/onboarding_screen.dart';
import 'features/auth/sign_in_screen.dart';
import 'features/create_event/create_event_screen.dart';
import 'features/events/event_detail_screen.dart';
import 'features/events/events_hub_screen.dart';
import 'features/events/match_detail_screen.dart';
import 'features/events/match_ratings_screen.dart';
import 'features/events/match_live_room.dart';
import 'features/events/schedule_matches_screen.dart';
import 'features/events/wc_live_screen.dart';
import 'features/events/wc_predict_screen.dart';
import 'features/events/world_cup_screen.dart';
import 'features/home/city_picker_screen.dart';
import 'features/home/home_screen.dart';
import 'features/inbox/inbox_screen.dart';
import 'features/me/favorites_screen.dart';
import 'features/me/following_screen.dart';
import 'features/me/my_events_screen.dart';
import 'features/me/my_pickups_screen.dart';
import 'features/me/my_teams_screen.dart';
import 'features/me/my_venues_screen.dart';
import 'features/messages/chat_screen.dart';
import 'features/pickup/create_pickup_screen.dart';
import 'features/pickup/pickup_detail_screen.dart';
import 'features/pickup/pickup_map_screen.dart';
import 'features/post/post_detail_screen.dart';
import 'features/profile/player_archive_screen.dart';
import 'features/profile/profile_edit_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/profile/profile_settings_screen.dart';
import 'features/rating/formation_rating_screen.dart';
import 'features/rating/post_match_rating_screen.dart';
import 'features/search/search_screen.dart';
import 'features/venue/create_venue_screen.dart';
import 'features/venue/venue_detail_screen.dart';
import 'features/settings/about_screen.dart';
import 'features/settings/account_settings_screen.dart';
import 'features/settings/appearance_settings_screen.dart';
import 'features/settings/help_screen.dart';
import 'features/settings/legal_screen.dart';
import 'features/settings/notif_settings_screen.dart';
import 'services/auth.dart';
import 'services/supabase.dart';
import 'widgets/bottom_nav_shell.dart';

final _authRefresh = AuthRefresh();

final router = GoRouter(
  initialLocation: '/home',
  refreshListenable: _authRefresh,
  redirect: (ctx, state) {
    final signedIn = supabase.auth.currentUser != null;
    final atSignIn = state.matchedLocation == '/sign-in';
    final atOnboarding = state.matchedLocation == '/onboarding';
    if (!signedIn && !atSignIn) return '/sign-in';
    if (signedIn && atSignIn) return '/home';
    if (!signedIn && atOnboarding) return '/sign-in';
    return null;
  },
  routes: [
    GoRoute(path: '/sign-in', builder: (_, s) => const SignInScreen()),
    GoRoute(path: '/onboarding', builder: (_, s) => const OnboardingScreen()),
    // Bottom-tab shell — 4 persistent tabs
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => BottomNavShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, s) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pickup',
              builder: (_, s) => const PickupMapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/events',
              builder: (_, s) => const EventsHubScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/me', builder: (_, s) => const ProfileScreen()),
          ],
        ),
      ],
    ),
    // Full-screen overlays
    GoRoute(
      path: '/pickup/create',
      builder: (_, s) => const CreatePickupScreen(),
    ),
    GoRoute(
      path: '/pickup/:id',
      builder: (_, s) => PickupDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/article/:id',
      builder: (_, s) => ArticleDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/post/:id',
      builder: (_, s) => PostDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/event/:id',
      builder: (_, s) => EventDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/event/:eventId/match/:matchId',
      builder: (_, s) => MatchDetailScreen(
        eventId: s.pathParameters['eventId']!,
        matchId: s.pathParameters['matchId']!,
      ),
    ),
    GoRoute(
      path: '/event/:eventId/match/:matchId/ratings',
      builder: (_, s) => MatchRatingsScreen(
        eventId: s.pathParameters['eventId']!,
        matchId: s.pathParameters['matchId']!,
      ),
    ),
    GoRoute(
      path: '/event/:eventId/match/:matchId/live',
      builder: (_, s) => MatchLiveRoom(
        eventId: s.pathParameters['eventId']!,
        matchId: s.pathParameters['matchId']!,
      ),
    ),
    GoRoute(
      path: '/event/:id/schedule',
      builder: (_, s) =>
          ScheduleMatchesScreen(eventId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/worldcup', builder: (_, s) => const WorldCupScreen()),
    GoRoute(
      path: '/worldcup/live/:matchId',
      builder: (_, s) => WcLiveScreen(matchId: s.pathParameters['matchId']!),
    ),
    GoRoute(
      path: '/worldcup/predict/:matchId',
      builder: (_, s) => WcPredictScreen(matchId: s.pathParameters['matchId']!),
    ),
    GoRoute(
      path: '/create-event',
      builder: (_, s) => const CreateEventScreen(),
    ),
    GoRoute(
      path: '/create-post',
      builder: (_, s) => const CreatePostScreen(),
    ),
    GoRoute(
      path: '/create-article',
      builder: (_, s) => const CreateArticleScreen(),
    ),
    GoRoute(
      path: '/event/:id/edit',
      builder: (_, s) => CreateEventScreen(editEventId: s.pathParameters['id']),
    ),
    // Venues
    GoRoute(
      path: '/venue/create',
      builder: (_, s) => const CreateVenueScreen(),
    ),
    GoRoute(
      path: '/venue/:id',
      builder: (_, s) => VenueDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/rate/:matchId',
      builder: (_, s) =>
          PostMatchRatingScreen(matchId: s.pathParameters['matchId']!),
    ),
    GoRoute(
      path: '/rate-pitch/:pickupId',
      builder: (_, s) =>
          FormationRatingScreen(pickupId: s.pathParameters['pickupId']!),
    ),
    GoRoute(path: '/archive', builder: (_, s) => const PlayerArchiveScreen()),
    GoRoute(
      path: '/chat/:convId',
      builder: (_, s) => ChatScreen(convId: s.pathParameters['convId']!),
    ),
    // Search / notifications / city
    GoRoute(path: '/search', builder: (_, s) => const SearchScreen()),
    GoRoute(
      path: '/inbox',
      builder: (_, s) => InboxScreen(
        initialTab: switch (s.uri.queryParameters['tab']) {
          'messages' => InboxTab.messages,
          _ => InboxTab.notifications,
        },
      ),
    ),
    GoRoute(
      path: '/messages',
      redirect: (_, _) => '/inbox?tab=messages',
    ),
    GoRoute(
      path: '/notifications',
      redirect: (_, _) => '/inbox?tab=notifications',
    ),
    GoRoute(path: '/city-picker', builder: (_, s) => const CityPickerScreen()),
    // My content
    GoRoute(path: '/me/events', builder: (_, s) => const MyEventsScreen()),
    GoRoute(path: '/me/pickups', builder: (_, s) => const MyPickupsScreen()),
    GoRoute(path: '/me/teams', builder: (_, s) => const MyTeamsScreen()),
    GoRoute(path: '/me/venues', builder: (_, s) => const MyVenuesScreen()),
    GoRoute(path: '/me/favorites', builder: (_, s) => const FavoritesScreen()),
    GoRoute(path: '/me/settings', builder: (_, s) => const ProfileSettingsScreen()),
    GoRoute(
      path: '/me/following',
      builder: (_, s) {
        final tab = int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0;
        return FollowingScreen(initialTab: tab);
      },
    ),
    // Profile edit
    GoRoute(
      path: '/profile/edit',
      builder: (_, s) => const ProfileEditScreen(),
    ),
    // Settings
    GoRoute(
      path: '/settings/account',
      builder: (_, s) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/appearance',
      builder: (_, s) => const AppearanceSettingsScreen(),
    ),
    GoRoute(
      path: '/settings/notifications',
      builder: (_, s) => const NotifSettingsScreen(),
    ),
    GoRoute(path: '/settings/help', builder: (_, s) => const HelpScreen()),
    GoRoute(path: '/settings/about', builder: (_, s) => const AboutScreen()),
    GoRoute(
      path: '/settings/legal/:kind',
      builder: (_, s) => LegalScreen(kind: s.pathParameters['kind']!),
    ),
  ],
);
