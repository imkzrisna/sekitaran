import 'wordle_status.dart';
import 'vo/wordle_guess_result.dart';
import 'vo/char_result.dart';
import 'vo/green_char.dart';
import 'vo/yellow_char.dart';
import 'vo/grey_char.dart';

class WordleInstance {
  String _correctWord = '';
  int _guessCount = 0;
  final List<List<CharResult>> _history = [];

  String get correctWord => _correctWord;

  WordleInstance setCorrectWord(String word) {
    _correctWord = word;
    _guessCount = 0;
    _history.clear();
    return this;
  }

  bool charracterIsInCorrectPosition(
    int i,
    List<String> correctChars,
    List<String> guessChars,
  ) {
    return i < correctChars.length && guessChars[i] == correctChars[i];
  }

  void reset(String word) {
    _guessCount = 0;
    _history.clear();
    _correctWord = word;
  }

  WordleGuessResult guess(String word) {
    _guessCount++;
    if (word != _correctWord) {
      final List<CharResult> charResults = [];
      final correctChars = _correctWord.split('');
      final guessChars = word.split('');

      for (int i = 0; i < guessChars.length; i++) {
        if (charracterIsInCorrectPosition(i, correctChars, guessChars)) {
          charResults.add(GreenChar(guessChars[i]));
        } else if (correctChars.contains(guessChars[i])) {
          charResults.add(YellowChar(guessChars[i]));
        } else {
          charResults.add(GreyChar(guessChars[i]));
        }
      }

      _history.add(charResults);

      if (_guessCount >= 6) {
        return WordleGuessResult(
          WordleStatus.outOfTries,
          [],
          history: List.from(_history),
        );
      }

      return WordleGuessResult(
        WordleStatus.incorrect,
        charResults,
        history: List.from(_history),
      );
    }
    final charResults = _correctWord
        .split('')
        .map((c) => GreenChar(c))
        .toList();
    _history.add(charResults);
    return WordleGuessResult(
      WordleStatus.correct,
      charResults,
      history: List.from(_history),
    );
  }
}

