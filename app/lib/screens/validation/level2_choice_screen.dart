import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/providers.dart';

/// Niveau 2 — choix du mode de preuve : photo sécurisée ou QR code d'un ami.
class Level2ChoiceScreen extends ConsumerStatefulWidget {
  const Level2ChoiceScreen({
    required this.machineId,
    required this.weightKg,
    required this.reps,
    super.key,
  });

  final String machineId;
  final double weightKg;
  final int reps;

  @override
  ConsumerState<Level2ChoiceScreen> createState() => _Level2ChoiceScreenState();
}

class _Level2ChoiceScreenState extends ConsumerState<Level2ChoiceScreen> {
  bool _loading = false;

  Future<void> _startFriendFlow() async {
    setState(() => _loading = true);
    try {
      final performance = await ref.read(performanceServiceProvider).createPendingLevel2(
            machineId: widget.machineId,
            weightKg: widget.weightKg,
            reps: widget.reps,
          );
      if (mounted) context.push('/validation/friend-qr/${performance.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preuve niveau 2')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Photo de la goupille de poids'),
                subtitle: const Text("Appareil photo sécurisé de l'application uniquement."),
                onTap: _loading
                    ? null
                    : () => context.push(
                          '/validation/camera/${widget.machineId}?weight=${widget.weightKg}&reps=${widget.reps}',
                        ),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.qr_code),
                title: const Text('QR code d\'un ami'),
                subtitle: const Text('Un ami géolocalisé à côté de toi scanne ton QR temporaire.'),
                onTap: _loading ? null : _startFriendFlow,
                trailing: _loading
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
