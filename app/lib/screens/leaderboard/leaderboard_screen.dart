import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_model.dart';
import '../../services/providers.dart';

final _topUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(leaderboardServiceProvider).fetchTopUsers();
});

const _medals = ['🥇', '🥈', '🥉'];

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
          child: users.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          "Personne au classement pour l'instant — sois le premier à valider une performance 🏆",
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isMe = user.id == myId;
                    final rank = index + 1;
                    final medal = rank <= 3 ? _medals[rank - 1] : null;
                    return ListTile(
                      tileColor: isMe ? Theme.of(context).colorScheme.primaryContainer : null,
                      leading: medal != null
                          ? Text(medal, style: const TextStyle(fontSize: 24))
                          : CircleAvatar(child: Text('$rank')),
                      title: Text(user.pseudo),
                      subtitle: Text('Ligue ${user.leagueLevel}'),
                      trailing: Text(
                        '${user.totalPoints} pts',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
