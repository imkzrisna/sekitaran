import 'package:flutter/material.dart';
import 'package:sekitaran/features/wordle/vo/char_result.dart';
import 'package:sekitaran/features/wordle/vo/green_char.dart';
import 'package:sekitaran/features/wordle/vo/grey_char.dart';
import 'package:sekitaran/features/wordle/vo/yellow_char.dart';

import 'green_box.dart';
import 'grey_box.dart';
import 'yellow_box.dart';

class GuessRow extends StatelessWidget {
  const GuessRow({super.key, required this.results});

  final List<CharResult> results;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: results.map((result) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: _buildBox(result),
        );
      }).toList(),
    );
  }

  Widget _buildBox(CharResult result) {
    switch (result.runtimeType) {
      case GreenChar:
        return GreenBox(char: result.char);
      case YellowChar:
        return YellowBox(char: result.char);
      case GreyChar:
        return GreyBox(char: result.char);
      default:
        return GreyBox(char: result.char);
    }
  }
}
