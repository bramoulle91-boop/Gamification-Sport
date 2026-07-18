import 'dart:math';

import 'package:geolocator/geolocator.dart';

class GeolocationService {
  /// Demande l'autorisation puis renvoie la position actuelle de l'appareil.
  /// Lève une [Exception] si l'utilisateur refuse ou si le GPS est désactivé.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('La localisation est désactivée sur cet appareil.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permission de localisation refusée.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permission de localisation refusée définitivement.');
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Distance en mètres entre deux points (formule de Haversine).
  double distanceInMeters({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadiusM = 6371000.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusM * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  bool isWithinGeofence({
    required Position position,
    required double gymLat,
    required double gymLon,
    required int radiusM,
  }) {
    final distance = distanceInMeters(
      lat1: position.latitude,
      lon1: position.longitude,
      lat2: gymLat,
      lon2: gymLon,
    );
    return distance <= radiusM;
  }
}
