import 'package:flutter/material.dart';

class LeagueBadge extends StatelessWidget {
  const LeagueBadge({required this.leagueLevel, super.key});

  final int leagueLevel;

  static const _leagueNames = ['Bronze', 'Argent', 'Or', 'Platine', 'Diamant', 'Légende'];

  String get _name => _leagueNames[(leagueLevel - 1).clamp(0, _leagueNames.length - 1)];

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.emoji_events, size: 18),
      label: Text('Ligue $_name'),
    );
  }
}
