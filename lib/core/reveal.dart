import 'dart:async';

import 'package:flutter/material.dart';

/// Memunculkan [child] dengan fade dan geser naik tipis.
/// Beri [index] berurutan (0, 1, 2, ...) agar bagian-bagian halaman muncul bergantian.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 70),
    this.duration = const Duration(milliseconds: 350),
    this.offset = 0.06,
  });

  final Widget child;
  final int index;
  final Duration step;
  final Duration duration;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> {
  bool _show = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(widget.step * widget.index, () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hormati pengaturan aksesibilitas "kurangi gerakan"
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: widget.duration,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : Offset(0, widget.offset),
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
