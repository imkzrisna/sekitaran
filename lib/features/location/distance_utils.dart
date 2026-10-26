import 'dart:math' as math;

/// Menghitung jarak garis lurus antara dua koordinat dalam meter.
double haversineMeters(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusMeters = 6371000.0;

  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);

  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.pow(math.sin(dLon / 2), 2);

  final clampedA = a.clamp(0.0, 1.0);
  final c = 2 * math.atan2(math.sqrt(clampedA), math.sqrt(1 - clampedA));

  return earthRadiusMeters * c;
}

double _toRadians(double degrees) => degrees * math.pi / 180;

/// Memeriksa validitas koordinat geografis.
bool isValidCoord(double? latitude, double? longitude) {
  if (latitude == null || longitude == null) return false;

  if (!latitude.isFinite || !longitude.isFinite) return false;

  if (latitude < -90 || latitude > 90) return false;
  if (longitude < -180 || longitude > 180) return false;

  // (0, 0) dianggap tidak valid sebagai koordinat toko pada aplikasi.
  if (latitude == 0 && longitude == 0) return false;

  return true;
}

/// Memformat jarak dalam meter atau kilometer.
String formatDistance(double meters) {
  if (!meters.isFinite || meters < 0) {
    throw ArgumentError.value(meters, 'meters', 'Jarak tidak valid');
  }

  if (meters.round() < 1000) {
    return '${meters.round()} m';
  }

  final kilometers = meters / 1000;
  return '${kilometers.toStringAsFixed(1).replaceAll('.', ',')} km';
}
