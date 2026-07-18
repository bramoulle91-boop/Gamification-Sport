import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/friend_activity_model.dart';
import '../../models/friendship_model.dart';
import '../../services/providers.dart';
import '../../widgets/demo_mode_banner.dart';

final _friendshipsProvider = FutureProvider<List<FriendshipModel>>((ref) {
  return ref.watch(friendshipServiceProvider).fetchMyFriendships();
});

/// Fil d'activité léger, en attendant les vraies notifications push :
/// arrivée en salle ou exercice coché par un ami, déduit de ses check-ins
/// et exercices validés récemment.
final _friendsActivityProvider = FutureProvider<List<FriendActivityModel>>((ref) async {
  final myId = ref.watch(currentUserIdProvider);
  if (myId == null) return [];
  final friendships = await ref.watch(_friendshipsProvider.future);
  final friendIds = friendships
      .where((f) => f.status == FriendshipStatus.unlocked)
      .map((f) => f.userId1 == myId ? f.userId2 : f.userId1)
      .toList();
  return ref.watch(activityServiceProvider).fetchFriendsActivity(friendIds: friendIds);
});

String _timeAgo(DateTime at) {
  final diff = DateTime.now().toUtc().difference(at.toUtc());
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  return 'il y a ${diff.inHours} h';
}

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    final results = await ref.read(friendshipServiceProvider).searchUsersByPseudo(query);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => ListView(
        children: results
            .map((user) => ListTile(
                  title: Text(user.pseudo),
                  trailing: FilledButton(
                    onPressed: () async {
                      if (ref.read(currentUserIdProvider) == null) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Connecte-toi pour ajouter des amis.')),
                        );
                        return;
                      }
                      try {
                        await ref.read(friendshipServiceProvider).sendRequest(user.id);
                        if (context.mounted) Navigator.of(context).pop();
                        ref.invalidate(_friendshipsProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('Erreur : $e')));
                        }
                      }
                    },
                    child: const Text('Ajouter'),
                  ),
                ))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendshipsAsync = ref.watch(_friendshipsProvider);
    final activityAsync = ref.watch(_friendsActivityProvider);
    final myId = ref.watch(currentUserIdProvider);
    final isLoggedIn = myId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Amis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: "Scanner le QR d'un ami",
            onPressed: () => context.push('/validation/scan-friend'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isLoggedIn)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: DemoModeBanner(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Chercher un pseudo',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ],
            ),
          ),
          if (isLoggedIn)
            activityAsync.maybeWhen(
              data: (activities) => activities.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Activité récente', style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 6),
                          ...activities.map(
                            (activity) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Icon(
                                    activity.isRecord
                                        ? Icons.emoji_events
                                        : activity.type == FriendActivityType.checkin
                                            ? Icons.location_on
                                            : Icons.check_circle,
                                    size: 16,
                                    color: activity.isRecord ? Colors.amber.shade700 : Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      activity.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: activity.isRecord ? FontWeight.w700 : null,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(activity.at),
                                    style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
          Expanded(
            child: friendshipsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Erreur : $err')),
              data: (friendships) => friendships.isEmpty
                  ? const Center(child: Text('Aucun ami pour le moment.'))
                  : ListView.builder(
                      itemCount: friendships.length,
                      itemBuilder: (context, index) {
                        final friendship = friendships[index];
                        final pending = friendship.status == FriendshipStatus.pending;
                        final pseudo = friendship.pseudoForOther(myId ?? '');
                        final points = friendship.pointsForOther(myId ?? '');
                        final streak = friendship.streakForOther(myId ?? '');
                        return ListTile(
                          leading: CircleAvatar(child: Text(pseudo.isNotEmpty ? pseudo[0].toUpperCase() : '?')),
                          title: Text(pseudo),
                          subtitle: Text(
                            pending
                                ? 'En attente'
                                : '🔥 $streak jours · $points pts',
                          ),
                          trailing: pending && friendship.userId2 == myId
                              ? TextButton(
                                  onPressed: () async {
                                    await ref.read(friendshipServiceProvider).acceptRequest(
                                          userId1: friendship.userId1,
                                          userId2: friendship.userId2,
                                        );
                                    ref.invalidate(_friendshipsProvider);
                                  },
                                  child: const Text('Accepter'),
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
