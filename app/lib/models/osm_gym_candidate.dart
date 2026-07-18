/// Une salle de sport connue d'OpenStreetMap, pas encore confirmée dans
/// GymQuest — affichée sur la carte pour qu'on puisse la "valider" en un tap.
class OsmGymCandidate {
  OsmGymCandidate({required this.name, required this.latitude, required this.longitude});

  final String name;
  final double latitude;
  final double longitude;
}
