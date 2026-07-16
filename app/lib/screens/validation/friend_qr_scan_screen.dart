import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/providers.dart';

/// Un ami scanne ici le QR temporaire affiché sur le téléphone de son pote
/// pour valider sa performance (niveau 2).
class FriendQrScanScreen extends ConsumerStatefulWidget {
  const FriendQrScanScreen({super.key});

  @override
  ConsumerState<FriendQrScanScreen> createState() => _FriendQrScanScreenState();
}

class _FriendQrScanScreenState extends ConsumerState<FriendQrScanScreen> {
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (code == null) return;
    _handled = true;

    try {
      final performance = await ref.read(performanceServiceProvider).redeemFriendValidationToken(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Performance de ton ami validée (${performance.weightKg}kg) ✅')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      setState(() => _handled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scanner le QR d'un ami")),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
