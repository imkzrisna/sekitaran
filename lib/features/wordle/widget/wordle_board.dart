import 'package:flutter/material.dart';
import 'package:sekitaran/features/wordle/vo/char_result.dart';

import 'empty_box.dart';
import 'guess_row.dart';

class WordleBoard extends StatelessWidget {
  const WordleBoard({
    super.key,
    required this.history,
    this.maxGuesses = 6,
    this.wordLength = 5,
  });

  final List<List<CharResult>> history;
  final int maxGuesses;
  final int wordLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(maxGuesses, (index) {
        if (index < history.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GuessRow(results: history[index]),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _emptyRow(),
        );
      }),
    );
  }

  Widget _emptyRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(wordLength, (index) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 3),
          child: EmptyBox(),
        );
      }),
    );
  }
}
