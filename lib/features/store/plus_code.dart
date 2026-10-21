import 'dart:math' as math;

const _alphabet = '23456789CFGHJMPQRVWX';

/// Plus Code di awal teks, mis. "69CR+F6C Caturtunggal, Sleman" atau "6P4G69CR+C6V".
final _plusCodeRe = RegExp(
  r'^\s*([23456789CFGHJMPQRVWX]{4,8}\+[23456789CFGHJMPQRVWX]{2,7})(?:\s+.*)?$',
  caseSensitive: false,
);

bool looksLikePlusCode(String input) => _plusCodeRe.hasMatch(input);

/// Kode pendek (4 karakter sebelum '+') butuh titik acuan [refLat]/[refLng]
/// yang jaraknya kurang dari ~55 km. Mengembalikan null jika tidak valid.
({double lat, double lng})? decodePlusCode(
  String input, {
  double? refLat,
  double? refLng,
}) {
  final m = _plusCodeRe.firstMatch(input);
  if (m == null) return null;
  final code = m.group(1)!.toUpperCase();
  final plus = code.indexOf('+');
  if (plus != 4 && plus != 8) return null;

  var digits = code.replaceAll('+', '');
  final isShort = plus == 4;
  if (isShort) {
    if (refLat == null || refLng == null) return null;
    final la = math.min(math.max(refLat, -90.0), 90.0) + 90;
    final ln = math.min(math.max(refLng, -180.0), 179.999999) + 180;
    final a0 = math.min((la / 20).floor(), 8);
    final c0 = (ln / 20).floor();
    final a1 = math.min((la - a0 * 20).floor(), 19);
    final c1 = math.min((ln - c0 * 20).floor(), 19);
    digits =
        _alphabet[a0] + _alphabet[c0] + _alphabet[a1] + _alphabet[c1] + digits;
  }
  if (digits.length < 10) return null;

  int idx(String ch) => _alphabet.indexOf(ch);
  const res = [20.0, 1.0, 0.05, 0.0025, 0.000125];
  var lat = 0.0;
  var lng = 0.0;
  for (var i = 0; i < 5; i++) {
    lat += idx(digits[i * 2]) * res[i];
    lng += idx(digits[i * 2 + 1]) * res[i];
  }
  var latSize = 0.000125;
  var lngSize = 0.000125;
  for (var i = 10; i < digits.length; i++) {
    latSize /= 5;
    lngSize /= 4;
    final v = idx(digits[i]);
    lat += (v ~/ 4) * latSize;
    lng += (v % 4) * lngSize;
  }
  var latC = lat - 90 + latSize / 2;
  var lngC = lng - 180 + lngSize / 2;

  if (isShort) {
    const resolution =
        1.0; // 4 karakter depan dibuang => area berulang 1 derajat
    final dLat = latC - refLat!;
    if (dLat > resolution / 2 && latC - resolution >= -90) {
      latC -= resolution;
    } else if (dLat < -resolution / 2 && latC + resolution <= 90) {
      latC += resolution;
    }
    final dLng = lngC - refLng!;
    if (dLng > resolution / 2) {
      lngC -= resolution;
    } else if (dLng < -resolution / 2) {
      lngC += resolution;
    }
  }
  return (lat: latC, lng: lngC);
}
