import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/store/plus_code.dart';

void main() {
  test('kode pendek + acuan Yogyakarta (data dari screenshot Google Maps)', () {
    final r = decodePlusCode(
      '69CR+C6V Caturtunggal, Sleman Regency',
      refLat: -7.7956,
      refLng: 110.3695,
    )!;
    expect(r.lat, closeTo(-7.778878, 1e-4));
    expect(r.lng, closeTo(110.390544, 1e-4));
  });

  test('kode lengkap tanpa acuan', () {
    final r = decodePlusCode('6P4G69CR+C6V')!;
    expect(r.lat, closeTo(-7.778878, 1e-4));
    expect(r.lng, closeTo(110.390544, 1e-4));
  });

  test('kode pendek tanpa acuan ditolak', () {
    expect(decodePlusCode('69CR+C6V'), isNull);
  });

  test('bukan plus code', () {
    expect(decodePlusCode('-7.7956, 110.3695'), isNull);
    expect(decodePlusCode('https://maps.app.goo.gl/abc'), isNull);
    expect(looksLikePlusCode('Hou+Ji+Tea'), isFalse);
  });
}
