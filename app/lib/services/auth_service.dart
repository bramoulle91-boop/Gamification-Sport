import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signUp({
    required String email,
    required String password,
    required String pseudo,
  }) async {
    final response = await _client.auth.signUp(email: email, password: password);
    final userId = response.user?.id;
    if (userId == null) {
      throw const AuthException('Échec de la création du compte.');
    }
    await _client.from('users').insert({
      'id': userId,
      'pseudo': pseudo,
      'email': email,
    });
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<UserModel> fetchProfile(String userId) async {
    final row = await _client.from('users').select().eq('id', userId).single();
    return UserModel.fromMap(row);
  }
}
