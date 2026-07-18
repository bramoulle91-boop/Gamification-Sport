import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/friendship_model.dart';
import '../../models/gym_checkin_model.dart';
import '../../models/gym_model.dart';
import '../../models/machine_king_model.dart';
import '../../models/osm_gym_candidate.dart';
import '../../services/geolocation_service.dart';
import '../../services/providers.dart';

// === DESIGN SYSTEM — STYLE SPORT CHIC =====================================
const _kBackground = Color(0xFF000000);
const _kCard = Color(0xFF121212);
const _kBorder = Color(0xFF1C1C1E);
const _kAccent = Color(0xFF00E676);
const _kMuted = Color(0xFF8E8E93);
const _kGold = Color(0xFFFFD60A);

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

final _myFriendshipsProvider = FutureProvider<List<FriendshipModel>>((ref) {
  return ref.watch(friendshipServiceProvider).fetchMyFriendships();
});

final _gymKingsProvider = FutureProvider.family<List<MachineKingModel>, String>((ref, gymId) {
  return ref.watch(machineKingServiceProvider).fetchMachineKings(gymId: gymId);
});

/// Qui de GymQuest est passé par cette salle aujourd'hui (check-ins réels,
/// pas juste "salle habituelle") — sert à l'affluence et aux amis connectés.
final _gymCheckinsProvider = FutureProvider.family<List<GymCheckinModel>, String>((ref, gymId) {
  return ref.watch(gymServiceProvider).fetchTodaysCheckins(gymId);
});

String _checkinTimeAgo(DateTime at) {
  final diff = DateTime.now().toUtc().difference(at.toUtc());
  if (diff.inMinutes < 1) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  return 'il y a ${diff.inHours} h';
}

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

/// Carte des salles, style "Sport Chic" (fond noir, accents vert émeraude) :
/// les salles déjà confirmées dans GymQuest ouvrent une fiche coulissante
/// avec l'affluence réelle, les amis qui s'y entraînent et le record en
/// cours sur une machine ; les salles connues d'OpenStreetMap pas encore
/// confirmées se valident d'un tap ; recherche par nom ; mode ajout libre ;
/// géolocalisation avec salles les plus proches.
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
  GymModel? _selectedGym;

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
      builder: (context) => _DarkAlertDialog(
        title: candidate.name,
        content: 'Ajouter cette salle à GymQuest ?',
        confirmLabel: 'Valider',
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

  void _selectGym(GymModel gym) {
    _mapController.move(LatLng(gym.latitude, gym.longitude), 15);
    setState(() => _selectedGym = gym);
  }

  void _selectSearchResult(_SearchResult result) {
    setState(() {
      _query = '';
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
    if (result.gym != null) {
      _selectGym(result.gym!);
    } else if (result.osmCandidate != null) {
      _mapController.move(LatLng(result.latitude, result.longitude), 15);
      _confirmOsmCandidate(result.osmCandidate!);
    }
  }

  Future<void> _openDirections(GymModel gym) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${gym.latitude},${gym.longitude}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'itinéraire.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final gymsAsync = ref.watch(_gymsProvider);
    final osmAsync = ref.watch(_osmCandidatesProvider);
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

    final sheetOpen = _selectedGym != null;

    return Scaffold(
      backgroundColor: _kBackground,
      appBar: AppBar(
        backgroundColor: _kBackground,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Salles partenaires'),
      ),
      body: Stack(
        children: [
          gymsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: _kAccent)),
            error: (err, _) => Center(child: Text('Erreur : $err', style: const TextStyle(color: Colors.white))),
            data: (gyms) => FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _brittanyCenter,
                initialZoom: 9,
                onTap: (tapPosition, point) {
                  if (_addingMode) {
                    _handleMapTap(point);
                  } else if (_selectedGym != null) {
                    setState(() => _selectedGym = null);
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
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
                          child: const _OsmPin(),
                        ),
                      ),
                    ),
                    ...gyms.map(
                      (gym) => Marker(
                        point: LatLng(gym.latitude, gym.longitude),
                        width: 46,
                        height: 46,
                        child: GestureDetector(
                          onTap: () => _selectGym(gym),
                          child: _GymPin(isMine: gym.id == myGymId),
                        ),
                      ),
                    ),
                    if (_userPosition != null)
                      Marker(
                        point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                        width: 70,
                        height: 70,
                        child: const IgnorePointer(child: _PulsingUserDot()),
                      ),
                  ],
                ),
                const RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap · © CARTO'),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: Column(
              children: [
                _GlassContainer(
                  borderRadius: 28,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _kAccent,
                    decoration: const InputDecoration(
                      hintText: 'Rechercher une salle, une ville…',
                      hintStyle: TextStyle(color: _kMuted),
                      prefixIcon: Icon(Icons.search, color: _kMuted),
                      suffixIcon: null,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                if (searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: searchResults
                          .map((result) => ListTile(
                                dense: true,
                                leading: Icon(
                                  result.gym != null ? Icons.fitness_center : Icons.location_on_outlined,
                                  color: result.gym != null ? _kAccent : _kMuted,
                                ),
                                title: Text(result.name, style: const TextStyle(color: Colors.white)),
                                subtitle: Text(
                                  result.gym != null ? 'Salle GymQuest' : 'À valider (OpenStreetMap)',
                                  style: const TextStyle(color: _kMuted),
                                ),
                                onTap: () => _selectSearchResult(result),
                              ))
                          .toList(),
                    ),
                  ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassContainer(
                    borderRadius: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Text(
                      _userPosition != null
                          ? '🟢 Position activée — scanne une machine pour valider'
                          : '⚪ Active ta position pour voir les salles proches',
                      style: const TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
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
                            avatar: const Icon(Icons.near_me, size: 15, color: _kAccent),
                            label: Text(
                              '${gym.name} · ${distKm.toStringAsFixed(1)} km',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            backgroundColor: _kCard,
                            side: const BorderSide(color: _kBorder),
                            onPressed: () => _selectGym(gym),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                if (_addingMode)
                  Container(
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kAccent.withOpacity(0.4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app, color: _kAccent),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              "Tape sur la carte à l'endroit de la salle à ajouter",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          if (_busy) const CircularProgressIndicator(strokeWidth: 2, color: _kAccent),
                        ],
                      ),
                    ),
                  ),
                if (!_addingMode && searchResults.isEmpty)
                  osmAsync.when(
                    loading: () => const _StatusCard(
                      icon: null,
                      loading: true,
                      text: 'Recherche des salles OpenStreetMap à proximité…',
                    ),
                    error: (err, _) => _StatusCard(
                      icon: Icons.error_outline,
                      iconColor: const Color(0xFFFF453A),
                      text: 'OpenStreetMap indisponible : $err',
                    ),
                    data: (candidates) => _StatusCard(
                      icon: Icons.location_on_outlined,
                      iconColor: _kMuted,
                      text: candidates.isEmpty
                          ? 'Aucune salle OpenStreetMap trouvée dans cette zone.'
                          : '${candidates.length} salle(s) OpenStreetMap trouvée(s) — repères fins à valider.',
                    ),
                  ),
              ],
            ),
          ),

          // === SCRIM + FICHE SALLE =========================================
          IgnorePointer(
            ignoring: !sheetOpen,
            child: AnimatedOpacity(
              opacity: sheetOpen ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: GestureDetector(
                onTap: () => setState(() => _selectedGym = null),
                child: Container(color: Colors.black.withOpacity(0.55)),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: sheetOpen ? 0 : -700,
            child: _selectedGym == null
                ? const SizedBox.shrink()
                : _GymBottomSheet(
                    gym: _selectedGym!,
                    isMyGym: _selectedGym!.id == myGymId,
                    onClose: () => setState(() => _selectedGym = null),
                    onGoTo: () => _openDirections(_selectedGym!),
                    onSeeGym: () {
                      final gymId = _selectedGym!.id;
                      setState(() => _selectedGym = null);
                      context.push('/gyms/$gymId');
                    },
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
            backgroundColor: _kCard,
            foregroundColor: _kAccent,
            onPressed: _locating ? null : () => _locateUser(manual: true),
            child: _locating
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent),
                  )
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'addGym',
            backgroundColor: _addingMode ? const Color(0xFF3A0F0F) : _kCard,
            foregroundColor: _addingMode ? const Color(0xFFFF453A) : _kAccent,
            onPressed: () => setState(() => _addingMode = !_addingMode),
            icon: Icon(_addingMode ? Icons.close : Icons.add_location_alt),
            label: Text(
              _addingMode ? 'Annuler' : 'Ajouter une salle',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conteneur "verre dépoli" réutilisé pour la recherche et les pilules de statut.
class _GlassContainer extends StatelessWidget {
  const _GlassContainer({required this.child, required this.borderRadius, this.padding});

  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: _kCard.withOpacity(0.6),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: _kBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.text, this.icon, this.iconColor, this.loading = false});

  final String text;
  final IconData? icon;
  final Color? iconColor;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent))
            else if (icon != null)
              Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(color: _kMuted, fontSize: 12))),
          ],
        ),
      ),
    );
  }
}

/// Point bleu de l'utilisateur avec halo vert émeraude pulsant.
class _PulsingUserDot extends StatefulWidget {
  const _PulsingUserDot();

  @override
  State<_PulsingUserDot> createState() => _PulsingUserDotState();
}

class _PulsingUserDotState extends State<_PulsingUserDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Container(
                width: 20 + t * 46,
                height: 20 + t * 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kAccent, width: 2),
                ),
              ),
            ),
            child!,
          ],
        );
      },
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF3A7CFF),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(color: _kAccent.withOpacity(0.7), blurRadius: 10)],
        ),
      ),
    );
  }
}

/// Repère d'une salle confirmée : haltère vert émeraude, doré et étoilé pour
/// "ma salle".
class _GymPin extends StatelessWidget {
  const _GymPin({required this.isMine});

  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final color = isMine ? _kGold : _kAccent;
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(isMine ? Icons.star : Icons.fitness_center, color: color, size: 20),
    );
  }
}

/// Repère d'une salle OpenStreetMap pas encore validée : discret, gris mat.
class _OsmPin extends StatelessWidget {
  const _OsmPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCard.withOpacity(0.85),
        shape: BoxShape.circle,
        border: Border.all(color: _kMuted, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: const Icon(Icons.add_location_alt_outlined, color: _kMuted, size: 16),
    );
  }
}

enum _AttendanceLevel { calm, moderate, saturated }

extension on _AttendanceLevel {
  Color get color {
    switch (this) {
      case _AttendanceLevel.calm:
        return _kAccent;
      case _AttendanceLevel.moderate:
        return const Color(0xFFFF9F0A);
      case _AttendanceLevel.saturated:
        return const Color(0xFFFF453A);
    }
  }

  String get emoji {
    switch (this) {
      case _AttendanceLevel.calm:
        return '🟢';
      case _AttendanceLevel.moderate:
        return '🟠';
      case _AttendanceLevel.saturated:
        return '🔴';
    }
  }

  String get label {
    switch (this) {
      case _AttendanceLevel.calm:
        return 'Calme';
      case _AttendanceLevel.moderate:
        return 'Modérée';
      case _AttendanceLevel.saturated:
        return 'Saturée';
    }
  }
}

Color _colorForPseudo(String pseudo) {
  const palette = [
    Color(0xFF3A7CFF),
    Color(0xFFFF7A3A),
    Color(0xFFB84AFF),
    Color(0xFFFF4A9C),
    Color(0xFF00E676),
    Color(0xFFFFD60A),
  ];
  return palette[pseudo.hashCode.abs() % palette.length];
}

/// Fiche coulissante d'une salle confirmée : affluence réelle, amis qui s'y
/// entraînent (salle habituelle en commun) et record en cours sur une
/// machine de la salle, avec itinéraire et accès aux machines.
class _GymBottomSheet extends ConsumerWidget {
  const _GymBottomSheet({
    required this.gym,
    required this.isMyGym,
    required this.onClose,
    required this.onGoTo,
    required this.onSeeGym,
  });

  final GymModel gym;
  final bool isMyGym;
  final VoidCallback onClose;
  final VoidCallback onGoTo;
  final VoidCallback onSeeGym;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(currentUserIdProvider) != null;
    final friendshipsAsync = ref.watch(_myFriendshipsProvider);
    final kingsAsync = ref.watch(_gymKingsProvider(gym.id));
    final checkinsAsync = ref.watch(_gymCheckinsProvider(gym.id));
    final myId = ref.watch(currentUserIdProvider);

    final friendIds = (isLoggedIn && myId != null)
        ? (friendshipsAsync.valueOrNull ?? [])
            .where((f) => f.status == FriendshipStatus.unlocked)
            .map((f) => f.userId1 == myId ? f.userId2 : f.userId1)
            .toSet()
        : <String>{};

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.78),
      decoration: const BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: _kBorder),
          left: BorderSide(color: _kBorder),
          right: BorderSide(color: _kBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(4))),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
                children: [
                  if (isMyGym) ...[
                    const Icon(Icons.star, color: _kGold, size: 20),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      gym.name,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: _kMuted)),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A. Affluence réelle — comptée sur les check-ins GymQuest
                    // du jour (pas la fréquentation totale de la salle).
                    checkinsAsync.when(
                      loading: () => const SizedBox(
                        height: 20,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent)),
                      ),
                      error: (_, __) => const Text(
                        'Affluence non disponible pour le moment.',
                        style: TextStyle(color: _kMuted, fontSize: 13),
                      ),
                      data: (checkins) {
                        final count = checkins.map((c) => c.userId).toSet().length;
                        final level = count == 0
                            ? _AttendanceLevel.calm
                            : count <= 3
                                ? _AttendanceLevel.moderate
                                : _AttendanceLevel.saturated;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '$count connexion${count > 1 ? 's' : ''} GymQuest aujourd\'hui',
                                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                if (count > 0) ...[
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: level.color.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(color: level.color.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      '${level.emoji} ${level.label}',
                                      style: TextStyle(color: level.color, fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Basé sur les utilisateurs GymQuest, pas sur la fréquentation totale de la salle.',
                              style: TextStyle(color: _kMuted, fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // B. Amis connectés aujourd'hui dans cette salle (check-in
                    // réel, pas juste "salle habituelle").
                    if (!isLoggedIn)
                      const Text(
                        'Connecte-toi pour voir tes amis connectés ici.',
                        style: TextStyle(color: _kMuted, fontSize: 13),
                      )
                    else
                      checkinsAsync.when(
                        loading: () => const SizedBox(
                          height: 20,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent)),
                        ),
                        error: (_, __) => const Text(
                          'Amis connectés : non disponible pour le moment.',
                          style: TextStyle(color: _kMuted, fontSize: 13),
                        ),
                        data: (checkins) {
                          final friendCheckins = checkins.where((c) => friendIds.contains(c.userId)).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friendCheckins.isEmpty
                                    ? 'Aucun ami connecté ici aujourd\'hui'
                                    : '${friendCheckins.length} ami${friendCheckins.length > 1 ? 's' : ''} connecté${friendCheckins.length > 1 ? 's' : ''} ici aujourd\'hui',
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              if (friendCheckins.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 74,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: friendCheckins.length,
                                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                                    itemBuilder: (context, i) {
                                      final checkin = friendCheckins[i];
                                      final pseudo = checkin.pseudo;
                                      final initials =
                                          pseudo.length >= 2 ? pseudo.substring(0, 2).toUpperCase() : pseudo.toUpperCase();
                                      return Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: _colorForPseudo(pseudo),
                                            child: Text(
                                              initials,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(pseudo, style: const TextStyle(color: _kMuted, fontSize: 11)),
                                          Text(
                                            _checkinTimeAgo(checkin.checkedInAt),
                                            style: const TextStyle(color: _kMuted, fontSize: 9),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    const SizedBox(height: 24),

                    // C. Record en cours sur une machine de la salle
                    kingsAsync.when(
                      loading: () => const SizedBox(
                        height: 20,
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kAccent)),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (kings) {
                        if (kings.isEmpty) return const SizedBox.shrink();
                        MachineKingModel? best;
                        for (final k in kings) {
                          if (!k.hasKing) continue;
                          if (best == null || (k.kingWeightKg ?? 0) > (best.kingWeightKg ?? 0)) best = k;
                        }
                        if (best == null) {
                          return const Row(
                            children: [
                              Icon(Icons.emoji_events_outlined, color: _kMuted, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Sois le premier à devenir Roi d\'une machine ici 💪',
                                  style: TextStyle(color: _kMuted, fontSize: 13, height: 1.35),
                                ),
                              ),
                            ],
                          );
                        }
                        return Row(
                          children: [
                            const Icon(Icons.emoji_events, color: _kGold, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Roi de ${best.machineName} : ${best.kingPseudo} — ${best.kingWeightKg!.toStringAsFixed(0)} kg',
                                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // D. Boutons d'action fixes
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: _kBorder))),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onGoTo,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.black,
                        side: const BorderSide(color: _kAccent, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text(
                        'Y aller (Itinéraire) 🚗',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSeeGym,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        side: const BorderSide(color: Color(0xFF2C2C2E)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Voir les machines',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkAlertDialog extends StatelessWidget {
  const _DarkAlertDialog({required this.title, required this.content, required this.confirmLabel});

  final String title;
  final String content;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _kBorder),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(content, style: const TextStyle(color: _kMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler', style: TextStyle(color: _kMuted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
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
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _kBorder),
      ),
      title: const Text('Nom de la salle', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        cursorColor: _kAccent,
        decoration: const InputDecoration(
          hintText: 'ex: Basic-Fit Lorient',
          hintStyle: TextStyle(color: _kMuted),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kBorder)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _kAccent)),
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler', style: TextStyle(color: _kMuted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _kAccent, foregroundColor: Colors.black),
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}
