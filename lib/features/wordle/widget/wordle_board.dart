import 'package:flutter/material.dart';
import 'package:sekitaran/features/wordle/vo/char_result.dart';

import 'empty_box.dart';
import 'guess_row.dart';

class WordleBoard extends StatelessWidget {
  const WordleBoard({
    super.key,
    required this.history,
    this.currentGuess = '',
    this.maxGuesses = 6,
    this.wordLength = 5,
  });

  static const _gap = 6.0;

  final List<List<CharResult>> history;

  /// Huruf yang sedang diketik, tampil di baris aktif.
  final String currentGuess;
  final int maxGuesses;
  final int wordLength;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth.isFinite ? c.maxWidth : 360.0;
        final size = ((width - _gap * (wordLength - 1)) / wordLength).clamp(
          40.0,
          56.0,
        );
        return SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < maxGuesses; i++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == maxGuesses - 1 ? 0 : _gap,
                  ),
                  child: i < history.length
                      ? GuessRow(results: history[i], size: size, gap: _gap)
                      : _emptyRow(
                          size,
                          i == history.length ? currentGuess : '',
                        ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyRow(double size, String typed) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < wordLength; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          EmptyBox(size: size, char: i < typed.length ? typed[i] : ''),
        ],
      ],
    );
  }
}
