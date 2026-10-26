import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/wordle/wordle_words.dart';

void main() {
  test('semua kata tepat 5 huruf kecil', () {
    for (final w in kWordleHints.keys) {
      expect(RegExp(r'^[a-z]{5}$').hasMatch(w), isTrue, reason: 'kata: $w');
    }
  });

  test('petunjuk terisi dan tidak memuat katanya sendiri', () {
    kWordleHints.forEach((word, hint) {
      expect(hint.trim(), isNotEmpty, reason: 'petunjuk kosong: $word');
      expect(
        hint.toLowerCase().contains(word),
        isFalse,
        reason: 'petunjuk membocorkan: $word',
      );
    });
  });
}
