import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../models/gym_model.dart';
import '../../services/providers.dart';

final _gymsProvider = FutureProvider<List<GymModel>>((ref) {
  return ref.watch(gymServiceProvider).fetchAllGyms();
});

/// Carte des salles partenaires : on choisit sa salle habituelle en tapant
/// sur un repère. Fond de carte OpenStreetMap (gratuit, pas de clé requise).
class GymMapScreen extends ConsumerStatefulWidget {
  const GymMapScreen({super.key});

  @override
  ConsumerState<GymMapScreen> createState() => _GymMapScreenState();
}

class _GymMapScreenState extends ConsumerState<GymMapScreen> {
  static const _parisCenter = LatLng(48.8566, 2.3522);

  Future<void> _chooseGym(GymModel gym) async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(currentUserIdProvider) == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Connecte-toi pour choisir ta salle.')));
      return;
    }
    try {
      await ref.read(gymServiceProvider).setHomeGym(gym.id);
      ref.invalidate(currentProfileProvider);
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('${gym.name} est maintenant ta salle 🏋️')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }

  void _showGymSheet(GymModel gym) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(gym.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
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
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _chooseGym(gym),
              child: const Text('Choisir cette salle'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gymsAsync = ref.watch(_gymsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Salles partenaires')),
      body: gymsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Erreur : $err')),
        data: (gyms) => FlutterMap(
          options: const MapOptions(initialCenter: _parisCenter, initialZoom: 12),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.gymquest',
            ),
            MarkerLayer(
              markers: gyms
                  .map(
                    (gym) => Marker(
                      point: LatLng(gym.latitude, gym.longitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showGymSheet(gym),
                        child: Icon(
                          Icons.location_on,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
