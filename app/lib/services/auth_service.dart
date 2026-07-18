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

  /// Se connecter avec le pseudo OU l'email — si ce n'est pas une adresse
  /// email, on retrouve l'email correspondant au pseudo avant de tenter la
  /// connexion (les pseudos sont uniques, voir migration 0001).
  Future<void> signInWithIdentifier({required String identifier, required String password}) async {
    final email = await _resolveEmail(identifier.trim());
    await signIn(email: email, password: password);
  }

  Future<String> _resolveEmail(String identifier) async {
    if (identifier.contains('@')) return identifier;
    final row = await _client.from('users').select('email').ilike('pseudo', identifier).maybeSingle();
    if (row == null) {
      throw const AuthException('Aucun compte avec ce pseudo.');
    }
    return row['email'] as String;
  }

  /// Envoie un email de réinitialisation de mot de passe. `redirectTo` doit
  /// pointer vers l'app déployée pour que le lien ramène bien ici.
  Future<void> sendPasswordResetEmail(String email, {required String redirectTo}) {
    return _client.auth.resetPasswordForEmail(email.trim(), redirectTo: redirectTo);
  }

  /// Définit un nouveau mot de passe — appelé après avoir cliqué le lien
  /// reçu par email (la session de récupération est déjà active à ce
  /// moment-là, détectée automatiquement par le SDK Supabase).
  Future<void> updatePassword(String newPassword) {
    return _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<UserModel> fetchProfile(String userId) async {
    final row = await _client.from('users').select().eq('id', userId).single();
    return UserModel.fromMap(row);
  }
}
