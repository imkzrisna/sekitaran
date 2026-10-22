import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/store/maps_link_parser.dart';

void main() {
  test('pin tempat (!3d!4d) diutamakan daripada @', () {
    final r = parseMapsCoordinates(
      'https://www.google.com/maps/place/Warung/@-7.7471,110.3552,17z/'
      'data=!3m1!4b1!4m6!3m5!1s0x0:0x0!8m2!3d-7.7470000!4d110.3550000',
    )!;
    expect(r.lat, closeTo(-7.747, 1e-6));
    expect(r.lng, closeTo(110.355, 1e-6));
    expect(r.approx, isFalse);
  });

  test('parameter q=', () {
    final r = parseMapsCoordinates(
      'https://www.google.com/maps?q=-7.759,110.408',
    )!;
    expect(r.lat, closeTo(-7.759, 1e-6));
    expect(r.lng, closeTo(110.408, 1e-6));
    expect(r.approx, isFalse);
  });

  test('hanya @ ditandai perkiraan', () {
    final r = parseMapsCoordinates(
      'https://www.google.com/maps/@-7.765,110.396,15z',
    )!;
    expect(r.lat, closeTo(-7.765, 1e-6));
    expect(r.approx, isTrue);
  });

  test('koordinat biasa', () {
    final r = parseMapsCoordinates('-7.7956, 110.3695')!;
    expect(r.lat, closeTo(-7.7956, 1e-6));
    expect(r.lng, closeTo(110.3695, 1e-6));
  });

  test('tanpa koordinat atau di luar rentang ditolak', () {
    expect(parseMapsCoordinates('https://example.com'), isNull);
    expect(
      parseMapsCoordinates('https://www.google.com/maps/@95.0,110.0,15z'),
      isNull,
    );
    expect(parseMapsCoordinates(''), isNull);
  });
}
