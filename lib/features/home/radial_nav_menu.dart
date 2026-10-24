import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Menu yang bisa ditandai sebagai halaman aktif.
/// profile & home dipakai kedua peran, add & edit khusus Business Owner,
/// chat & currency khusus Regular User.
enum RadialNavItem { profile, home, add, edit, chat, currency }

/// Satu ikon di dalam cincin.
class RadialNavEntry {
  const RadialNavEntry({
    required this.item,
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final RadialNavItem item;
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
}

/// Tombol menu melingkar di pojok kanan bawah. Letakkan sebagai anak dari
/// Stack layar penuh (StackFit.expand) di atas konten halaman.
class RadialNavMenu extends StatefulWidget {
  /// Menu Business Owner: Profile, Home, Add item, Edit.
  RadialNavMenu({
    super.key,
    VoidCallback? onProfile,
    VoidCallback? onHome,
    VoidCallback? onAddStore,
    VoidCallback? onEdit,
    this.current,
  }) : entries = [
         RadialNavEntry(
           item: RadialNavItem.profile,
           icon: Icons.person_outline,
           tooltip: 'Profile',
           onTap: onProfile,
         ),
         RadialNavEntry(
           item: RadialNavItem.home,
           icon: Icons.home_outlined,
           tooltip: 'Home',
           onTap: onHome,
         ),
         RadialNavEntry(
           item: RadialNavItem.add,
           icon: Icons.add_circle_outline,
           tooltip: 'Add item',
           onTap: onAddStore,
         ),
         RadialNavEntry(
           item: RadialNavItem.edit,
           icon: Icons.edit_outlined,
           tooltip: 'Edit',
           onTap: onEdit,
         ),
       ];

  /// Menu Regular User: Profile, Home, Explore, Currency.
  RadialNavMenu.regular({
    super.key,
    VoidCallback? onProfile,
    VoidCallback? onHome,
    VoidCallback? onChat,
    VoidCallback? onCurrency,
    this.current,
  }) : entries = [
         RadialNavEntry(
           item: RadialNavItem.profile,
           icon: Icons.person_outline,
           tooltip: 'Profile',
           onTap: onProfile,
         ),
         RadialNavEntry(
           item: RadialNavItem.home,
           icon: Icons.home_outlined,
           tooltip: 'Home',
           onTap: onHome,
         ),
         RadialNavEntry(
           item: RadialNavItem.chat,
           icon: Icons.forum_outlined,
           tooltip: 'Global Chat',
           onTap: onChat,
         ),
         RadialNavEntry(
           item: RadialNavItem.currency,
           icon: Icons.currency_exchange,
           tooltip: 'Currency',
           onTap: onCurrency,
         ),
       ];

  /// Isi cincin, urut dari bawah ke atas (harus 4 item).
  final List<RadialNavEntry> entries;

  /// Menu yang sedang aktif (diberi lingkaran putih). null = tidak ada.
  final RadialNavItem? current;

  @override
  State<RadialNavMenu> createState() => _RadialNavMenuState();
}

class _RadialNavMenuState extends State<RadialNavMenu>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _fabSize = 58.0;
  static const _fabRight = 20.0;
  static const _fabBottom = 40.0;
  static const _ringOuter = 143.0;
  static const _ringInner = 90.0;

  // Sudut (derajat) tiap ikon, dari bawah ke atas.
  static const _angles = <double>[199, 163, 126, 90];

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  // Ikon muncul bergantian dari bawah ke atas dengan sedikit efek memantul.
  late final List<Animation<double>> _iconAnims = List.generate(
    _angles.length,
    (i) => CurvedAnimation(
      parent: _ctrl,
      curve: Interval(0.2 + i * 0.12, 1.0, curve: Curves.easeOutBack),
    ),
  );

  bool _open = false;

  @override
  void initState() {
    super.initState();
    assert(widget.entries.length == _angles.length);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _ctrl.reverse();
  }

  Widget _ring() {
    final items = widget.entries;
    const r = (_ringOuter + _ringInner) / 2;

    return SizedBox(
      width: _ringOuter * 2,
      height: _ringOuter * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _RingPainter(
                  color: _green,
                  inner: _ringInner,
                  outer: _ringOuter,
                ),
              ),
            ),
          ),
          for (var i = 0; i < items.length && i < _angles.length; i++)
            Positioned(
              left: _ringOuter + r * math.cos(_angles[i] * math.pi / 180) - 24,
              top: _ringOuter - r * math.sin(_angles[i] * math.pi / 180) - 24,
              width: 48,
              height: 48,
              child: ScaleTransition(
                scale: _iconAnims[i],
                child: _ringIcon(items[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ringIcon(RadialNavEntry it) {
    final active = widget.current == it.item;
    final disabled = it.onTap == null && !active;
    return Tooltip(
      message: it.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          _close();
          it.onTap?.call();
        },
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: active
                  ? const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : const [],
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: disabled ? 0.45 : 1,
              child: Icon(
                it.icon,
                color: active ? _green : Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Sembunyikan saat keyboard terbuka agar tidak menutupi isian.
    if (mq.viewInsets.bottom > 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, c) {
        final cx = c.maxWidth - _fabRight - _fabSize / 2;
        final cy = c.maxHeight - _fabBottom - mq.padding.bottom - _fabSize / 2;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Latar redup: memudar masuk/keluar, ketuk untuk menutup.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_open,
                child: FadeTransition(
                  opacity: _anim,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                    child: const ColoredBox(color: Color(0x33000000)),
                  ),
                ),
              ),
            ),
            Positioned(
              left: cx - _ringOuter,
              top: cy - _ringOuter,
              child: IgnorePointer(
                ignoring: !_open,
                child: ScaleTransition(scale: _anim, child: _ring()),
              ),
            ),
            Positioned(
              right: _fabRight,
              bottom: _fabBottom + mq.padding.bottom,
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  width: _fabSize,
                  height: _fabSize,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 14,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => RotationTransition(
                      turns: Tween<double>(begin: 0.75, end: 1).animate(anim),
                      child: FadeTransition(opacity: anim, child: child),
                    ),
                    child: Icon(
                      _open ? Icons.close : Icons.widgets_outlined,
                      key: ValueKey(_open),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.inner,
    required this.outer,
  });

  final Color color;
  final double inner;
  final double outer;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addOval(Rect.fromCircle(center: c, radius: outer))
      ..addOval(Rect.fromCircle(center: c, radius: inner));

    // Bayangan lembut agar cincin terangkat dari konten di belakangnya.
    canvas.drawShadow(path, Colors.black, 10, true);
    canvas.drawPath(path, Paint()..color = color);

    // Garis tepi tipis sebagai highlight.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(c, outer - 0.5, edge);
    canvas.drawCircle(c, inner + 0.5, edge);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color || old.inner != inner || old.outer != outer;
}
