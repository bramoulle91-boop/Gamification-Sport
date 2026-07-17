import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/demo_data.dart';
import '../models/program_model.dart';
import '../models/user_model.dart';
import 'auth_service.dart';
import 'friendship_service.dart';
import 'leaderboard_service.dart';
import 'performance_service.dart';
import 'program_service.dart';
import 'rewards_service.dart';
import 'staff_service.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final performanceServiceProvider = Provider((ref) => PerformanceService());
final friendshipServiceProvider = Provider((ref) => FriendshipService());
final leaderboardServiceProvider = Provider((ref) => LeaderboardService());
final rewardsServiceProvider = Provider((ref) => RewardsService());
final staffServiceProvider = Provider((ref) => StaffService());
final programServiceProvider = Provider((ref) => ProgramService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return SupabaseService.client.auth.currentUser?.id;
});

/// Profil de l'utilisateur connecté. Retombe sur un profil de démonstration
/// quand personne n'est connecté, pour que l'app reste visitable sans compte.
final currentProfileProvider = FutureProvider<UserModel>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return demoProfile;
  return ref.watch(authServiceProvider).fetchProfile(userId);
});

/// Programme d'entraînement suivi par l'utilisateur, avec repli sur un
/// programme de démonstration hors connexion.
final myProgramProvider = FutureProvider<UserProgramModel?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return demoUserProgram;
  return ref.watch(programServiceProvider).fetchMyProgram();
});
