import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bandeau affiché quand personne n'est connecté : les données visibles
/// sont un aperçu de démonstration, pas un vrai compte.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Aperçu — données de démonstration',
              style: TextStyle(color: scheme.onPrimaryContainer, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/login'),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }
}
