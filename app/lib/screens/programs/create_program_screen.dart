import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/program_service.dart';
import '../../services/providers.dart';

/// Formulaire de création d'un programme sur-mesure : l'utilisateur nomme
/// son programme puis ajoute ses propres exercices, groupés par jour, plutôt
/// que de suivre le Programme Découverte imposé.
class CreateProgramScreen extends ConsumerStatefulWidget {
  const CreateProgramScreen({super.key});

  @override
  ConsumerState<CreateProgramScreen> createState() => _CreateProgramScreenState();
}

class _CreateProgramScreenState extends ConsumerState<CreateProgramScreen> {
  final _nameController = TextEditingController(text: 'Mon programme');
  final List<ProgramExerciseDraft> _exercises = [];
  bool _saving = false;

  Future<void> _openAddExerciseSheet() async {
    final lastDayLabel = _exercises.isNotEmpty ? _exercises.last.dayLabel : 'Jour 1';
    final draft = await showModalBottomSheet<ProgramExerciseDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AddExerciseSheet(defaultDayLabel: lastDayLabel),
    );
    if (draft != null) {
      setState(() => _exercises.add(draft));
    }
  }

  Future<void> _save() async {
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour créer un programme.')),
      );
      context.push('/login');
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoute au moins un exercice avant de créer ton programme.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final programService = ref.read(programServiceProvider);
      final program = await programService.createCustomProgram(
        name: _nameController.text.trim().isEmpty ? 'Mon programme' : _nameController.text.trim(),
        exercises: _exercises,
      );
      await programService.enroll(program);
      ref.invalidate(myProgramProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Programme créé 💪')));
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, List<ProgramExerciseDraft>> get _byDay {
    final map = <String, List<ProgramExerciseDraft>>{};
    for (final exercise in _exercises) {
      map.putIfAbsent(exercise.dayLabel, () => []).add(exercise);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _byDay;
    return Scaffold(
      appBar: AppBar(title: const Text('Créer mon programme')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom du programme',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _exercises.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        "Aucun exercice pour l'instant — ajoute ta première séance ci-dessous.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView(
                    children: grouped.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                            child: Text(entry.key, style: Theme.of(context).textTheme.titleMedium),
                          ),
                          ...entry.value.map((exercise) => ListTile(
                                title: Text(exercise.exerciseName),
                                subtitle: Text(
                                  '${exercise.targetedMuscle ?? ''}${exercise.targetedMuscle != null ? ' · ' : ''}'
                                  '${exercise.targetSets} × ${exercise.targetReps}'
                                  '${(exercise.targetWeightKg ?? 0) > 0 ? ' × ${exercise.targetWeightKg!.toStringAsFixed(0)}kg' : ''}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => setState(() => _exercises.remove(exercise)),
                                ),
                              )),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                OutlinedButton.icon(
                  onPressed: _openAddExerciseSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter un exercice'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Créer et commencer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddExerciseSheet extends StatefulWidget {
  const _AddExerciseSheet({required this.defaultDayLabel});

  final String defaultDayLabel;

  @override
  State<_AddExerciseSheet> createState() => _AddExerciseSheetState();
}

class _AddExerciseSheetState extends State<_AddExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _dayController = TextEditingController(text: widget.defaultDayLabel);
  final _nameController = TextEditingController();
  final _muscleController = TextEditingController();
  final _setsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _weightController = TextEditingController();

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ProgramExerciseDraft(
        dayLabel: _dayController.text.trim(),
        exerciseName: _nameController.text.trim(),
        targetedMuscle: _muscleController.text.trim().isEmpty ? null : _muscleController.text.trim(),
        targetSets: int.parse(_setsController.text),
        targetReps: int.parse(_repsController.text),
        targetWeightKg: double.tryParse(_weightController.text.replaceAll(',', '.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Nouvel exercice', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dayController,
              decoration: const InputDecoration(labelText: 'Jour (ex: Jour 1 — Push)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Exercice (ex: Développé couché)'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requis' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _muscleController,
              decoration: const InputDecoration(labelText: 'Muscle ciblé (optionnel)'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _setsController,
                    decoration: const InputDecoration(labelText: 'Séries'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Nombre' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _repsController,
                    decoration: const InputDecoration(labelText: 'Répétitions'),
                    keyboardType: TextInputType.number,
                    validator: (v) => (int.tryParse(v ?? '') == null) ? 'Nombre' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    decoration: const InputDecoration(labelText: 'Poids kg (optionnel)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _submit, child: const Text('Ajouter')),
          ],
        ),
      ),
    );
  }
}
