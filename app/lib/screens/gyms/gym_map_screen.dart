import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/gym_model.dart';
import '../../models/osm_gym_candidate.dart';
import '../../services/providers.dart';

final _gymsProvider = FutureProvider<List<GymModel>>((ref) {
  return ref.watch(gymServiceProvider).fetchAllGyms();
});

/// Salles de sport connues d'OpenStreetMap (Basic-Fit, Fitness Park, salles
/// indépendantes...) dans la zone couverte par la carte, pas encore
/// confirmées dans GymQuest.
final _osmCandidatesProvider = FutureProvider<List<OsmGymCandidate>>((ref) {
  return ref.watch(osmGymServiceProvider).fetchCandidates(
        south: 47.2,
        west: -5.2,
        north: 48.9,
        east: -0.9,
      );
});

double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusM = 6371000.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
  return earthRadiusM * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Carte des salles : les salles déjà confirmées dans GymQuest (repère plein,
/// on tape pour ouvrir la fiche), les salles connues d'OpenStreetMap pas
/// encore confirmées (repère fin, on tape pour les valider), et un mode
/// ajout libre pour les salles qui ne sont sur aucune des deux. Fond de
/// carte OpenStreetMap (gratuit, pas de clé requise).
class GymMapScreen extends ConsumerStatefulWidget {
  const GymMapScreen({super.key});

  @override
  ConsumerState<GymMapScreen> createState() => _GymMapScreenState();
}

class _GymMapScreenState extends ConsumerState<GymMapScreen> {
  static const _brittanyCenter = LatLng(48.15, -2.9);
  bool _addingMode = false;
  bool _busy = false;

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
    await _createGym(name.trim(), point.latitude, point.longitude);
    if (mounted) setState(() => _addingMode = false);
  }

  Future<void> _confirmOsmCandidate(OsmGymCandidate candidate) async {
    if (ref.read(currentUserIdProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connecte-toi pour valider une salle.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(candidate.name),
        content: const Text('Ajouter cette salle à GymQuest ?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Valider')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _createGym(candidate.name, candidate.latitude, candidate.longitude);
  }

  Future<void> _createGym(String name, double lat, double lon) async {
    setState(() => _busy = true);
    try {
      await ref.read(gymServiceProvider).createGym(name: name, latitude: lat, longitude: lon);
      ref.invalidate(_gymsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name ajoutée 📍')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymsAsync = ref.watch(_gymsProvider);
    final osmAsync = ref.watch(_osmCandidatesProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Salles partenaires')),
      body: Stack(
        children: [
          gymsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erreur : $err')),
            data: (gyms) {
              // On masque les salles OSM trop proches d'une salle déjà
              // confirmée, pour éviter un doublon visuel de repères.
              final osmCandidates = osmAsync.valueOrNull ?? [];
              final unconfirmedOsm = osmCandidates.where((candidate) {
                return gyms.every(
                  (gym) => _distanceMeters(candidate.latitude, candidate.longitude, gym.latitude, gym.longitude) > 150,
                );
              }).toList();

              return FlutterMap(
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
                    markers: [
                      ...unconfirmedOsm.map(
                        (candidate) => Marker(
                          point: LatLng(candidate.latitude, candidate.longitude),
                          width: 40,
                          height: 40,
                          child: GestureDetector(
                            onTap: () => _confirmOsmCandidate(candidate),
                            child: Icon(Icons.location_on_outlined, color: scheme.outline, size: 34),
                          ),
                        ),
                      ),
                      ...gyms.map(
                        (gym) => Marker(
                          point: LatLng(gym.latitude, gym.longitude),
                          width: 44,
                          height: 44,
                          child: GestureDetector(
                            onTap: () => context.push('/gyms/${gym.id}'),
                            child: Icon(Icons.location_on, color: scheme.primary, size: 40),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                if (_addingMode)
                  Card(
                    color: scheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Tape sur la carte à l'endroit de la salle à ajouter",
                              style: TextStyle(color: scheme.onPrimaryContainer),
                            ),
                          ),
                          if (_busy) const CircularProgressIndicator(strokeWidth: 2),
                        ],
                      ),
                    ),
                  ),
                if (!_addingMode)
                  osmAsync.when(
                    loading: () => const Card(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 8),
                            Text('Recherche des salles OpenStreetMap à proximité…', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    error: (err, _) => Card(
                      color: scheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'OpenStreetMap indisponible : $err',
                                style: TextStyle(color: scheme.onErrorContainer, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (candidates) => Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: scheme.outline, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                candidates.isEmpty
                                    ? 'Aucune salle OpenStreetMap trouvée dans cette zone.'
                                    : '${candidates.length} salle(s) OpenStreetMap trouvée(s) — repères fins à valider.',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(() => _addingMode = !_addingMode),
        icon: Icon(_addingMode ? Icons.close : Icons.add_location_alt),
        label: Text(_addingMode ? 'Annuler' : 'Ajouter une salle'),
        backgroundColor: _addingMode ? scheme.errorContainer : null,
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
