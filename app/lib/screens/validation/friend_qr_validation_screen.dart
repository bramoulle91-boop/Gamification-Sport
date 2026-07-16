import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/providers.dart';

/// Affiche le QR temporaire (2 min) que l'ami doit scanner pour valider
/// la performance en cours (niveau 2, variante "duel entre amis").
class FriendQrValidationScreen extends ConsumerStatefulWidget {
  const FriendQrValidationScreen({required this.performanceId, super.key});

  final String performanceId;

  @override
  ConsumerState<FriendQrValidationScreen> createState() => _FriendQrValidationScreenState();
}

class _FriendQrValidationScreenState extends ConsumerState<FriendQrValidationScreen> {
  String? _token;
  DateTime? _expiresAt;
  Timer? _timer;
  Duration _remaining = Duration.zero;
  String? _error;

  @override
  void initState() {
    super.initState();
    _requestToken();
  }

  Future<void> _requestToken() async {
    try {
      final tokenRow = await ref
          .read(performanceServiceProvider)
          .requestFriendValidationToken(widget.performanceId);
      setState(() {
        _token = tokenRow['token'] as String;
        _expiresAt = DateTime.parse(tokenRow['expires_at'] as String);
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      _tick();
    } catch (e) {
      setState(() => _error = 'Impossible de générer le QR : $e');
    }
  }

  void _tick() {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return;
    final remaining = expiresAt.difference(DateTime.now());
    setState(() => _remaining = remaining.isNegative ? Duration.zero : remaining);
    if (remaining.isNegative) _timer?.cancel();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR à faire scanner')),
      body: Center(
        child: _error != null
            ? Padding(padding: const EdgeInsets.all(24), child: Text(_error!))
            : _token == null
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: QrImageView(data: _token!, size: 240),
                      ),
                      Text(
                        _remaining > Duration.zero
                            ? 'Expire dans ${_remaining.inSeconds}s'
                            : 'QR expiré, reviens en arrière pour en générer un nouveau',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          "Demande à ton ami d'ouvrir GymQuest et de scanner ce QR "
                          "depuis son propre téléphone, à côté de toi.",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
