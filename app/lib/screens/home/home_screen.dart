import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/program_exercise_model.dart';
import '../../services/geolocation_service.dart';
import '../../services/providers.dart';
import '../../widgets/demo_mode_banner.dart';
import '../../widgets/league_badge.dart';
import '../../widgets/program_card.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/streak_row.dart';

/// Nombre de jours consécutifs (jusqu'à aujourd'hui ou hier) où l'utilisateur
/// a validé au moins un exercice — le streak n'est pas encore cassé tant
/// qu'il peut encore agir aujourd'hui.
int _currentStreak(Set<DateTime> completionDates) {
  final normalized = completionDates.map((d) => DateTime(d.year, d.month, d.day)).toSet();
  var cursor = DateTime.now();
  cursor = DateTime(cursor.year, cursor.month, cursor.day);
  if (!normalized.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (normalized.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _enrolling = false;
  String? _togglingExerciseId;

  /// Coche ou décoche un exercice de la séance du jour. Cocher demande le
  /// poids/les reps réellement faits, valide la géolocalisation côté
  /// serveur contre la salle habituelle (en attendant que toutes les
  /// machines aient un QR code), attribue des points, détecte un record
  /// personnel et déclenche un check-in — le tout visible par les amis.
  /// Décocher est libre.
  Future<void> _toggleExercise(ProgramExerciseModel exercise, bool currentlyDone) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(currentUserIdProvider) == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour suivre ta séance.')),
      );
      return;
    }
    if (currentlyDone) {
      setState(() => _togglingExerciseId = exercise.id);
      try {
        await ref.read(programServiceProvider).uncompleteExercise(exercise.id);
        ref.invalidate(myTodaysCompletionsProvider);
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('$e')));
      } finally {
        if (mounted) setState(() => _togglingExerciseId = null);
      }
      return;
    }

    final gym = ref.read(myGymProvider).valueOrNull;
    if (gym == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Choisis d\'abord ta salle habituelle sur la carte.')),
      );
      return;
    }

    final result = await showDialog<(double?, int?)>(
      context: context,
      builder: (context) => _WeightRepsDialog(exercise: exercise),
    );
    if (result == null) return;

    setState(() => _togglingExerciseId = exercise.id);
    try {
      final position = await GeolocationService().getCurrentPosition();
      final isRecord = await ref.read(programServiceProvider).completeExercise(
            programExerciseId: exercise.id,
            gymId: gym.id,
            lat: position.latitude,
            lon: position.longitude,
            weightKg: result.$1,
            reps: result.$2,
          );
      ref.invalidate(myTodaysCompletionsProvider);
      ref.invalidate(currentProfileProvider);
      if (isRecord && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('🏆 Nouveau record personnel sur cet exercice !')),
        );
      }
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
          final completionDates = ref.watch(myCompletionDatesProvider).valueOrNull;
          final streakCount = isLoggedIn
              ? (completionDates != null ? _currentStreak(completionDates) : 0)
              : profile.streakHistory.length;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentProfileProvider);
              ref.invalidate(myProgramProvider);
              ref.invalidate(myCompletionDatesProvider);
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
                      onToggle: (exercise) => _toggleExercise(exercise, doneExerciseIds.contains(exercise.id)),
                      onOpenCalendar: () => context.push('/programs/calendar'),
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

/// Demande le poids/les reps réellement faits avant de cocher un exercice,
/// pré-rempli avec l'objectif du programme mais modifiable — c'est cette
/// donnée qui permet de détecter un record et de le montrer aux amis.
class _WeightRepsDialog extends StatefulWidget {
  const _WeightRepsDialog({required this.exercise});

  final ProgramExerciseModel exercise;

  @override
  State<_WeightRepsDialog> createState() => _WeightRepsDialogState();
}

class _WeightRepsDialogState extends State<_WeightRepsDialog> {
  late final _weightController = TextEditingController(
    text: widget.exercise.targetWeightKg != null && widget.exercise.targetWeightKg! > 0
        ? widget.exercise.targetWeightKg!.toStringAsFixed(0)
        : '',
  );
  late final _repsController = TextEditingController(text: '${widget.exercise.targetReps}');

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.exerciseName),
      content: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Poids (kg)'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Répétitions'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
            final reps = int.tryParse(_repsController.text);
            Navigator.of(context).pop((weight, reps));
          },
          child: const Text('Valider'),
        ),
      ],
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
