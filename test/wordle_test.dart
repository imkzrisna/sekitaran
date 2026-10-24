import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/wordle/wordle_instance.dart';
import 'package:sekitaran/features/wordle/wordle_status.dart';
import 'package:sekitaran/features/wordle/vo/green_char.dart';
import 'package:sekitaran/features/wordle/vo/yellow_char.dart';
import 'package:sekitaran/features/wordle/vo/grey_char.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test("when guess is incorrect, should be in incorrect state", () {
    final wordleInstance = WordleInstance().setCorrectWord("there");

    final result = wordleInstance.guess("hello");

    expect(result.status, WordleStatus.incorrect);
  });

  test("when a character is correct but in the wrong spot, should mark it as green", () async {
    final wordleInstance = WordleInstance().setCorrectWord("ftomm");

    final result = wordleInstance.guess("fotmm");

    final expectedResult = [
      GreenChar('f'),
      YellowChar('o'),
      YellowChar('t'),
      GreenChar('m'),
      GreenChar('m'),
    ];

    expect(result.result, expectedResult);
  });

  test("when a character is incorrect regardless the placement, should mark it as grey", () async {
    final wordleInstance = WordleInstance().setCorrectWord("ftomm");

    final result = wordleInstance.guess("fromm");

    final expectedResult = [
      GreenChar('f'),
      GreyChar('r'),
      GreenChar('o'),
      GreenChar('m'),
      GreenChar('m'),
    ];

    expect(result.result, expectedResult);
  });

  test("when failing to guess more than six times, should be in out of tries status", () async {
    final wordleInstance = WordleInstance().setCorrectWord("ftomm");

    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");

    final result = wordleInstance.guess("fromm");

    expect(result.status, WordleStatus.outOfTries);
  });

  test("when failing to guess more than six times, the seventh tries should not add up in the guess history", () async {
    final wordleInstance = WordleInstance().setCorrectWord("ftomm");

    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");
    wordleInstance.guess("fromm");

    final result = wordleInstance.guess("fromm");

    expect(result.history.length == 7, true);
  });

  test("when failing to guess and then guesses successfully, should have the provided result history", () async {
    final wordleInstance = WordleInstance().setCorrectWord("ftomm");

    wordleInstance.guess("mromf");

    final guess1 = [
      YellowChar("m"),
      GreyChar("r"),
      GreenChar("o"),
      GreenChar("m"),
      YellowChar("f"),
    ];

    wordleInstance.guess("mtomf");

    final guess2 = [
      YellowChar("m"),
      GreenChar("t"),
      GreenChar("o"),
      GreenChar("m"),
      YellowChar("f"),
    ];

    final result = wordleInstance.guess("ftomm");

    final guess3 = [
      GreenChar("f"),
      GreenChar("t"),
      GreenChar("o"),
      GreenChar("m"),
      GreenChar("m"),
    ];

    final expectedGuessHistory = [guess1, guess2, guess3];

    expect(result.history, expectedGuessHistory);
    expect(result.status, WordleStatus.correct);
  });
}
