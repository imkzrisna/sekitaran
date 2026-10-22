import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sekitaran/features/store/plus_code.dart';

class MapsLinkException implements Exception {
  const MapsLinkException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// approx = true bila hanya pusat tampilan peta (@lat,lng), bukan pin tempat.
typedef MapsCoordinate = ({double lat, double lng, bool approx});

const _redirectCodes = {301, 302, 303, 307, 308};
const _userAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36';

bool _isGoogleHost(String host) {
  final h = host.toLowerCase();
  return h == 'goo.gl' ||
      h.endsWith('.goo.gl') ||
      RegExp(r'(^|\.)google\.[a-z.]+$').hasMatch(h);
}

/// Mengambil koordinat dari teks/URL tanpa akses jaringan. null jika tidak ada.
MapsCoordinate? parseMapsCoordinates(
  String input, {
  double? refLat,
  double? refLng,
}) {
  final plus = decodePlusCode(input, refLat: refLat, refLng: refLng);
  if (plus != null) return (lat: plus.lat, lng: plus.lng, approx: false);
  var text = input.trim();
  try {
    text = Uri.decodeFull(text);
  } catch (_) {}

  const n = r'(-?\d{1,3}(?:\.\d+)?)';
  final candidates = <(RegExp, bool)>[
    (RegExp('!3d$n!4d$n'), false), // pin tempat (paling akurat)
    (RegExp('[?&](?:q|ll|query|destination|daddr|center)=$n,[\\s+]*$n'), false),
    (RegExp('/(?:place|search|dir)/$n,[\\s+]*$n'), false),
    (RegExp('@$n,$n'), true), // pusat tampilan peta
    (RegExp('^$n\\s*,\\s*$n\$'), false), // "lat, lng" biasa
  ];

  for (final (re, approx) in candidates) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat == null || lng == null) continue;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
    if (lat == 0 && lng == 0) continue;
    return (lat: lat, lng: lng, approx: approx);
  }
  return null;
}

/// Mencari koordinat di isi HTML halaman tempat Google Maps.
MapsCoordinate? parseMapsCoordinatesFromPage(String body) {
  final text = body
      .replaceAll('%2C', ',')
      .replaceAll('\\u003d', '=')
      .replaceAll('\\u0026', '&')
      .replaceAll('&amp;', '&');
  final m = RegExp(r'center=(-?\d{1,3}\.\d+),(-?\d{1,3}\.\d+)')
      .firstMatch(text);
  if (m != null) {
    final lat = double.tryParse(m.group(1)!);
    final lng = double.tryParse(m.group(2)!);
    if (lat != null &&
        lng != null &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180) {
      return (lat: lat, lng: lng, approx: false);
    }
  }
  return parseMapsCoordinates(text);
}

/// Seperti [parseMapsCoordinates], tetapi mengikuti link pendek Google.
Future<MapsCoordinate> resolveMapsLink(
  String input, {
  double? refLat,
  double? refLng,
}) async {
  final raw = input.trim();
  final direct = parseMapsCoordinates(raw, refLat: refLat, refLng: refLng);
  if (direct != null) return direct;

  final parsed = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
  if (parsed == null || !parsed.hasAuthority || !_isGoogleHost(parsed.host)) {
    throw const MapsLinkException(
      'Link tidak dikenali. Gunakan link dari Google Maps.',
    );
  }

  var current = parsed.scheme == 'https'
      ? parsed
      : parsed.replace(scheme: 'https');
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
  try {
    for (var hop = 0; hop < 6; hop++) {
      final req = await client
          .getUrl(current)
          .timeout(const Duration(seconds: 10));
      req.followRedirects = false;
      req.headers.set(HttpHeaders.userAgentHeader, _userAgent);
      final res = await req.close().timeout(const Duration(seconds: 10));
      final loc = res.headers.value(HttpHeaders.locationHeader);
      if (!_redirectCodes.contains(res.statusCode) || loc == null) {
        final body = await res
            .transform(const Utf8Decoder(allowMalformed: true))
            .join()
            .timeout(const Duration(seconds: 10));
        final found = parseMapsCoordinatesFromPage(body);
        if (found != null) return found;
        break;
      }
      await res.drain<void>();

      var next = current.resolve(loc);
      // Halaman persetujuan Google: tujuan asli ada di parameter "continue".
      final cont = next.queryParameters['continue'];
      if (next.host.startsWith('consent.') && cont != null) {
        next = Uri.tryParse(cont) ?? next;
      }
      if (!_isGoogleHost(next.host)) break;

      final found = parseMapsCoordinates(next.toString());
      if (found != null) return found;
      current = next;
    }
  } on MapsLinkException {
    rethrow;
  } on TimeoutException {
    throw const MapsLinkException('Waktu habis saat membuka link. Coba lagi.');
  } on IOException {
    throw const MapsLinkException(
      'Tidak dapat membuka link. Periksa koneksi internet.',
    );
  } finally {
    client.close(force: true);
  }

  throw const MapsLinkException(
    'Link tempat di Google Maps tidak memuat koordinat. Salin Plus Code '
    '(mis. 69CR+F6C) atau koordinat dari halaman tempat, atau ketuk '
    'langsung di peta.',
  );
}
