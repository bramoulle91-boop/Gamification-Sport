import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../models/performance_model.dart';
import '../../services/providers.dart';

/// "Tribunal des Pairs" : la communauté visionne une courte vidéo de
/// l'exécution et vote pour valider ou rejeter une performance niveau 3.
class PeerJuryScreen extends ConsumerStatefulWidget {
  const PeerJuryScreen({super.key});

  @override
  ConsumerState<PeerJuryScreen> createState() => _PeerJuryScreenState();
}

class _PeerJuryScreenState extends ConsumerState<PeerJuryScreen> {
  List<PerformanceModel> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final pending = await ref.read(performanceServiceProvider).fetchPendingLevel3ForJury();
    setState(() {
      _pending = pending;
      _loading = false;
    });
  }

  Future<void> _vote(PerformanceModel performance, bool approve) async {
    await ref.read(performanceServiceProvider).castPeerJuryVote(
          performanceId: performance.id,
          approve: approve,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vote enregistré 🗳️')));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tribunal des Pairs')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pending.isEmpty
              ? const Center(child: Text('Aucune vidéo à juger pour le moment 🎬'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _pending.length,
                    itemBuilder: (context, index) {
                      final performance = _pending[index];
                      return _JuryCard(performance: performance, onVote: _vote);
                    },
                  ),
                ),
    );
  }
}

class _JuryCard extends ConsumerStatefulWidget {
  const _JuryCard({required this.performance, required this.onVote});

  final PerformanceModel performance;
  final Future<void> Function(PerformanceModel performance, bool approve) onVote;

  @override
  ConsumerState<_JuryCard> createState() => _JuryCardState();
}

class _JuryCardState extends ConsumerState<_JuryCard> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _loadVideo();
  }

  Future<void> _loadVideo() async {
    final path = widget.performance.proofVideoPath;
    if (path == null) return;
    final performanceService = ref.read(performanceServiceProvider);
    try {
      final url = await performanceService.getSignedProofUrl(path);
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (mounted) setState(() => _controller = controller);
    } catch (_) {
      // Vidéo indisponible : l'aperçu reste vide, le vote texte suffit.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final performance = widget.performance;
    final controller = _controller;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (controller != null && controller.value.isInitialized)
            AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  IconButton(
                    icon: Icon(controller.value.isPlaying ? Icons.pause_circle : Icons.play_circle, size: 48),
                    onPressed: () => setState(() {
                      controller.value.isPlaying ? controller.pause() : controller.play();
                    }),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(24),
              child: Icon(Icons.videocam_off, size: 48),
            ),
          ListTile(
            title: Text('${performance.weightKg}kg × ${performance.reps} reps'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up, color: Colors.green),
                  onPressed: () => widget.onVote(performance, true),
                ),
                IconButton(
                  icon: const Icon(Icons.thumb_down, color: Colors.red),
                  onPressed: () => widget.onVote(performance, false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
