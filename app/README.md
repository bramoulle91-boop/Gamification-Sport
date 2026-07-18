# GymQuest — application Flutter

Application mobile de GymQuest : validation gamifiée des performances en salle, ligues, amis, boutique de récompenses.

> Le document d'architecture d'origine envisageait FlutterFlow (no-code). Ce projet est écrit en Flutter/Dart "code-first" — même stack Supabase, mais entièrement versionnable et testable ici.

## Prérequis

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal stable, ≥ 3.24)
- Un projet [Supabase](https://supabase.com) sur lequel les migrations de [`../supabase/migrations`](../supabase/migrations) ont été appliquées

## Configuration

```bash
cp .env.example .env
# renseigner SUPABASE_URL et SUPABASE_ANON_KEY dans .env
```

## Lancer le projet

```bash
flutter create . --platforms=android,ios   # génère les dossiers natifs (non versionnés)
flutter pub get
flutter run
```

## Structure

```
lib/
  config/       # lecture des variables d'environnement (.env)
  models/       # modèles de données (User, Gym, Machine, Performance, ...)
  services/     # accès Supabase : auth, performances/validation, amis, classement, récompenses
  router/       # navigation (go_router)
  screens/      # écrans, organisés par domaine (auth, home, machines, validation, ...)
  widgets/      # composants réutilisables
```

## Parcours de validation implémentés

- **Niveau 1 (routine)** : `PerformanceService.logLevel1` appelle la RPC Supabase `log_performance_level1`, qui vérifie géofencing + cohérence temporelle côté serveur.
- **Niveau 2 (records & duels)** : photo prise via l'appareil photo intégré (`CameraProofScreen`) ou QR code temporaire scanné par un ami (`FriendQrValidationScreen` / `FriendQrScanScreen`).
- **Niveau 3 (gros enjeux)** : validation par le staff de la salle (`StaffValidationScreen`, réservé aux comptes liés à `gym_staff`) ou vote de la communauté sur vidéo (`PeerJuryScreen`, "Tribunal des Pairs").

## Vérifié

`flutter analyze` passe sans erreur (2 lints d'info mineurs). L'app n'a pas été buildée sur device/émulateur dans cet environnement (pas de SDK Android/iOS ni d'accès à un projet Supabase réel) — à tester contre un vrai backend avant mise en production.
