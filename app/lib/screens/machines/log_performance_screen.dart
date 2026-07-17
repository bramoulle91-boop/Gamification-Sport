import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/performance_model.dart';
import '../../services/providers.dart';

enum _SubmitLevel { routine, recordOrDuel, highStakes }

/// Formulaire de saisie d'une performance (poids/reps) puis routage vers le
/// bon parcours de validation selon l'enjeu déclaré par l'utilisateur.
class LogPerformanceScreen extends ConsumerStatefulWidget {
  const LogPerformanceScreen({required this.machineId, super.key});

  final String machineId;

  @override
  ConsumerState<LogPerformanceScreen> createState() => _LogPerformanceScreenState();
}

class _LogPerformanceScreenState extends ConsumerState<LogPerformanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  _SubmitLevel _level = _SubmitLevel.routine;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final weight = double.parse(_weightController.text.replaceAll(',', '.'));
    final reps = int.parse(_repsController.text);

    switch (_level) {
      case _SubmitLevel.routine:
        setState(() {
          _loading = true;
          _error = null;
        });
        try {
          final service = ref.read(performanceServiceProvider);
          // Capturé avant l'envoi : après, la nouvelle perf fausserait la comparaison.
          final previousBest = await service.fetchPersonalBest(widget.machineId);
          final performance = await service.logLevel1(
            machineId: widget.machineId,
            weightKg: weight,
            reps: reps,
          );
          if (mounted) {
            final isNewRecord = performance.validationStatus == ValidationStatus.validated &&
                (previousBest == null || weight > previousBest);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isNewRecord
                      ? '🎉 Nouveau record personnel sur cette machine !'
                      : 'Performance validée ✅',
                ),
                duration: isNewRecord ? const Duration(seconds: 4) : const Duration(seconds: 3),
              ),
            );
            context.go('/home');
          }
        } catch (e) {
          setState(() => _error = 'Validation impossible : $e');
        } finally {
          if (mounted) setState(() => _loading = false);
        }
        break;
      case _SubmitLevel.recordOrDuel:
        if (mounted) {
          context.push('/validation/level2-choice/${widget.machineId}?weight=$weight&reps=$reps');
        }
        break;
      case _SubmitLevel.highStakes:
        if (mounted) {
          context.push('/validation/level3-submit/${widget.machineId}?weight=$weight&reps=$reps');
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle performance')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Poids (kg)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (double.tryParse((v ?? '').replaceAll(',', '.')) == null) ? 'Poids invalide' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _repsController,
                decoration: const InputDecoration(labelText: 'Répétitions'),
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') == null) ? 'Nombre invalide' : null,
              ),
              const SizedBox(height: 24),
              Text("Quel est l'enjeu ?", style: Theme.of(context).textTheme.titleMedium),
              RadioListTile(
                value: _SubmitLevel.routine,
                groupValue: _level,
                onChanged: (v) => setState(() => _level = v!),
                title: const Text('🟢 Séance normale'),
                subtitle: const Text('Validation automatique (géoloc + cohérence temporelle).'),
              ),
              RadioListTile(
                value: _SubmitLevel.recordOrDuel,
                groupValue: _level,
                onChanged: (v) => setState(() => _level = v!),
                title: const Text('🟡 Record personnel ou duel'),
                subtitle: const Text('Photo de la goupille ou QR code d\'un ami.'),
              ),
              RadioListTile(
                value: _SubmitLevel.highStakes,
                groupValue: _level,
                onChanged: (v) => setState(() => _level = v!),
                title: const Text('🔴 Gros enjeu / cadeau physique'),
                subtitle: const Text('Validation par le staff ou vote de la communauté.'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Continuer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
