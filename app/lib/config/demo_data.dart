import '../models/user_model.dart';

/// Profil affiché quand personne n'est connecté, pour permettre de visiter
/// l'intégralité de l'app (design, écrans) sans compte ni backend configuré.
final demoProfile = UserModel(
  id: 'demo-user',
  pseudo: 'Toi (aperçu)',
  email: 'demo@gymquest.app',
  leagueLevel: 3,
  totalPoints: 1240,
  streakHistory: List.generate(12, (_) => const <String, dynamic>{}),
);
