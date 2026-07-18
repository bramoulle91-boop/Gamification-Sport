import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/friends/friends_screen.dart';
import '../screens/gyms/gym_detail_screen.dart';
import '../screens/gyms/gym_map_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/main_shell.dart';
import '../screens/leaderboard/leaderboard_screen.dart';
import '../screens/machines/log_performance_screen.dart';
import '../screens/machines/machine_scan_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/programs/create_program_screen.dart';
import '../screens/programs/program_calendar_screen.dart';
import '../screens/rewards/rewards_shop_screen.dart';
import '../screens/validation/camera_proof_screen.dart';
import '../screens/validation/friend_qr_scan_screen.dart';
import '../screens/validation/friend_qr_validation_screen.dart';
import '../screens/validation/level2_choice_screen.dart';
import '../screens/validation/level3_submit_screen.dart';
import '../screens/validation/peer_jury_screen.dart';
import '../screens/validation/staff_validation_screen.dart';
import '../services/providers.dart';

double _weightParam(GoRouterState state) =>
    double.tryParse(state.uri.queryParameters['weight'] ?? '') ?? 0;
int _repsParam(GoRouterState state) => int.tryParse(state.uri.queryParameters['reps'] ?? '') ?? 0;

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(currentUserIdProvider);

  return GoRouter(
    initialLocation: '/home',
    // Pas de connexion requise pour visiter l'app : les écrans affichent des
    // données de démonstration tant qu'il n'y a pas de session (voir
    // currentProfileProvider). On évite juste de montrer /login ou /signup
    // à quelqu'un déjà connecté.
    redirect: (context, state) {
      final loggedIn = authState != null;
      final loggingInRoute =
          state.matchedLocation == '/login' || state.matchedLocation == '/signup';
      if (loggedIn && loggingInRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
          GoRoute(path: '/leaderboard', builder: (context, state) => const LeaderboardScreen()),
          GoRoute(path: '/friends', builder: (context, state) => const FriendsScreen()),
          GoRoute(path: '/rewards', builder: (context, state) => const RewardsShopScreen()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        ],
      ),
      GoRoute(path: '/scan', builder: (context, state) => const MachineScanScreen()),
      GoRoute(path: '/programs/create', builder: (context, state) => const CreateProgramScreen()),
      GoRoute(path: '/programs/calendar', builder: (context, state) => const ProgramCalendarScreen()),
      GoRoute(path: '/gyms/map', builder: (context, state) => const GymMapScreen()),
      GoRoute(
        path: '/gyms/:gymId',
        builder: (context, state) => GymDetailScreen(gymId: state.pathParameters['gymId']!),
      ),
      GoRoute(
        path: '/log-performance/:machineId',
        builder: (context, state) => LogPerformanceScreen(
          machineId: state.pathParameters['machineId']!,
        ),
      ),
      GoRoute(
        path: '/validation/level2-choice/:machineId',
        builder: (context, state) => Level2ChoiceScreen(
          machineId: state.pathParameters['machineId']!,
          weightKg: _weightParam(state),
          reps: _repsParam(state),
        ),
      ),
      GoRoute(
        path: '/validation/camera/:machineId',
        builder: (context, state) => CameraProofScreen(
          machineId: state.pathParameters['machineId']!,
          weightKg: _weightParam(state),
          reps: _repsParam(state),
        ),
      ),
      GoRoute(
        path: '/validation/friend-qr/:performanceId',
        builder: (context, state) => FriendQrValidationScreen(
          performanceId: state.pathParameters['performanceId']!,
        ),
      ),
      GoRoute(path: '/validation/scan-friend', builder: (context, state) => const FriendQrScanScreen()),
      GoRoute(
        path: '/validation/level3-submit/:machineId',
        builder: (context, state) => Level3SubmitScreen(
          machineId: state.pathParameters['machineId']!,
          weightKg: _weightParam(state),
          reps: _repsParam(state),
        ),
      ),
      GoRoute(path: '/validation/staff', builder: (context, state) => const StaffValidationScreen()),
      GoRoute(path: '/validation/jury', builder: (context, state) => const PeerJuryScreen()),
    ],
  );
});
