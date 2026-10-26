import 'package:flutter/material.dart';
import 'package:sekitaran/features/wordle/vo/char_result.dart';
import 'package:sekitaran/features/wordle/vo/green_char.dart';
import 'package:sekitaran/features/wordle/vo/yellow_char.dart';

import 'green_box.dart';
import 'grey_box.dart';
import 'yellow_box.dart';

class GuessRow extends StatelessWidget {
  const GuessRow({
    super.key,
    required this.results,
    this.size = 60,
    this.gap = 6,
  });

  final List<CharResult> results;
  final double size;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < results.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          _buildBox(results[i], i),
        ],
      ],
    );
  }

  Widget _buildBox(CharResult r, int index) {
    final delay = index * 220; // kotak membalik berurutan
    if (r is GreenChar) {
      return GreenBox(char: r.char, size: size, delayMs: delay);
    }
    if (r is YellowChar) {
      return YellowBox(char: r.char, size: size, delayMs: delay);
    }
    return GreyBox(char: r.char, size: size, delayMs: delay);
  }
}
