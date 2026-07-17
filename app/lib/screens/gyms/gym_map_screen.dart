import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../models/gym_model.dart';
import '../../models/osm_gym_candidate.dart';
import '../../services/geolocation_service.dart';
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

/// Un lieu trouvé par la recherche : soit une salle déjà confirmée, soit
/// une salle OpenStreetMap pas encore ajoutée.
class _SearchResult {
  _SearchResult.gym(GymModel gym)
      : name = gym.name,
        latitude = gym.latitude,
        longitude = gym.longitude,
        gym = gym,
        osmCandidate = null;

  _SearchResult.osm(OsmGymCandidate candidate)
      : name = candidate.name,
        latitude = candidate.latitude,
        longitude = candidate.longitude,
        gym = null,
        osmCandidate = candidate;

  final String name;
  final double latitude;
  final double longitude;
  final GymModel? gym;
  final OsmGymCandidate? osmCandidate;
}

/// Carte des salles : les salles déjà confirmées dans GymQuest (repère plein,
/// on tape pour ouvrir la fiche), les salles connues d'OpenStreetMap pas
/// encore confirmées (repère fin, on tape pour les valider), une recherche
/// par nom, et un mode ajout libre pour les salles absentes des deux. Fond
/// de carte CARTO Voyager (gratuit, pas de clé requise).
class GymMapScreen extends ConsumerStatefulWidget {
  const GymMapScreen({super.key});

  @override
  ConsumerState<GymMapScreen> createState() => _GymMapScreenState();
}

class _GymMapScreenState extends ConsumerState<GymMapScreen> {
  static const _brittanyCenter = LatLng(48.15, -2.9);
  final _mapController = MapController();
  final _searchController = TextEditingController();
  bool _addingMode = false;
  bool _busy = false;
  bool _locating = false;
  String _query = '';
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Localise l'utilisateur et centre la carte sur lui. Silencieux en cas
  /// d'échec au chargement (l'utilisateur n'a peut-être pas encore répondu
  /// au prompt du navigateur) ; affiche l'erreur seulement si déclenché à
  /// la main via le bouton "Ma position".
  Future<void> _locateUser({bool manual = false}) async {
    setState(() => _locating = true);
    try {
      final position = await GeolocationService().getCurrentPosition();
      if (!mounted) return;
      setState(() => _userPosition = position);
      _mapController.move(LatLng(position.latitude, position.longitude), 13);
    } catch (e) {
      if (manual && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Localisation indisponible : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

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

  void _selectSearchResult(_SearchResult result) {
    _mapController.move(LatLng(result.latitude, result.longitude), 15);
    setState(() {
      _query = '';
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
    if (result.gym != null) {
      context.push('/gyms/${result.gym!.id}');
    } else if (result.osmCandidate != null) {
      _confirmOsmCandidate(result.osmCandidate!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymsAsync = ref.watch(_gymsProvider);
    final osmAsync = ref.watch(_osmCandidatesProvider);
    final scheme = Theme.of(context).colorScheme;
    final myGymId = ref.watch(myGymProvider).valueOrNull?.id;

    final gyms = gymsAsync.valueOrNull ?? [];
    final osmCandidates = osmAsync.valueOrNull ?? [];
    final unconfirmedOsm = osmCandidates.where((candidate) {
      return gyms.every(
        (gym) => _distanceMeters(candidate.latitude, candidate.longitude, gym.latitude, gym.longitude) > 150,
      );
    }).toList();

    final searchResults = _query.trim().isEmpty
        ? <_SearchResult>[]
        : [
            ...gyms.where((g) => g.name.toLowerCase().contains(_query.toLowerCase())).map(_SearchResult.gym),
            ...unconfirmedOsm
                .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
                .map(_SearchResult.osm),
          ].take(6).toList();

    final nearbyGyms = _userPosition == null
        ? <GymModel>[]
        : ([...gyms]..sort((a, b) => _distanceMeters(
                _userPosition!.latitude, _userPosition!.longitude, a.latitude, a.longitude)
            .compareTo(_distanceMeters(
                _userPosition!.latitude, _userPosition!.longitude, b.latitude, b.longitude))));

    return Scaffold(
      appBar: AppBar(title: const Text('Salles partenaires')),
      body: Stack(
        children: [
          gymsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Erreur : $err')),
            data: (gyms) => FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _brittanyCenter,
                initialZoom: 9,
                onTap: (tapPosition, point) => _handleMapTap(point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'app.gymquest',
                ),
                MarkerLayer(
                  markers: [
                    ...unconfirmedOsm.map(
                      (candidate) => Marker(
                        point: LatLng(candidate.latitude, candidate.longitude),
                        width: 36,
                        height: 36,
                        child: GestureDetector(
                          onTap: () => _confirmOsmCandidate(candidate),
                          child: _OsmPin(color: scheme.outline),
                        ),
                      ),
                    ),
                    ...gyms.map(
                      (gym) => Marker(
                        point: LatLng(gym.latitude, gym.longitude),
                        width: 46,
                        height: 46,
                        child: GestureDetector(
                          onTap: () => context.push('/gyms/${gym.id}'),
                          child: _GymPin(
                            color: gym.id == myGymId ? Colors.amber.shade700 : scheme.primary,
                            isMine: gym.id == myGymId,
                          ),
                        ),
                      ),
                    ),
                    if (_userPosition != null)
                      Marker(
                        point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                        width: 26,
                        height: 26,
                        child: const _MyLocationPin(),
                      ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap · © CARTO', onTap: () {}),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(28),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Chercher une salle par son nom…',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _query = '';
                                _searchController.clear();
                              }),
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: searchResults
                          .map((result) => ListTile(
                                dense: true,
                                leading: Icon(
                                  result.gym != null ? Icons.location_on : Icons.location_on_outlined,
                                  color: result.gym != null ? scheme.primary : scheme.outline,
                                ),
                                title: Text(result.name),
                                subtitle: Text(result.gym != null ? 'Salle GymQuest' : 'À valider (OpenStreetMap)'),
                                onTap: () => _selectSearchResult(result),
                              ))
                          .toList(),
                    ),
                  ),
                if (!_addingMode && searchResults.isEmpty && nearbyGyms.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: min(5, nearbyGyms.length),
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final gym = nearbyGyms[i];
                          final distKm = _distanceMeters(
                                _userPosition!.latitude,
                                _userPosition!.longitude,
                                gym.latitude,
                                gym.longitude,
                              ) /
                              1000;
                          return ActionChip(
                            avatar: Icon(Icons.near_me, size: 15, color: scheme.primary),
                            label: Text('${gym.name} · ${distKm.toStringAsFixed(1)} km'),
                            backgroundColor: Theme.of(context).colorScheme.surface,
                            onPressed: () => _selectSearchResult(_SearchResult.gym(gym)),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
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
                if (!_addingMode && searchResults.isEmpty)
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'locate',
            mini: true,
            tooltip: 'Ma position',
            onPressed: _locating ? null : () => _locateUser(manual: true),
            child: _locating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addGym',
            onPressed: () => setState(() => _addingMode = !_addingMode),
            icon: Icon(_addingMode ? Icons.close : Icons.add_location_alt),
            label: Text(_addingMode ? 'Annuler' : 'Ajouter une salle'),
            backgroundColor: _addingMode ? scheme.errorContainer : null,
          ),
        ],
      ),
    );
  }
}

/// Repère d'une salle confirmée : pastille pleine avec ombre portée, dorée
/// et étoilée pour "ma salle", verte sinon.
class _GymPin extends StatelessWidget {
  const _GymPin({required this.color, required this.isMine});

  final Color color;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Icon(
        isMine ? Icons.star : Icons.fitness_center,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

/// Repère d'une salle OpenStreetMap pas encore validée : plus discret,
/// contour uniquement, pour bien la distinguer d'une salle confirmée.
class _OsmPin extends StatelessWidget {
  const _OsmPin({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Icon(Icons.add_location_alt_outlined, color: color, size: 16),
    );
  }
}

/// Position actuelle de l'utilisateur : point bleu classique façon Google
/// Maps, pour se repérer par rapport aux salles affichées.
class _MyLocationPin extends StatelessWidget {
  const _MyLocationPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.blue.shade600,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 4),
          ],
        ),
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
