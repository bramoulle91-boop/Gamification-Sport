import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/reward_model.dart';
import '../../services/providers.dart';
import '../../widgets/demo_mode_banner.dart';

final _rewardsProvider = FutureProvider<List<RewardModel>>((ref) {
  return ref.watch(rewardsServiceProvider).fetchRewards();
});

class RewardsShopScreen extends ConsumerWidget {
  const RewardsShopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(_rewardsProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isLoggedIn = ref.watch(currentUserIdProvider) != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Boutique de récompenses')),
      body: rewardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (rewards) {
          final myPoints = profileAsync.valueOrNull?.totalPoints ?? 0;
          return ListView(
            children: [
              if (!isLoggedIn)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: DemoModeBanner(),
                ),
              ...rewards.map((reward) {
                final affordable = myPoints >= reward.pointsCost;
                return ListTile(
                  leading: const Icon(Icons.card_giftcard),
                  title: Text(reward.name),
                  subtitle: Text(reward.partnerName ?? 'GymQuest'),
                  trailing: FilledButton(
                    onPressed: affordable
                        ? () async {
                            if (!isLoggedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Connecte-toi pour échanger des points.')),
                              );
                              return;
                            }
                            try {
                              await ref.read(rewardsServiceProvider).redeem(reward);
                              ref.invalidate(currentProfileProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(content: Text('Échangé 🎁')));
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(SnackBar(content: Text('Erreur : $e')));
                              }
                            }
                          }
                        : null,
                    child: Text('${reward.pointsCost} pts'),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
