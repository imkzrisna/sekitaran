import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart'
    show TileState, WordleColors;

class WordleKeyboard extends StatelessWidget {
  const WordleKeyboard({
    super.key,
    required this.onLetter,
    required this.onEnter,
    required this.onBackspace,
    this.keyStates = const {},
    this.enabled = true,
  });

  static const _row1 = 'QWERTYUIOP';
  static const _row2 = 'ASDFGHJKL';
  static const _row3 = 'ZXCVBNM';
  static const _idle = Color(0xFFE6ECEB);

  final void Function(String letter) onLetter;
  final VoidCallback onEnter;
  final VoidCallback onBackspace;

  /// Huruf kapital -> status terbaik huruf itu dari semua tebakan.
  final Map<String, TileState> keyStates;
  final bool enabled;

  Widget _key({
    required int flex,
    required Color fill,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: fill,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: enabled ? onTap : null,
            child: SizedBox(height: 52, child: Center(child: child)),
          ),
        ),
      ),
    );
  }

  Widget _letter(String ch) {
    final (fill, text) = switch (keyStates[ch]) {
      TileState.correct => (WordleColors.correct, Colors.white),
      TileState.present => (WordleColors.present, Colors.white),
      TileState.absent => (WordleColors.absent, Colors.white),
      _ => (_idle, WordleColors.ink),
    };
    return _key(
      flex: 2,
      fill: fill,
      onTap: () => onLetter(ch),
      child: Text(
        ch,
        style: GoogleFonts.poppins(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [for (final c in _row1.split('')) _letter(c)]),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(flex: 1),
              for (final c in _row2.split('')) _letter(c),
              const Spacer(flex: 1),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _key(
                flex: 3,
                fill: _idle,
                onTap: onEnter,
                child: Text(
                  'Enter',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: WordleColors.ink,
                  ),
                ),
              ),
              for (final c in _row3.split('')) _letter(c),
              _key(
                flex: 3,
                fill: _idle,
                onTap: onBackspace,
                child: const Icon(
                  Icons.backspace_outlined,
                  size: 22,
                  color: WordleColors.ink,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
