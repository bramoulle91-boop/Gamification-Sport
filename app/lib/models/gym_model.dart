class GymModel {
  GymModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.geofencingRadiusM = 100,
    this.liveAttendanceRate,
  });

  factory GymModel.fromMap(Map<String, dynamic> map) {
    final point = map['gps_coordinates'] as String? ?? '(0,0)';
    final coords = point
        .replaceAll('(', '')
        .replaceAll(')', '')
        .split(',')
        .map((e) => double.tryParse(e.trim()) ?? 0)
        .toList();
    return GymModel(
      id: map['id'] as String,
      name: map['name'] as String,
      latitude: coords.isNotEmpty ? coords[0] : 0,
      longitude: coords.length > 1 ? coords[1] : 0,
      geofencingRadiusM: (map['geofencing_radius_m'] as num?)?.toInt() ?? 100,
      liveAttendanceRate: (map['live_attendance_rate'] as num?)?.toDouble(),
    );
  }

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int geofencingRadiusM;
  final double? liveAttendanceRate;
}
