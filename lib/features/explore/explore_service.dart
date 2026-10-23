import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show IconData, Icons;
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum ShopCategory {
  restaurant('Local Restaurant', Icons.restaurant_outlined),
  grocery('Grocery Store', Icons.shopping_basket_outlined),
  exchange('Money Changer', Icons.currency_exchange);

  const ShopCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class Shop {
  const Shop({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
  });

  final String id;
  final String name;
  final ShopCategory category;
  final LatLng position;
}

class ShopDistance {
  const ShopDistance(this.shop, this.meters);
  final Shop shop;
  final double meters;
}

const _distance = Distance();

/// Jarak garis lurus (udara) dalam meter.
double airMeters(LatLng a, LatLng b) => _distance.as(LengthUnit.Meter, a, b);

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
}

String formatDuration(double seconds) {
  final mins = (seconds / 60).round();
  if (mins < 1) return '< 1 min';
  if (mins < 60) return '$mins min';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// TODO: ganti dengan toko dari database (latitude/longitude tiap toko).
/// Sementara toko contoh diletakkan di sekitar [origin] agar jarak dan rute
/// bisa dicoba di mana pun.
List<Shop> sampleShopsAround(LatLng origin) {
  Shop s(String id, String name, ShopCategory c, double dLat, double dLng) =>
      Shop(
        id: id,
        name: name,
        category: c,
        position: LatLng(origin.latitude + dLat, origin.longitude + dLng),
      );
  return [
    s('s1', 'Warung Makan Bu Sari', ShopCategory.restaurant, 0.00073, 0),
    s('s2', 'Toko Sembako Maju', ShopCategory.grocery, 0, -0.0009),
    s('s3', 'Penukaran Uang Jetis', ShopCategory.exchange, -0.0018, 0.0012),
    s('s4', 'Warung Makan Pak Joko', ShopCategory.restaurant, 0.0035, 0.002),
    s('s5', 'Toko Sembako Berkah', ShopCategory.grocery, -0.006, -0.004),
    s('s6', 'Money Changer Sentosa', ShopCategory.exchange, 0.012, 0.01),
  ];
}

class ShopsFailure implements Exception {
  const ShopsFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

ShopCategory? _categoryFrom(String? c) => switch (c) {
  'restaurant' => ShopCategory.restaurant,
  'grocery' => ShopCategory.grocery,
  'money_changer' => ShopCategory.exchange,
  _ => null,
};

double? _toD(Object? v) =>
    v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

/// Toko dari tabel businesses. Baris tanpa koordinat valid atau tanpa
/// kategori yang dikenal dilewati.
Future<List<Shop>> fetchShops() async {
  try {
    final rows = await Supabase.instance.client
        .from('businesses')
        .select('id, name, category, latitude, longitude')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .limit(500);
    final out = <Shop>[];
    for (final r in rows) {
      final cat = _categoryFrom(r['category'] as String?);
      final lat = _toD(r['latitude']);
      final lng = _toD(r['longitude']);
      if (cat == null || lat == null || lng == null) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      if (lat == 0 && lng == 0) continue;
      out.add(
        Shop(
          id: r['id'] as String,
          name: r['name'] as String,
          category: cat,
          position: LatLng(lat, lng),
        ),
      );
    }
    return out;
  } catch (_) {
    throw const ShopsFailure('Could not load shops. Check your connection.');
  }
}

class RoadRoute {
  const RoadRoute({
    required this.points,
    required this.meters,
    required this.seconds,
  });

  final List<LatLng> points;
  final double meters;
  final double seconds;
}

class RouteFailure implements Exception {
  const RouteFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Rute jalan lewat server demo OSRM (profil mobil). Hanya untuk pemakaian
/// ringan: panggil saat dibutuhkan saja, jangan berulang-ulang.
Future<RoadRoute> fetchRoadRoute(LatLng from, LatLng to) async {
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
    '?overview=full&geometries=geojson',
  );
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    final req = await client.getUrl(uri).timeout(const Duration(seconds: 10));
    req.headers.set(
      HttpHeaders.userAgentHeader,
      'SekitaranApp/1.0 (student project)',
    );
    final res = await req.close().timeout(const Duration(seconds: 10));
    final body = await res
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(body);
    if (data is! Map<String, dynamic> || data['code'] != 'Ok') {
      throw const RouteFailure('No road route was found between these points.');
    }
    final routes = data['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const RouteFailure('No road route was found between these points.');
    }
    final r = routes.first as Map<String, dynamic>;
    final coords = (r['geometry']['coordinates'] as List)
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
    if (coords.length < 2) {
      throw const RouteFailure('No road route was found between these points.');
    }
    return RoadRoute(
      points: coords,
      meters: (r['distance'] as num).toDouble(),
      seconds: (r['duration'] as num).toDouble(),
    );
  } on RouteFailure {
    rethrow;
  } on TimeoutException {
    throw const RouteFailure('Loading the route took too long. Please retry.');
  } on SocketException {
    throw const RouteFailure('No internet connection.');
  } catch (_) {
    throw const RouteFailure('Could not load the road route.');
  } finally {
    client.close(force: true);
  }
}
