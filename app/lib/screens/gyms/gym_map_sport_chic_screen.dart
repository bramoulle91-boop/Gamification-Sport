import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// === DESIGN SYSTEM — STYLE SPORT CHIC =====================================
const _kBackground = Color(0xFF000000);
const _kCard = Color(0xFF121212);
const _kBorder = Color(0xFF1C1C1E);
const _kAccent = Color(0xFF00E676);
const _kMuted = Color(0xFF8E8E93);

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

class _MockFriend {
  const _MockFriend({required this.name, required this.initials, required this.color});
  final String name;
  final String initials;
  final Color color;
}

class _MockGym {
  const _MockGym({
    required this.id,
    required this.name,
    required this.position,
    required this.isPartner,
    required this.athleteCount,
    required this.attendanceLevel,
    required this.hourlyAttendance,
    required this.nowIndex,
    required this.friendsHere,
    required this.challengeTitle,
    required this.challengePercent,
  });

  final String id;
  final String name;
  final LatLng position;
  final bool isPartner;
  final int athleteCount;
  final _AttendanceLevel attendanceLevel;
  final List<double> hourlyAttendance;
  final int nowIndex;
  final List<_MockFriend> friendsHere;
  final String challengeTitle;
  final double challengePercent;
}

// Position simulée de l'utilisateur, à quelques rues de Basic-Fit Quimper
// (décalée volontairement de la salle pour que le point bleu et le repère
// de salle restent visuellement distincts sur la carte).
const _mockUserPosition = LatLng(47.9975, -4.1010);

final _mockGyms = <_MockGym>[
  _MockGym(
    id: 'basic-fit-quimper',
    name: 'Basic-Fit Quimper',
    position: const LatLng(47.9950, -4.0980),
    isPartner: true,
    athleteCount: 34,
    attendanceLevel: _AttendanceLevel.moderate,
    hourlyAttendance: const [0.15, 0.2, 0.35, 0.5, 0.7, 0.85, 0.65, 0.4, 0.3, 0.45, 0.6, 0.3, 0.1, 0.08],
    nowIndex: 6,
    friendsHere: const [
      _MockFriend(name: 'Thomas', initials: 'TH', color: Color(0xFF3A7CFF)),
      _MockFriend(name: 'Julien', initials: 'JU', color: Color(0xFFFF7A3A)),
      _MockFriend(name: 'Camille', initials: 'CA', color: Color(0xFFB84AFF)),
    ],
    challengeTitle: 'Rameur',
    challengePercent: 0.72,
  ),
  _MockGym(
    id: 'orange-bleue-quimper',
    name: "L'Orange Bleue Quimper",
    position: const LatLng(47.9995, -4.1035),
    isPartner: true,
    athleteCount: 11,
    attendanceLevel: _AttendanceLevel.calm,
    hourlyAttendance: const [0.1, 0.12, 0.2, 0.3, 0.4, 0.35, 0.25, 0.2, 0.18, 0.22, 0.3, 0.2, 0.1, 0.05],
    nowIndex: 6,
    friendsHere: const [
      _MockFriend(name: 'Léa', initials: 'LE', color: Color(0xFFFF4A9C)),
    ],
    challengeTitle: 'Développé couché',
    challengePercent: 0.41,
  ),
  _MockGym(
    id: 'fitness-park-quimper',
    name: 'Fitness Park Quimper',
    position: const LatLng(47.9890, -4.0910),
    isPartner: false,
    athleteCount: 0,
    attendanceLevel: _AttendanceLevel.saturated,
    hourlyAttendance: const [0.3, 0.4, 0.5, 0.6, 0.8, 0.95, 0.9, 0.7, 0.5, 0.6, 0.7, 0.4, 0.2, 0.15],
    nowIndex: 6,
    friendsHere: const [],
    challengeTitle: '—',
    challengePercent: 0,
  ),
  _MockGym(
    id: 'salle-independante-erguer',
    name: 'Salle Indépendante — Ergué',
    position: const LatLng(47.9880, -4.1120),
    isPartner: false,
    athleteCount: 0,
    attendanceLevel: _AttendanceLevel.calm,
    hourlyAttendance: const [0.05, 0.1, 0.15, 0.2, 0.25, 0.3, 0.2, 0.15, 0.1, 0.1, 0.15, 0.1, 0.05, 0.05],
    nowIndex: 6,
    friendsHere: const [],
    challengeTitle: '—',
    challengePercent: 0,
  ),
];

/// Onglet 1 — La Gym Map & choix de la salle.
///
/// Composant autonome, données simulées localement (aucun appel réseau hors
/// du fond de carte) : pensé pour être branché tel quel dans FlutterFlow en
/// Custom Widget, ou remplacé plus tard par de vraies données Supabase.
class GymMapSportChicScreen extends StatefulWidget {
  const GymMapSportChicScreen({super.key});

  @override
  State<GymMapSportChicScreen> createState() => _GymMapSportChicScreenState();
}

class _GymMapSportChicScreenState extends State<GymMapSportChicScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  String _query = '';
  _MockGym? _selectedGym;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_MockGym> get _visibleGyms {
    if (_query.trim().isEmpty) return _mockGyms;
    final q = _query.toLowerCase();
    return _mockGyms.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  void _handlePinTap(_MockGym gym) {
    if (!gym.isPartner) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _kCard,
          content: Text(
            '${gym.name} n\'est pas encore une salle partenaire GymQuest.',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
      return;
    }
    _mapController.move(gym.position, 15);
    setState(() => _selectedGym = gym);
  }

  Future<void> _openDirections(_MockGym gym) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${gym.position.latitude},${gym.position.longitude}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'itinéraire.")),
      );
    }
  }

  void _showPlateauLockedDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _kBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock, color: _kMuted),
            SizedBox(width: 10),
            Text('Plateau verrouillé', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          "Pour préserver l'anonymat, vous devez scanner le QR code d'une machine "
          'physique sur place pour débloquer le direct.',
          style: TextStyle(color: _kMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris', style: TextStyle(color: _kAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sheetOpen = _selectedGym != null;

    return Scaffold(
      backgroundColor: _kBackground,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mockUserPosition,
              initialZoom: 14,
              onTap: (_, __) => setState(() => _selectedGym = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'app.gymquest',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _mockUserPosition,
                    width: 70,
                    height: 70,
                    child: const IgnorePointer(child: _PulsingUserDot()),
                  ),
                  ..._visibleGyms.map(
                    (gym) => Marker(
                      point: gym.position,
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _handlePinTap(gym),
                        child: _GymPin(isPartner: gym.isPartner),
                      ),
                    ),
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

          // === ZONE SUPÉRIEURE FLOTTANTE ===================================
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _GlassContainer(
                  borderRadius: 18,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(color: Colors.white),
                    cursorColor: _kAccent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      hintText: 'Rechercher une salle, une ville...',
                      hintStyle: TextStyle(color: _kMuted),
                      prefixIcon: Icon(Icons.search, color: _kMuted),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _GlassContainer(
                    borderRadius: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: const Text(
                      '⚪ Mode Préparation (Hors-ligne) - Scannez une machine pour entrer',
                      style: TextStyle(color: _kMuted, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // === SCRIM + BOTTOM SHEET ========================================
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
            bottom: sheetOpen ? 0 : -600,
            child: _selectedGym == null
                ? const SizedBox.shrink()
                : _GymBottomSheet(
                    gym: _selectedGym!,
                    onClose: () => setState(() => _selectedGym = null),
                    onGoTo: () => _openDirections(_selectedGym!),
                    onLockedTap: _showPlateauLockedDialog,
                  ),
          ),
        ],
      ),
    );
  }
}

/// Conteneur "verre dépoli" réutilisé pour la recherche et la pilule de statut.
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

/// Repère de salle : haltère vert émeraude si partenaire, gris mat sinon.
class _GymPin extends StatelessWidget {
  const _GymPin({required this.isPartner});

  final bool isPartner;

  @override
  Widget build(BuildContext context) {
    final color = isPartner ? _kAccent : _kMuted;
    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Icon(Icons.fitness_center, color: color, size: 20),
    );
  }
}

/// Fiche coulissante de la salle sélectionnée — les 4 rubriques imposées.
class _GymBottomSheet extends StatelessWidget {
  const _GymBottomSheet({
    required this.gym,
    required this.onClose,
    required this.onGoTo,
    required this.onLockedTap,
  });

  final _MockGym gym;
  final VoidCallback onClose;
  final VoidCallback onGoTo;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
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
                    // A. Affluence en direct
                    Row(
                      children: [
                        Text(
                          '${gym.athleteCount} Athlètes connectés',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: gym.attendanceLevel.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: gym.attendanceLevel.color.withOpacity(0.4)),
                          ),
                          child: Text(
                            '${gym.attendanceLevel.emoji} ${gym.attendanceLevel.label}',
                            style: TextStyle(color: gym.attendanceLevel.color, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _AttendanceHistogram(hourly: gym.hourlyAttendance, nowIndex: gym.nowIndex),
                    const SizedBox(height: 24),

                    // B. Confidentialité "Mes amis"
                    Text(
                      '${gym.friendsHere.length} ami${gym.friendsHere.length > 1 ? 's' : ''} s\'entraîne${gym.friendsHere.length > 1 ? 'nt' : ''} ici',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    if (gym.friendsHere.isEmpty)
                      const Text('Aucun ami connecté ici pour le moment.', style: TextStyle(color: _kMuted, fontSize: 13))
                    else
                      SizedBox(
                        height: 74,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: gym.friendsHere.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, i) {
                            final friend = gym.friendsHere[i];
                            return Column(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: friend.color,
                                  child: Text(
                                    friend.initials,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(friend.name, style: const TextStyle(color: _kMuted, fontSize: 11)),
                              ],
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 24),

                    // C. Défi de salle
                    if (gym.challengeTitle != '—') ...[
                      Row(
                        children: [
                          const Icon(Icons.emoji_events, color: Color(0xFFFFD60A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Défi ${gym.challengeTitle} : ${(gym.challengePercent * 100).toStringAsFixed(0)}% complété par la communauté de cette salle.',
                              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: gym.challengePercent,
                          minHeight: 6,
                          backgroundColor: _kBorder,
                          valueColor: const AlwaysStoppedAnimation(_kAccent),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            // D. Boutons d'action fixes
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _kBorder)),
              ),
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
                      onPressed: onLockedTap,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFF1C1C1E),
                        side: const BorderSide(color: Color(0xFF2C2C2E)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.lock, size: 14, color: _kMuted),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Se connecter au Plateau',
                              style: TextStyle(color: _kMuted, fontWeight: FontWeight.w700, fontSize: 13),
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

/// Mini-histogramme vertical façon Apple Fitness, avec ligne "Maintenant".
class _AttendanceHistogram extends StatelessWidget {
  const _AttendanceHistogram({required this.hourly, required this.nowIndex});

  final List<double> hourly;
  final int nowIndex;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth / hourly.length;
          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(hourly.length, (i) {
                  final isNow = i == nowIndex;
                  final isPast = i <= nowIndex;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 56 * hourly[i].clamp(0.05, 1.0),
                          decoration: BoxDecoration(
                            color: isNow ? _kAccent : _kAccent.withOpacity(isPast ? 0.55 : 0.22),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned(
                left: (barWidth * (nowIndex + 0.5) - 1).clamp(0.0, constraints.maxWidth - 2),
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: const Color(0xFFFF453A)),
              ),
            ],
          );
        },
      ),
    );
  }
}
