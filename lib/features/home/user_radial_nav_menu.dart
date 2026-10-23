import 'dart:math' as math;

import 'package:flutter/material.dart';

enum UserNavItem { profile, home, explore, currency }

/// Menu melingkar untuk Regular User. Letakkan sebagai anak dari
/// Stack layar penuh (StackFit.expand) di atas konten halaman.
class UserRadialNavMenu extends StatefulWidget {
  const UserRadialNavMenu({
    super.key,
    this.current,
    this.onProfile,
    this.onHome,
    this.onExplore,
    this.onCurrency,
  });

  final UserNavItem? current;
  final VoidCallback? onProfile;
  final VoidCallback? onHome;
  final VoidCallback? onExplore;
  final VoidCallback? onCurrency;

  @override
  State<UserRadialNavMenu> createState() => _UserRadialNavMenuState();
}

class _UserRadialNavMenuState extends State<UserRadialNavMenu>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _fabSize = 70.0;
  static const _fabRight = 20.0;
  static const _fabBottom = 40.0;
  static const _ringOuter = 172.0;
  static const _ringInner = 108.0;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );
  late final Animation<double> _anim = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.easeOutCubic,
  );

  bool _open = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    _open ? _ctrl.forward() : _ctrl.reverse();
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _ctrl.reverse();
  }

  Widget _ring() {
    final items =
        <
          ({
            UserNavItem id,
            IconData icon,
            String tooltip,
            double angle,
            VoidCallback? onTap,
          })
        >[
          (
            id: UserNavItem.profile,
            icon: Icons.person_outline,
            tooltip: 'Profile',
            angle: 199,
            onTap: widget.onProfile,
          ),
          (
            id: UserNavItem.home,
            icon: Icons.home_outlined,
            tooltip: 'Home',
            angle: 163,
            onTap: widget.onHome,
          ),
          (
            id: UserNavItem.explore,
            icon: Icons.map_outlined,
            tooltip: 'Explore',
            angle: 126,
            onTap: widget.onExplore,
          ),
          (
            id: UserNavItem.currency,
            icon: Icons.currency_exchange,
            tooltip: 'Currency',
            angle: 90,
            onTap: widget.onCurrency,
          ),
        ];
    const r = (_ringOuter + _ringInner) / 2;
    const half = 28.0;

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
          for (final it in items)
            Positioned(
              left: _ringOuter + r * math.cos(it.angle * math.pi / 180) - half,
              top: _ringOuter - r * math.sin(it.angle * math.pi / 180) - half,
              width: half * 2,
              height: half * 2,
              child: Tooltip(
                message: it.tooltip,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _close();
                    it.onTap?.call();
                  },
                  child: Center(
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: it.id == widget.current
                            ? Colors.white
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        it.icon,
                        size: 30,
                        color: it.id == widget.current ? _green : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
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
            if (_open)
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggle,
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
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _open ? Icons.close : Icons.widgets_outlined,
                      key: ValueKey(_open),
                      color: Colors.white,
                      size: 36,
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
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.color != color || old.inner != inner || old.outer != outer;
}
