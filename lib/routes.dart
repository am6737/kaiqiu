// routes.dart — go_router config with auth redirect + 5-tab shell
import 'package:go_router/go_router.dart';

import 'features/auth/sign_in_screen.dart';
import 'features/create_event/create_event_screen.dart';
import 'features/events/event_detail_screen.dart';
import 'features/events/events_hub_screen.dart';
import 'features/events/world_cup_screen.dart';
import 'features/home/home_screen.dart';
import 'features/messages/chat_screen.dart';
import 'features/messages/messages_screen.dart';
import 'features/pickup/pickup_detail_screen.dart';
import 'features/pickup/pickup_map_screen.dart';
import 'features/profile/player_archive_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/rating/post_match_rating_screen.dart';
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
    if (!signedIn && !atSignIn) return '/sign-in';
    if (signedIn && atSignIn) return '/home';
    return null;
  },
  routes: [
    GoRoute(
      path: '/sign-in',
      builder: (_, s) => const SignInScreen(),
    ),
    // Bottom-tab shell — 5 persistent tabs
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => BottomNavShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (_, s) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/pickup', builder: (_, s) => const PickupMapScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/events', builder: (_, s) => const EventsHubScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/messages', builder: (_, s) => const MessagesScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/me', builder: (_, s) => const ProfileScreen()),
        ]),
      ],
    ),
    // Full-screen overlays
    GoRoute(
      path: '/pickup/:id',
      builder: (_, s) => PickupDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/event/:id',
      builder: (_, s) => EventDetailScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(
      path: '/worldcup',
      builder: (_, s) => const WorldCupScreen(),
    ),
    GoRoute(
      path: '/create-event',
      builder: (_, s) => const CreateEventScreen(),
    ),
    GoRoute(
      path: '/rate/:matchId',
      builder: (_, s) => PostMatchRatingScreen(matchId: s.pathParameters['matchId']!),
    ),
    GoRoute(
      path: '/archive',
      builder: (_, s) => const PlayerArchiveScreen(),
    ),
    GoRoute(
      path: '/chat/:convId',
      builder: (_, s) => ChatScreen(convId: s.pathParameters['convId']!),
    ),
  ],
);
