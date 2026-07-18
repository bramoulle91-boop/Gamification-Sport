import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/providers.dart';

/// Capture une photo via l'appareil photo intégré de l'app (pas d'import galerie)
/// pour servir de preuve niveau 2 : la goupille de poids sur la machine.
class CameraProofScreen extends ConsumerStatefulWidget {
  const CameraProofScreen({
    required this.machineId,
    required this.weightKg,
    required this.reps,
    super.key,
  });

  final String machineId;
  final double weightKg;
  final int reps;

  @override
  ConsumerState<CameraProofScreen> createState() => _CameraProofScreenState();
}

class _CameraProofScreenState extends ConsumerState<CameraProofScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      setState(() => _error = 'Aucun appareil photo disponible.');
      return;
    }
    final controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
    _controller = controller;
    _initFuture = controller.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _captureAndSubmit() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final xFile = await controller.takePicture();
      final performance = await ref.read(performanceServiceProvider).logLevel2WithPhoto(
            machineId: widget.machineId,
            weightKg: widget.weightKg,
            reps: widget.reps,
            photoFile: File(xFile.path),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Performance validée (${performance.validationStatus.name}) ✅')),
        );
        context.go('/home');
      }
    } catch (e) {
      setState(() => _error = 'Envoi impossible : $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Photo de preuve')),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
          : _initFuture == null
              ? const Center(child: CircularProgressIndicator())
              : FutureBuilder<void>(
                  future: _initFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(_controller!),
                        Positioned(
                          bottom: 32,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: FloatingActionButton.large(
                              onPressed: _submitting ? null : _captureAndSubmit,
                              child: _submitting
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.camera),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
