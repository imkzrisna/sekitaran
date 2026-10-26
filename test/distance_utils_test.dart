import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/location/distance_utils.dart';
import 'package:sekitaran/features/location/routing_service.dart';

void main() {
  test('titik sama = 0', () {
    expect(haversineMeters(-7.7956, 110.3695, -7.7956, 110.3695), 0);
  });
  test('1 derajat lintang ~111 km', () {
    expect(haversineMeters(10, 100, 11, 100), closeTo(111195, 300));
  });
  test('Monas ke Bundaran HI ~2,2 km', () {
    final d = haversineMeters(-6.1754, 106.8272, -6.1949, 106.8230);
    expect(d, inInclusiveRange(2100, 2350));
  });
  test('validasi koordinat', () {
    expect(isValidCoord(null, 110), isFalse);
    expect(isValidCoord(91, 110), isFalse);
    expect(isValidCoord(0, 0), isFalse);
    expect(isValidCoord(-7.79, 110.36), isTrue);
  });
  test('format jarak', () {
    expect(formatDistance(450), '450 m');
    expect(formatDistance(1234), '1,2 km');
    expect(formatDistance(999.6), '1,0 km');
  });
  test('parse respons OSRM', () {
    const body =
        '{"code":"Ok","routes":[{"distance":650.5,"duration":480,"geometry":{"coordinates":[[110.1,-7.1],[110.2,-7.2]]}}]}';
    final r = RoutingService.parse(body);
    expect(r.meters, 650.5);
    expect(r.points.length, 2);
    expect(r.points.first.latitude, -7.1);
  });
  test('respons gagal memunculkan RouteException', () {
    expect(
      () => RoutingService.parse('{"code":"NoRoute","routes":[]}'),
      throwsA(isA<RouteException>()),
    );
  });
}
