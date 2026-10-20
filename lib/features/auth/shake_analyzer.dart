import 'dart:math';

class ShakeSample {
  const ShakeSample(this.tMs, this.magnitude);
  final int tMs;
  final double magnitude;
}

enum ShakeVerdict { human, tooFew, tooShort, tooRegular }

class ShakeAnalyzer {
  /// Ambang puncak (m/s^2, tanpa gravitasi). Turunkan jika terlalu sulit.
  static const peakThreshold = 8.0;
  static const minPeakGapMs = 120;
  static const targetPeaks = 6;
  static const minPeaks = 5;
  static const minSpanMs = 800;

  /// Penolakan hanya jika interval DAN kekuatan sama-sama nyaris konstan.
  static const minIntervalCv = 0.10;
  static const minAmplitudeCv = 0.08;

  static List<ShakeSample> findPeaks(List<ShakeSample> s) {
    final peaks = <ShakeSample>[];
    for (var i = 1; i < s.length - 1; i++) {
      final c = s[i];
      if (c.magnitude < peakThreshold) continue;
      if (c.magnitude < s[i - 1].magnitude ||
          c.magnitude <= s[i + 1].magnitude) {
        continue;
      }
      if (peaks.isNotEmpty && c.tMs - peaks.last.tMs < minPeakGapMs) {
        if (c.magnitude > peaks.last.magnitude) peaks[peaks.length - 1] = c;
        continue;
      }
      peaks.add(c);
    }
    return peaks;
  }

  static int countPeaks(List<ShakeSample> s) => findPeaks(s).length;

  /// Koefisien variasi = simpangan baku / rata-rata.
  static double cv(List<double> v) {
    if (v.length < 2) return 0;
    final mean = v.reduce((a, b) => a + b) / v.length;
    if (mean == 0) return 0;
    final variance =
        v.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
        v.length;
    return sqrt(variance) / mean;
  }

  static ShakeVerdict analyze(List<ShakeSample> samples) {
    final peaks = findPeaks(samples);
    if (peaks.length < minPeaks) return ShakeVerdict.tooFew;
    if (peaks.last.tMs - peaks.first.tMs < minSpanMs) {
      return ShakeVerdict.tooShort;
    }
    final intervals = <double>[
      for (var i = 1; i < peaks.length; i++)
        (peaks[i].tMs - peaks[i - 1].tMs).toDouble(),
    ];
    final amplitudes = peaks.map((p) => p.magnitude).toList();
    if (cv(intervals) < minIntervalCv && cv(amplitudes) < minAmplitudeCv) {
      return ShakeVerdict.tooRegular;
    }
    return ShakeVerdict.human;
  }
}
