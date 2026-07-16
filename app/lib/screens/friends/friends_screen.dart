import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/friendship_model.dart';
import '../../services/providers.dart';
import '../../widgets/demo_mode_banner.dart';

final _friendshipsProvider = FutureProvider<List<FriendshipModel>>((ref) {
  return ref.watch(friendshipServiceProvider).fetchMyFriendships();
});

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
                        final friendId =
                            friendship.userId1 == myId ? friendship.userId2 : friendship.userId1;
                        final pending = friendship.status == FriendshipStatus.pending;
                        return ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.person)),
                          title: Text(friendId),
                          subtitle: Text(pending ? 'En attente' : 'Connecté'),
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
