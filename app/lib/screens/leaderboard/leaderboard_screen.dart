import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../services/providers.dart';

final _topUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(leaderboardServiceProvider).fetchTopUsers();
});

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_topUsersProvider);
    final myId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Classement')),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (users) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(_topUsersProvider),
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isMe = user.id == myId;
              return ListTile(
                tileColor: isMe ? Theme.of(context).colorScheme.primaryContainer : null,
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text(user.pseudo),
                trailing: Text('${user.totalPoints} pts'),
              );
            },
          ),
        ),
      ),
    );
  }
}
