import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/gym_model.dart';
import '../../services/providers.dart';

final _gymsProvider = FutureProvider<List<GymModel>>((ref) {
  return ref.watch(gymServiceProvider).fetchAllGyms();
});

/// Carte des salles partenaires : on choisit sa salle habituelle en tapant
/// sur un repère (ouvre sa fiche), ou on ajoute une nouvelle salle en tapant
/// n'importe où sur la carte en mode ajout. Fond de carte OpenStreetMap
/// (gratuit, pas de clé requise).
class GymMapScreen extends ConsumerStatefulWidget {
  const GymMapScreen({super.key});

  @override
  ConsumerState<GymMapScreen> createState() => _GymMapScreenState();
}

class _GymMapScreenState extends ConsumerState<GymMapScreen> {
  static const _brittanyCenter = LatLng(48.15, -2.9);
  bool _addingMode = false;
  bool _creating = false;

  Future<void> _handleMapTap(LatLng point) async {
    if (!_addingMode) return;
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour ajouter une salle.')),
      );
      return;
    }
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameGymDialog(),
    );
    if (name == null || name.trim().isEmpty) return;

    setState(() => _creating = true);
    try {
      await ref.read(gymServiceProvider).createGym(
            name: name.trim(),
            latitude: point.latitude,
            longitude: point.longitude,
          );
      ref.invalidate(_gymsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$name ajoutée à la carte 📍')));
        setState(() => _addingMode = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymsAsync = ref.watch(_gymsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Salles partenaires')),
      body: Stack(
        children: [
          gymsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erreur : $err')),
            data: (gyms) => FlutterMap(
              options: MapOptions(
                initialCenter: _brittanyCenter,
                initialZoom: 9,
                onTap: (tapPosition, point) => _handleMapTap(point),
              ),
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
                            onTap: () => context.push('/gyms/${gym.id}'),
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
          if (_addingMode)
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.touch_app, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Tape sur la carte à l'endroit de la salle à ajouter",
                          style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                      ),
                      if (_creating) const CircularProgressIndicator(strokeWidth: 2),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _addingMode = !_addingMode),
        icon: Icon(_addingMode ? Icons.close : Icons.add_location_alt),
        label: Text(_addingMode ? 'Annuler' : 'Ajouter une salle'),
        backgroundColor: _addingMode ? Theme.of(context).colorScheme.errorContainer : null,
      ),
    );
  }
}

class _NameGymDialog extends StatefulWidget {
  const _NameGymDialog();

  @override
  State<_NameGymDialog> createState() => _NameGymDialogState();
}

class _NameGymDialogState extends State<_NameGymDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nom de la salle'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'ex: Basic-Fit Lorient'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
