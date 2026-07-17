import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/osm_gym_candidate.dart';

/// Interroge OpenStreetMap (API Overpass, gratuite, sans clé) pour trouver
/// les vraies salles de sport déjà répertoriées (Basic-Fit, Fitness Park,
/// salles indépendantes...) dans une zone, à proposer sur la carte.
class OsmGymService {
  static const _endpoint = 'https://overpass-api.de/api/interpreter';

  Future<List<OsmGymCandidate>> fetchCandidates({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final query = '[out:json][timeout:25];'
        'node["leisure"="fitness_centre"]($south,$west,$north,$east);'
        'out body;';
    final uri = Uri.parse(_endpoint).replace(queryParameters: {'data': query});

    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw Exception('Impossible de charger les salles à proximité (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    return elements
        .map((e) => e as Map<String, dynamic>)
        .where((e) => e['lat'] != null && e['lon'] != null)
        .map((e) {
          final tags = e['tags'] as Map<String, dynamic>?;
          return OsmGymCandidate(
            name: (tags?['name'] as String?) ?? 'Salle de sport',
            latitude: (e['lat'] as num).toDouble(),
            longitude: (e['lon'] as num).toDouble(),
          );
        })
        .toList();
  }
}
