import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/gym_model.dart';
import '../../models/machine_model.dart';
import '../../services/providers.dart';

final _gymProvider = FutureProvider.family<GymModel?, String>((ref, gymId) {
  return ref.watch(gymServiceProvider).fetchGymById(gymId);
});

final _gymMachinesProvider = FutureProvider.family<List<MachineModel>, String>((ref, gymId) {
  return ref.watch(gymServiceProvider).fetchMachinesForGym(gymId);
});

/// Fiche d'une salle : ses machines, accessibles directement (sans passer
/// par le scan QR), et le choix de cette salle comme salle habituelle.
class GymDetailScreen extends ConsumerWidget {
  const GymDetailScreen({required this.gymId, super.key});

  final String gymId;

  Future<void> _chooseGym(BuildContext context, WidgetRef ref, GymModel gym) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(currentUserIdProvider) == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Connecte-toi pour choisir ta salle.')));
      return;
    }
    try {
      await ref.read(gymServiceProvider).setHomeGym(gym.id);
      ref.invalidate(currentProfileProvider);
      messenger.showSnackBar(SnackBar(content: Text('${gym.name} est maintenant ta salle 🏋️')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gymAsync = ref.watch(_gymProvider(gymId));
    final machinesAsync = ref.watch(_gymMachinesProvider(gymId));
    final myGymAsync = ref.watch(myGymProvider);

    return Scaffold(
      appBar: AppBar(
        title: gymAsync.when(
          data: (gym) => Text(gym?.name ?? 'Salle'),
          loading: () => const Text('Salle'),
          error: (_, __) => const Text('Salle'),
        ),
      ),
      body: gymAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (gym) {
          if (gym == null) return const Center(child: Text('Salle introuvable.'));
          final isMyGym = myGymAsync.valueOrNull?.id == gym.id;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Icon(Icons.people_outline, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    gym.liveAttendanceRate != null
                        ? 'Affluence : ${(gym.liveAttendanceRate! * 100).toStringAsFixed(0)}%'
                        : 'Affluence inconnue pour le moment',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: isMyGym ? null : () => _chooseGym(context, ref, gym),
                icon: Icon(isMyGym ? Icons.check_circle : Icons.flag_outlined),
                label: Text(isMyGym ? "C'est déjà ta salle" : 'Choisir cette salle'),
              ),
              const SizedBox(height: 24),
              Text('Machines', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              machinesAsync.when(
                loading: () => const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                )),
                error: (err, _) => Text('Erreur : $err'),
                data: (machines) => machines.isEmpty
                    ? const Text('Aucune machine enregistrée pour cette salle pour le moment.')
                    : Column(
                        children: machines
                            .map((machine) => Card(
                                  child: ListTile(
                                    leading: const Icon(Icons.fitness_center),
                                    title: Text(machine.name),
                                    subtitle: Text(machine.targetedMuscle ?? ''),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => context.push('/log-performance/${machine.id}'),
                                  ),
                                ))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
