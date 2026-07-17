import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/program_exercise_model.dart';
import '../models/program_model.dart';

/// Séance du jour du programme suivi par l'utilisateur : liste d'exercices
/// à cocher au fil de la séance, avec un raccourci vers le scan de machine
/// pour transformer chaque exercice en performance validée.
class ProgramCard extends StatelessWidget {
  const ProgramCard({
    required this.userProgram,
    required this.doneExerciseIds,
    required this.onToggle,
    required this.onNextDay,
    super.key,
  });

  final UserProgramModel userProgram;
  final Set<String> doneExerciseIds;
  final void Function(String exerciseId) onToggle;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    final exercises = userProgram.todaysExercises;
    final doneCount = exercises.where((e) => doneExerciseIds.contains(e.id)).length;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            color: scheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.fitness_center, color: scheme.onPrimaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userProgram.currentDayLabel,
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        userProgram.program.name,
                        style: TextStyle(color: scheme.onPrimaryContainer.withOpacity(0.85), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$doneCount/${exercises.length}',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ...exercises.map((exercise) {
            final done = doneExerciseIds.contains(exercise.id);
            return ListTile(
              leading: Checkbox(value: done, onChanged: (_) => onToggle(exercise.id)),
              title: Text(
                exercise.exerciseName,
                style: done ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
              ),
              subtitle: Text(_exerciseSubtitle(exercise)),
              trailing: IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Scanner la machine pour cet exercice',
                onPressed: () => context.push('/scan'),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: OutlinedButton.icon(
              onPressed: onNextDay,
              icon: const Icon(Icons.skip_next),
              label: const Text('Séance suivante'),
            ),
          ),
        ],
      ),
    );
  }

  String _exerciseSubtitle(ProgramExerciseModel exercise) {
    final weight = exercise.targetWeightKg;
    final weightText = (weight != null && weight > 0) ? ' × ${weight.toStringAsFixed(0)}kg' : '';
    return '${exercise.targetedMuscle ?? ''} · ${exercise.targetSets} × ${exercise.targetReps}$weightText'
        .replaceFirst(RegExp(r'^ · '), '');
  }
}

/// Carte proposée quand l'utilisateur ne suit encore aucun programme :
/// suivre le programme prédéfini, ou créer le sien sur-mesure.
class NoProgramCard extends StatelessWidget {
  const NoProgramCard({
    required this.onStartDiscovery,
    required this.onCreateOwn,
    this.loading = false,
    super.key,
  });

  final VoidCallback onStartDiscovery;
  final VoidCallback onCreateOwn;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome),
                const SizedBox(width: 8),
                Text('Aucun programme en cours', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Suis le Programme Découverte (full-body en 3 séances), ou crée ton propre programme avec tes exercices.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: loading ? null : onCreateOwn,
                    child: const Text('Créer le mien'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: loading ? null : onStartDiscovery,
                    child: loading
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Découverte'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
