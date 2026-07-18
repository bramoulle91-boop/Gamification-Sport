import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Scanne le QR code collé sur une machine pour l'identifier (QR_Code_Hash).
class MachineScanScreen extends StatefulWidget {
  const MachineScanScreen({super.key});

  @override
  State<MachineScanScreen> createState() => _MachineScanScreenState();
}

class _MachineScanScreenState extends State<MachineScanScreen> {
  bool _handled = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;
    _handled = true;

    try {
      final machine = await Supabase.instance.client
          .from('machines')
          .select('id')
          .eq('qr_code_hash', code)
          .maybeSingle();

      if (!mounted) return;
      if (machine == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Machine inconnue, réessaie.')),
        );
        setState(() => _handled = false);
        return;
      }
      context.replace('/log-performance/${machine['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      setState(() => _handled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner une machine')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
