import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/providers.dart';
import '../../widgets/league_badge.dart';
import '../../widgets/stat_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('GymQuest')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (profile) {
          if (profile == null) return const SizedBox.shrink();
          final streakCount = profile.streakHistory.length;
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(currentProfileProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Salut ${profile.pseudo} 👋', style: Theme.of(context).textTheme.titleLarge),
                    LeagueBadge(leagueLevel: profile.leagueLevel),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Points cumulés',
                        value: '${profile.totalPoints}',
                        icon: Icons.star,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Streak',
                        value: '$streakCount jours',
                        icon: Icons.local_fire_department,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Comment valider une perf ?', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const _ValidationLevelTile(
                  emoji: '🟢',
                  title: 'Niveau 1 — Routine',
                  subtitle: 'Automatique : géolocalisation + cohérence temporelle.',
                ),
                const _ValidationLevelTile(
                  emoji: '🟡',
                  title: 'Niveau 2 — Records & Duels',
                  subtitle: 'Photo de la goupille via l\'appareil sécurisé, ou QR code d\'un ami à côté de toi.',
                ),
                const _ValidationLevelTile(
                  emoji: '🔴',
                  title: 'Niveau 3 — Gros enjeux',
                  subtitle: 'Validation par le staff de la salle ou vote de la communauté sur vidéo.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ValidationLevelTile extends StatelessWidget {
  const _ValidationLevelTile({required this.emoji, required this.title, required this.subtitle});

  final String emoji;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Text(emoji, style: const TextStyle(fontSize: 24)),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
