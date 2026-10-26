import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/core/indonesia_geo.dart';

void main() {
  test('kota di Indonesia diterima', () {
    expect(isInIndonesiaCoord(-6.2088, 106.8456), isTrue); // Jakarta
    expect(isInIndonesiaCoord(3.5952, 98.6722), isTrue); // Medan
    expect(isInIndonesiaCoord(-10.1772, 123.607), isTrue); // Kupang
    expect(isInIndonesiaCoord(1.1300, 104.0300), isTrue); // Batam
    expect(isInIndonesiaCoord(-2.53, 140.7), isTrue); // Jayapura
  });
  test('lokasi luar Indonesia ditolak', () {
    expect(isInIndonesiaCoord(1.3521, 103.8198), isFalse); // Singapura
    expect(isInIndonesiaCoord(3.139, 101.6869), isFalse); // Kuala Lumpur
    expect(isInIndonesiaCoord(5.4, 100.33), isFalse); // Penang
    expect(isInIndonesiaCoord(1.4927, 103.7414), isFalse); // Johor Bahru
    expect(isInIndonesiaCoord(5.98, 116.07), isFalse); // Kota Kinabalu
    expect(isInIndonesiaCoord(-8.5569, 125.5603), isFalse); // Dili
    expect(isInIndonesiaCoord(-9.44, 147.18), isFalse); // Port Moresby
    expect(isInIndonesiaCoord(-33.87, 151.21), isFalse); // Sydney
    expect(isInIndonesiaCoord(35.68, 139.69), isFalse); // Tokyo
  });
  test('zona waktu', () {
    expect(zoneOffsetFor(-6.2088, 106.8456), 7); // Jakarta
    expect(zoneOffsetFor(-8.2192, 114.3691), 7); // Banyuwangi
    expect(zoneOffsetFor(-8.65, 115.2167), 8); // Denpasar
    expect(zoneOffsetFor(-5.147, 119.43), 8); // Makassar
    expect(zoneOffsetFor(1.4748, 124.8421), 8); // Manado
    expect(zoneOffsetFor(-3.7, 128.17), 9); // Ambon
    expect(zoneOffsetFor(-2.53, 140.7), 9); // Jayapura
  });
}
