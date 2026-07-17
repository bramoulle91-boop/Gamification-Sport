import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import 'supabase_service.dart';

class AuthService {
  final SupabaseClient _client = SupabaseService.client;

  User? get currentAuthUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Le profil `public.users` correspondant est créé côté serveur par un
  /// trigger sur `auth.users` (voir migration 0006) dès que le compte existe,
  /// indépendamment de l'état de la session client — donc y compris avant
  /// confirmation de l'email. Le pseudo choisi ici lui est transmis via les
  /// métadonnées du compte.
  Future<void> signUp({
    required String email,
    required String password,
    required String pseudo,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'pseudo': pseudo},
    );
    if (response.user == null) {
      throw const AuthException('Échec de la création du compte.');
    }
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
