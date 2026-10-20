import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/shake_analyzer.dart';

List<ShakeSample> _build(List<int> peakTimes, List<double> amps) {
  final end = peakTimes.last + 200;
  return [
    for (var t = 0; t <= end; t += 20)
      ShakeSample(
        t,
        [
          for (var i = 0; i < peakTimes.length; i++)
            max(0.0, amps[i] * (1 - (t - peakTimes[i]).abs() / 60)),
        ].reduce(max),
      ),
  ];
}

void main() {
  test('goyangan tidak beraturan dianggap manusia', () {
    final rnd = Random(1);
    var t = 200;
    final times = <int>[];
    final amps = <double>[];
    for (var i = 0; i < 8; i++) {
      times.add(t);
      amps.add(11 + rnd.nextDouble() * 11);
      t += 200 + (rnd.nextInt(12) * 20);
    }
    expect(ShakeAnalyzer.analyze(_build(times, amps)), ShakeVerdict.human);
  });

  test('goyangan konstan sempurna ditolak', () {
    final times = [for (var i = 0; i < 8; i++) 200 + i * 300];
    final amps = List.filled(8, 15.0);
    expect(ShakeAnalyzer.analyze(_build(times, amps)), ShakeVerdict.tooRegular);
  });

  test('tanpa gerakan ditolak', () {
    final s = [for (var t = 0; t < 3000; t += 20) ShakeSample(t, 0.1)];
    expect(ShakeAnalyzer.analyze(s), ShakeVerdict.tooFew);
  });
}
