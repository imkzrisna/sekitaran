import 'package:flutter/material.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart';

/// Kotak kosong, atau kotak berisi huruf yang sedang diketik.
class EmptyBox extends StatelessWidget {
  const EmptyBox({super.key, this.size = 60, this.char = ''});

  final double size;
  final String char;

  @override
  Widget build(BuildContext context) =>
      LetterTile(state: TileState.empty, char: char, size: size);
}
