import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/exercise_catalog.dart';
import '../../services/program_service.dart';
import '../../services/providers.dart';

Uri _techniqueSearchUri(String exerciseName) => Uri.parse(
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$exerciseName technique musculation')}',
    );

Future<void> _openTechnique(BuildContext context, String exerciseName) async {
  final launched = await launchUrl(_techniqueSearchUri(exerciseName), mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Impossible d'ouvrir la vidéo.")),
    );
  }
}

/// Formulaire de création d'un programme sur-mesure : l'utilisateur nomme
/// son programme puis ajoute ses exercices, groupés par jour, en piochant
/// dans un catalogue par groupe musculaire (ou en tapant un nom libre —
/// le programme reste entièrement personnalisable), plutôt que de suivre
/// le Programme Découverte imposé.
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Programme créé 💪 — modifie ton calendrier depuis l\'accueil si besoin')),
        );
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
                                leading: Icon(iconForMuscleGroup(exercise.targetedMuscle)),
                                title: Text(exercise.exerciseName),
                                subtitle: Text(
                                  '${exercise.targetedMuscle ?? ''}${exercise.targetedMuscle != null ? ' · ' : ''}'
                                  '${exercise.targetSets} × ${exercise.targetReps}'
                                  '${(exercise.targetWeightKg ?? 0) > 0 ? ' × ${exercise.targetWeightKg!.toStringAsFixed(0)}kg' : ''}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.play_circle_outline),
                                      tooltip: 'Voir la technique',
                                      onPressed: () => _openTechnique(context, exercise.exerciseName),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => setState(() => _exercises.remove(exercise)),
                                    ),
                                  ],
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
  final _muscleController = TextEditingController();
  final _setsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _weightController = TextEditingController();
  TextEditingController? _nameFieldController;
  String _muscleFilter = 'Tous';
  String? _pickedName;

  void _applyCatalogEntry(ExerciseCatalogEntry entry) {
    setState(() {
      _pickedName = entry.name;
      _muscleController.text = entry.muscleGroup;
      _setsController.text = '${entry.defaultSets}';
      _repsController.text = '${entry.defaultReps}';
    });
    _nameFieldController?.text = entry.name;
  }

  void _submit() {
    final exerciseName = (_nameFieldController?.text ?? _pickedName ?? '').trim();
    if (!_formKey.currentState!.validate() || exerciseName.isEmpty) {
      if (exerciseName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choisis ou tape un exercice.')),
        );
      }
      return;
    }
    Navigator.of(context).pop(
      ProgramExerciseDraft(
        dayLabel: _dayController.text.trim(),
        exerciseName: exerciseName,
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
            const SizedBox(height: 12),
            const Text('Groupe musculaire', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['Tous', ...muscleGroups].map((g) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(g, style: const TextStyle(fontSize: 12)),
                      selected: _muscleFilter == g,
                      onSelected: (_) => setState(() => _muscleFilter = g),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            Autocomplete<ExerciseCatalogEntry>(
              displayStringForOption: (e) => e.name,
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.toLowerCase();
                return exerciseCatalog.where((e) {
                  final matchesGroup = _muscleFilter == 'Tous' || e.muscleGroup == _muscleFilter;
                  final matchesQuery = query.isEmpty || e.name.toLowerCase().contains(query);
                  return matchesGroup && matchesQuery;
                });
              },
              onSelected: _applyCatalogEntry,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                _nameFieldController = controller;
                return TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    labelText: 'Exercice (choisis dans la liste ou tape le tien)',
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final list = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width - 64,
                      height: list.length > 4 ? 220 : list.length * 56.0,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final entry = list[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(iconForMuscleGroup(entry.muscleGroup)),
                            title: Text(entry.name),
                            subtitle: Text(entry.muscleGroup, style: const TextStyle(fontSize: 11)),
                            trailing: IconButton(
                              icon: const Icon(Icons.play_circle_outline, size: 20),
                              tooltip: 'Voir la technique',
                              onPressed: () => _openTechnique(context, entry.name),
                            ),
                            onTap: () => onSelected(entry),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
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
