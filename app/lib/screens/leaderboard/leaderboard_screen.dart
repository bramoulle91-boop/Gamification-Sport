import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/machine_king_model.dart';
import '../../models/user_model.dart';
import '../../services/providers.dart';

final _topUsersProvider = FutureProvider<List<UserModel>>((ref) {
  return ref.watch(leaderboardServiceProvider).fetchTopUsers();
});

final _machineKingsProvider = FutureProvider<List<MachineKingModel>>((ref) {
  return ref.watch(machineKingServiceProvider).fetchMachineKings();
});

const _medals = ['🥇', '🥈', '🥉'];

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classement')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Athlètes'), icon: Icon(Icons.emoji_events)),
                ButtonSegment(value: 1, label: Text('Machines'), icon: Icon(Icons.fitness_center)),
              ],
              selected: {_segment},
              onSelectionChanged: (s) => setState(() => _segment = s.first),
            ),
          ),
          Expanded(child: _segment == 0 ? const _AthletesTab() : const _MachinesTab()),
        ],
      ),
    );
  }
}

class _AthletesTab extends ConsumerWidget {
  const _AthletesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_topUsersProvider);
    final myId = ref.watch(currentUserIdProvider);

    return usersAsync.when(
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
    );
  }
}

class _MachinesTab extends ConsumerWidget {
  const _MachinesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kingsAsync = ref.watch(_machineKingsProvider);
    final isLoggedIn = ref.watch(currentUserIdProvider) != null;

    return kingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Erreur : $err')),
      data: (machines) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(_machineKingsProvider),
        child: machines.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        "Aucune machine enregistrée pour l'instant.",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: machines.length,
                itemBuilder: (context, index) => _MachineKingTile(machine: machines[index], isLoggedIn: isLoggedIn),
              ),
      ),
    );
  }
}

class _MachineKingTile extends StatelessWidget {
  const _MachineKingTile({required this.machine, required this.isLoggedIn});

  final MachineKingModel machine;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(machine.machineName, style: Theme.of(context).textTheme.titleMedium),
                      if (machine.targetedMuscle != null)
                        Text(machine.targetedMuscle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                if (machine.hasKing)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Text('👑', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 4),
                          Text(
                            machine.isMeTheKing ? 'Toi !' : machine.kingPseudo!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      Text('${machine.kingWeightKg!.toStringAsFixed(0)} kg'),
                    ],
                  )
                else
                  Text('Aucun King', style: TextStyle(color: scheme.outline)),
              ],
            ),
            if (isLoggedIn) ...[
              const Divider(height: 20),
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    machine.myBestWeightKg != null
                        ? 'Ton record : ${machine.myBestWeightKg!.toStringAsFixed(0)} kg'
                        : "Tu n'as pas encore essayé — lance-toi 💪",
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
