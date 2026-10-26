import 'dart:convert';

class RoutePoint {
  final double latitude;
  final double longitude;

  const RoutePoint({required this.latitude, required this.longitude});
}

class RouteResult {
  final double meters;
  final double durationSeconds;
  final List<RoutePoint> points;

  const RouteResult({
    required this.meters,
    required this.durationSeconds,
    required this.points,
  });
}

class RouteException implements Exception {
  final String message;

  const RouteException(this.message);

  @override
  String toString() => 'RouteException: $message';
}

class RoutingService {
  /// Membaca respons JSON OSRM dan mengubahnya menjadi RouteResult.
  static RouteResult parse(String body) {
    try {
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        throw const RouteException('Format respons tidak valid');
      }

      if (decoded['code'] != 'Ok') {
        throw RouteException('OSRM gagal menemukan rute: ${decoded['code']}');
      }

      final routes = decoded['routes'];

      if (routes is! List || routes.isEmpty) {
        throw const RouteException('Rute tidak ditemukan');
      }

      final route = routes.first;

      if (route is! Map<String, dynamic>) {
        throw const RouteException('Data rute tidak valid');
      }

      final distance = route['distance'];
      final duration = route['duration'];

      if (distance is! num || duration is! num) {
        throw const RouteException('Jarak atau durasi tidak valid');
      }

      final geometry = route['geometry'];
      final coordinates = geometry is Map<String, dynamic>
          ? geometry['coordinates']
          : null;

      if (coordinates is! List) {
        throw const RouteException('Koordinat rute tidak tersedia');
      }

      final points = <RoutePoint>[];

      for (final coordinate in coordinates) {
        if (coordinate is! List || coordinate.length < 2) {
          throw const RouteException('Koordinat rute tidak valid');
        }

        final longitude = coordinate[0];
        final latitude = coordinate[1];

        if (longitude is! num || latitude is! num) {
          throw const RouteException('Nilai koordinat tidak valid');
        }

        points.add(
          RoutePoint(
            latitude: latitude.toDouble(),
            longitude: longitude.toDouble(),
          ),
        );
      }

      return RouteResult(
        meters: distance.toDouble(),
        durationSeconds: duration.toDouble(),
        points: List.unmodifiable(points),
      );
    } on RouteException {
      rethrow;
    } on FormatException {
      throw const RouteException('Respons JSON tidak valid');
    } catch (e) {
      throw RouteException('Gagal membaca respons OSRM: $e');
    }
  }
}
