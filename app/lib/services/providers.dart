import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'auth_service.dart';
import 'friendship_service.dart';
import 'leaderboard_service.dart';
import 'performance_service.dart';
import 'rewards_service.dart';
import 'staff_service.dart';
import 'supabase_service.dart';

final authServiceProvider = Provider((ref) => AuthService());
final performanceServiceProvider = Provider((ref) => PerformanceService());
final friendshipServiceProvider = Provider((ref) => FriendshipService());
final leaderboardServiceProvider = Provider((ref) => LeaderboardService());
final rewardsServiceProvider = Provider((ref) => RewardsService());
final staffServiceProvider = Provider((ref) => StaffService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return SupabaseService.client.auth.currentUser?.id;
});

final currentProfileProvider = FutureProvider<UserModel?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(authServiceProvider).fetchProfile(userId);
});
