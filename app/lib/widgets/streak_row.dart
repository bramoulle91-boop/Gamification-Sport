import 'package:flutter/material.dart';

/// Sept pastilles représentant les 7 derniers jours, allumées selon la
/// longueur du streak courant — une vision plus visuelle que le seul chiffre.
class StreakRow extends StatelessWidget {
  const StreakRow({required this.activeDays, super.key});

  final int activeDays;

  static const _labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(7, (i) {
        final active = i < activeDays;
        return Expanded(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 8,
                decoration: BoxDecoration(
                  color: active ? scheme.primary : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(_labels[i], style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
        );
      }),
    );
  }
}
