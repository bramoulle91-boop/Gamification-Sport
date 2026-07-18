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
    // Couvre plusieurs façons de tagger une salle de sport sur OSM, et les
    // bâtiments (way) en plus des simples points (node), avec leur centre.
    final bbox = '$south,$west,$north,$east';
    final query = '[out:json][timeout:25];'
        '('
        'node["leisure"="fitness_centre"]($bbox);'
        'way["leisure"="fitness_centre"]($bbox);'
        'node["sport"="fitness"]($bbox);'
        'way["sport"="fitness"]($bbox);'
        ');'
        'out center;';
    final uri = Uri.parse(_endpoint).replace(queryParameters: {'data': query});

    final http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 20));
    } catch (e) {
      throw Exception('Connexion à OpenStreetMap impossible : $e');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'OpenStreetMap a répondu avec une erreur ${response.statusCode} : '
        '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = data['elements'] as List<dynamic>? ?? [];

    final candidates = <OsmGymCandidate>[];
    for (final raw in elements) {
      final element = raw as Map<String, dynamic>;
      final lat = element['lat'] as num? ?? (element['center'] as Map<String, dynamic>?)?['lat'] as num?;
      final lon = element['lon'] as num? ?? (element['center'] as Map<String, dynamic>?)?['lon'] as num?;
      if (lat == null || lon == null) continue;
      final tags = element['tags'] as Map<String, dynamic>?;
      candidates.add(OsmGymCandidate(
        name: (tags?['name'] as String?) ?? 'Salle de sport',
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
      ));
    }
    return candidates;
  }
}
