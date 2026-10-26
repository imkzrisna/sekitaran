import 'package:flutter/material.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart';

class GreyBox extends StatelessWidget {
  const GreyBox({
    super.key,
    required this.char,
    this.size = 60,
    this.delayMs = 0,
  });

  final String char;
  final double size;
  final int delayMs;

  @override
  Widget build(BuildContext context) => LetterTile(
    state: TileState.absent,
    char: char,
    size: size,
    delayMs: delayMs,
  );
}
