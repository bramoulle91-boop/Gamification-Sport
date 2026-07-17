import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/geolocation_service.dart';
import '../../services/providers.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/league_badge.dart';
import '../../widgets/program_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/streak_row.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _enrolling = false;
  String? _togglingExerciseId;

  /// Coche ou décoche un exercice de la séance du jour. Cocher valide la
  /// géolocalisation côté serveur contre la salle habituelle (en attendant
  /// que toutes les machines aient un QR code) et déclenche un check-in
  /// visible par les amis ; décocher est libre.
  Future<void> _toggleExercise(String exerciseId, bool currentlyDone) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(currentUserIdProvider) == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour suivre ta séance.')),
      );
      return;
    }
    setState(() => _togglingExerciseId = exerciseId);
    try {
      if (currentlyDone) {
        await ref.read(programServiceProvider).uncompleteExercise(exerciseId);
      } else {
        final gym = ref.read(myGymProvider).valueOrNull;
        if (gym == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Choisis d\'abord ta salle habituelle sur la carte.')),
          );
          return;
        }
        final position = await GeolocationService().getCurrentPosition();
        await ref.read(programServiceProvider).completeExercise(
              programExerciseId: exerciseId,
              gymId: gym.id,
              lat: position.latitude,
              lon: position.longitude,
            );
      }
      ref.invalidate(myTodaysCompletionsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _togglingExerciseId = null);
    }
  }

  Future<void> _startDiscoveryProgram() async {
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour démarrer un programme.')),
      );
      return;
    }
    setState(() => _enrolling = true);
    try {
      final program = await ref.read(programServiceProvider).fetchDiscoveryProgram();
      await ref.read(programServiceProvider).enroll(program);
      ref.invalidate(myProgramProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _enrolling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final programAsync = ref.watch(myProgramProvider);
    final isLoggedIn = ref.watch(currentUserIdProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GymQuest'),
        actions: [
          IconButton(
            icon: const Text('🗺️', style: TextStyle(fontSize: 20)),
            tooltip: 'Carte des salles',
            onPressed: () => context.push('/gyms/map'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (profile) {
          final streakCount = profile.streakHistory.length;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentProfileProvider);
              ref.invalidate(myProgramProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isLoggedIn) ...[
                  const DemoModeBanner(),
                  const SizedBox(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Salut ${profile.pseudo} 👋', style: Theme.of(context).textTheme.titleLarge),
                    LeagueBadge(leagueLevel: profile.leagueLevel),
                  ],
                ),
                const SizedBox(height: 8),
                Consumer(
                  builder: (context, ref, _) {
                    final gymAsync = ref.watch(myGymProvider);
                    return gymAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (gym) => ActionChip(
                        avatar: const Text('📍'),
                        label: Text(gym != null ? gym.name : 'Choisir ta salle'),
                        onPressed: () => context.push('/gyms/map'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Points cumulés',
                        value: '${profile.totalPoints}',
                        icon: Icons.star,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Streak',
                        value: '$streakCount jours',
                        icon: Icons.local_fire_department,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                StreakRow(activeDays: streakCount.clamp(0, 7)),
                const SizedBox(height: 24),
                Text('Ta séance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                programAsync.when(
                  loading: () => const Center(child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  )),
                  error: (err, _) => Text('Erreur : $err'),
                  data: (userProgram) {
                    if (userProgram == null) {
                      return NoProgramCard(
                        onStartDiscovery: _startDiscoveryProgram,
                        onCreateOwn: () => context.push('/programs/create'),
                        loading: _enrolling,
                      );
                    }
                    final completionsAsync = ref.watch(myTodaysCompletionsProvider);
                    final doneExerciseIds = completionsAsync.valueOrNull ?? <String>{};
                    return ProgramCard(
                      userProgram: userProgram,
                      doneExerciseIds: doneExerciseIds,
                      togglingExerciseId: _togglingExerciseId,
                      onToggle: (id) => _toggleExercise(id, doneExerciseIds.contains(id)),
                      onNextDay: () async {
                        if (!isLoggedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Connecte-toi pour suivre ta progression.')),
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(programServiceProvider).advanceToNextDay(userProgram.program);
                          ref.invalidate(myProgramProvider);
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
                          }
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                Text('Comment valider une perf ?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const _ValidationLevelTile(
                  emoji: '🟢',
                  title: 'Niveau 1 — Routine',
                  subtitle: 'Automatique : géolocalisation + cohérence temporelle.',
                ),
                const _ValidationLevelTile(
                  emoji: '🟡',
                  title: 'Niveau 2 — Records & Duels',
                  subtitle: 'Photo de la goupille via l\'appareil sécurisé, ou QR code d\'un ami à côté de toi.',
                ),
                const _ValidationLevelTile(
                  emoji: '🔴',
                  title: 'Niveau 3 — Gros enjeux',
                  subtitle: 'Validation par le staff de la salle ou vote de la communauté sur vidéo.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ValidationLevelTile extends StatelessWidget {
  const _ValidationLevelTile({required this.emoji, required this.title, required this.subtitle});

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
