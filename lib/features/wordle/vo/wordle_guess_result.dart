import '../wordle_status.dart';
import 'char_result.dart';

class WordleGuessResult {
  final WordleStatus status;
  final List<CharResult> result;
  final List<List<CharResult>> history;

  WordleGuessResult(this.status, this.result, {this.history = const []});
}