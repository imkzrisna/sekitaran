/// Pembatasan wilayah Indonesia dan zona waktu dari koordinat.
/// Perkiraan berbasis kotak koordinat, bukan batas negara yang presisi.
const kIndonesiaOnlyMessage =
    'Sekitaran is only available in Indonesia. Your location is outside Indonesia.';
const kIndonesiaOnlyMessageId =
    'Sekitaran hanya bisa digunakan di wilayah Indonesia. '
    'Lokasi ini berada di luar Indonesia.';

// (minLat, maxLat, minLng, maxLng) area negara tetangga di dalam kotak Indonesia
const _outside = <(double, double, double, double)>[
  (2.9, 7.0, 99.0, 105.0), // Semenanjung Malaysia utara dan Penang
  (1.15, 2.9, 101.9, 104.6), // Selangor sampai Johor dan Singapura
  (2.3, 7.0, 109.0, 115.0), // Sarawak
  (4.35, 7.0, 115.0, 120.0), // Sabah dan Brunei
  (4.9, 7.0, 119.0, 126.2), // Filipina selatan
  (-9.6, -8.25, 125.0, 127.4), // Timor Leste
  (-11.2, -9.5, 94.9, 115.0), // Pulau Christmas dan sekitarnya
];

bool isInIndonesiaCoord(double lat, double lng) {
  if (lat.isNaN || lng.isNaN) return false;
  if (lat < -11.2 || lat > 6.2 || lng < 94.9 || lng > 141.02) return false;
  for (final b in _outside) {
    if (lat >= b.$1 && lat <= b.$2 && lng >= b.$3 && lng <= b.$4) {
      return false;
    }
  }
  return true;
}

/// Offset jam dari UTC: 7 = WIB, 8 = WITA, 9 = WIT.
int zoneOffsetFor(double lat, double lng) {
  if (lng >= 127.0 || (lng >= 125.0 && lat < 1.0)) return 9;
  if (lng >= 114.42) return 8;
  return 7;
}
