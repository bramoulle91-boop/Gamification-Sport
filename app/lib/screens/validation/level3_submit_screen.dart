import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/providers.dart';

/// Niveau 3 — deux parcours possibles : validation par le staff de la salle,
/// ou soumission d'une courte vidéo au "Tribunal des Pairs" (vote communautaire).
class Level3SubmitScreen extends ConsumerStatefulWidget {
  const Level3SubmitScreen({
    required this.machineId,
    required this.weightKg,
    required this.reps,
    super.key,
  });

  final String machineId;
  final double weightKg;
  final int reps;

  @override
  ConsumerState<Level3SubmitScreen> createState() => _Level3SubmitScreenState();
}

class _Level3SubmitScreenState extends ConsumerState<Level3SubmitScreen> {
  bool _loading = false;
  bool _recording = false;
  CameraController? _controller;
  String? _error;

  Future<void> _submitToStaff() async {
    setState(() => _loading = true);
    try {
      await ref.read(performanceServiceProvider).logLevel3(
            machineId: widget.machineId,
            weightKg: widget.weightKg,
            reps: widget.reps,
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Envoyé au staff pour validation ✅')));
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Envoi impossible : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _startJuryVideoFlow() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _error = 'Aucun appareil photo disponible.');
      return;
    }
    final controller = CameraController(cameras.first, ResolutionPreset.medium);
    await controller.initialize();
    setState(() => _controller = controller);
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null) return;
    if (!_recording) {
      await controller.startVideoRecording();
      setState(() => _recording = true);
      return;
    }
    setState(() => _loading = true);
    try {
      final file = await controller.stopVideoRecording();
      setState(() => _recording = false);
      await ref.read(performanceServiceProvider).logLevel3(
            machineId: widget.machineId,
            weightKg: widget.weightKg,
            reps: widget.reps,
            proofVideoFile: File(file.path),
          );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Soumis au Tribunal des Pairs ✅')));
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Envoi impossible : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Gros enjeu — validation')),
      body: controller != null && controller.value.isInitialized
          ? Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(controller),
                Positioned(
                  bottom: 32,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton.large(
                      backgroundColor: _recording ? Colors.red : null,
                      onPressed: _loading ? null : _toggleRecording,
                      child: Icon(_recording ? Icons.stop : Icons.videocam),
                    ),
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.verified_user),
                      title: const Text('Validation par le staff'),
                      subtitle: const Text('Le gérant ou coach de la salle valide manuellement.'),
                      onTap: _loading ? null : _submitToStaff,
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.groups),
                      title: const Text('Tribunal des Pairs'),
                      subtitle: const Text('Filme une courte vidéo, la communauté vote.'),
                      onTap: _loading ? null : _startJuryVideoFlow,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  if (_loading) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
    );
  }
}
