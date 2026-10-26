import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palet Wordle. Ubah warna di sini untuk seluruh game.
class WordleColors {
  const WordleColors._();
  static const correct = Color(0xFF103D17);
  static const present = Color(0xFFC99A4A);
  static const absent = Color(0xFF7A7A7A);
  static const tileBorder = Color(0xFFC9C9C9);
  static const tileFill = Color(0xFFFFFFFF);
  static const ink = Color(0xFF252525);
  static const accent = Color(0xFF5BAA5F);
  static const bg = Color(0xFFF2F9F8);
  static const grey = Color(0xFF7A7A7A);
  static const danger = Color(0xFFC62828);
}

enum TileState { empty, correct, present, absent }

/// Satu kotak huruf. Kotak berwarna membalik (flip) saat pertama muncul.
class LetterTile extends StatefulWidget {
  const LetterTile({
    super.key,
    required this.state,
    this.char = '',
    this.size = 60,
    this.delayMs = 0,
  });

  final TileState state;
  final String char;
  final double size;
  final int delayMs;

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile>
    with SingleTickerProviderStateMixin {
  static const _flipMs = 450;

  late final AnimationController _c;
  late final Animation<double> _t;

  bool get _animated => widget.state != TileState.empty;

  @override
  void initState() {
    super.initState();
    final total = widget.delayMs + _flipMs;
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: total),
    );
    _t = CurvedAnimation(
      parent: _c,
      curve: Interval(widget.delayMs / total, 1, curve: Curves.easeInOut),
    );
    if (_animated) _c.forward();
  }

  @override
  void didUpdateWidget(covariant LetterTile old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      if (_animated) {
        _c.forward(from: 0);
      } else {
        _c.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _face(TileState s) {
    final (fill, border, text) = switch (s) {
      TileState.correct => (
        WordleColors.correct,
        WordleColors.correct,
        Colors.white,
      ),
      TileState.present => (
        WordleColors.present,
        WordleColors.present,
        Colors.white,
      ),
      TileState.absent => (
        WordleColors.absent,
        WordleColors.absent,
        Colors.white,
      ),
      TileState.empty => (
        WordleColors.tileFill,
        WordleColors.tileBorder,
        WordleColors.ink,
      ),
    };
    return Container(
      width: widget.size,
      height: widget.size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(
          color: (s == TileState.empty && widget.char.isNotEmpty)
              ? WordleColors.grey
              : border,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        widget.char.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: widget.size * 0.45,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_animated) return _face(TileState.empty);
    return AnimatedBuilder(
      animation: _t,
      builder: (_, _) {
        final angle = _t.value * math.pi;
        final front = angle < math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.002)
            ..rotateX(angle),
          child: front
              ? _face(TileState.empty)
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationX(math.pi),
                  child: _face(widget.state),
                ),
        );
      },
    );
  }
}
