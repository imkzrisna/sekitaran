import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BusinessHomePage extends StatefulWidget {
  const BusinessHomePage({super.key});

  @override
  State<BusinessHomePage> createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);

  // Ukuran tombol & menu melingkar
  static const _fabSize = 58.0;
  static const _fabRight = 20.0;
  static const _fabBottom = 40.0;
  static const _ringOuter = 143.0;
  static const _ringInner = 90.0;

  // TODO: ganti dengan data dari backend
  final String _storeName = 'Nama Toko';
  final int _listedItems = 0;
  final int _customerComments = 0;

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

  // ---------- Bagian konten ----------

  Widget _underlined(String text, {double size = 16}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: _label,
        ),
      ),
    );
  }

  Widget _title() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'Welcome to Sekitaran',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: _green,
          ),
        ),
        Positioned(
          top: -14,
          right: -22,
          child: Text(
            '*',
            style: GoogleFonts.poppins(
              fontSize: 44,
              fontWeight: FontWeight.w500,
              color: _green,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _subtitle() {
    final base = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _label,
      height: 1.5,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Hey, '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: const EdgeInsets.only(bottom: 2),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
              ),
              child: Text('Store Owner!', style: base.copyWith(height: 1.2)),
            ),
          ),
          const TextSpan(text: ' Ready to manage your business?'),
        ],
      ),
    );
  }

  Widget _myBusinessRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _underlined('My Business'),
            const SizedBox(width: 6),
            const Icon(Icons.storefront_outlined, color: _green, size: 22),
          ],
        ),
        Flexible(
          child: GestureDetector(
            onTap: () {
              // TODO: ganti toko yang dipilih
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '\u201C$_storeName\u201D',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.sync, color: _green, size: 22),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required IconData icon,
    required String title,
    required int value,
    required String caption,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _green, size: 24),
        const SizedBox(height: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _label,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            '$value',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: _green,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(caption, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
      ],
    );
  }

  Widget _storeOverview() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _stat(
              icon: Icons.view_in_ar_outlined,
              title: 'Listed Items',
              value: _listedItems,
              caption: 'Products and services',
            ),
          ),
          Container(
            width: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: _green,
          ),
          Expanded(
            child: _stat(
              icon: Icons.chat_bubble_outline,
              title: 'Customer Comments',
              value: _customerComments,
              caption: 'For selected store',
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentCommentsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _underlined('Recent Comments'),
            const SizedBox(width: 6),
            const Icon(
              Icons.mark_chat_unread_outlined,
              color: _green,
              size: 22,
            ),
          ],
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // TODO: tandai semua komentar sebagai sudah dibaca
          },
          child: Row(
            children: [
              Text(
                'Mark as read',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _label,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.mark_chat_read_outlined,
                color: _green,
                size: 22,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _content() {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 64, 28, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _title(),
                const SizedBox(height: 16),
                _subtitle(),
                const SizedBox(height: 22),
                _myBusinessRow(),
                const SizedBox(height: 22),
                _underlined('Store Overview'),
                const SizedBox(height: 14),
                _storeOverview(),
                const SizedBox(height: 24),
                _recentCommentsRow(),
                // TODO: daftar komentar terbaru
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Menu melingkar ----------

  Widget _radialMenu() {
    // sudut (derajat) tiap ikon, dari bawah ke atas
    final items =
        <({IconData icon, String tooltip, double angle, VoidCallback onTap})>[
          (
            icon: Icons.person_outline,
            tooltip: 'Profile',
            angle: 199,
            onTap: () {
              /* TODO: halaman profil */
            },
          ),
          (
            icon: Icons.home_outlined,
            tooltip: 'Home',
            angle: 163,
            onTap: () {
              /* sudah di Home */
            },
          ),
          (
            icon: Icons.add_circle_outline,
            tooltip: 'Add item',
            angle: 126,
            onTap: () {
              /* TODO: tambah produk/jasa */
            },
          ),
          (
            icon: Icons.edit_outlined,
            tooltip: 'Edit',
            angle: 90,
            onTap: () {
              /* TODO: edit bisnis */
            },
          ),
        ];

    const r = (_ringOuter + _ringInner) / 2;

    return ScaleTransition(
      scale: _anim,
      child: SizedBox(
        width: _ringOuter * 2,
        height: _ringOuter * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
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
                left: _ringOuter + r * math.cos(it.angle * math.pi / 180) - 24,
                top: _ringOuter - r * math.sin(it.angle * math.pi / 180) - 24,
                width: 48,
                height: 48,
                child: Tooltip(
                  message: it.tooltip,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      it.onTap();
                      _toggle();
                    },
                    child: Icon(it.icon, color: Colors.white, size: 28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _bg,
      body: LayoutBuilder(
        builder: (context, c) {
          final cx = c.maxWidth - _fabRight - _fabSize / 2;
          final cy = c.maxHeight - _fabBottom - bottomInset - _fabSize / 2;

          return Stack(
            children: [
              _content(),

              // Area luar menu: ketuk untuk menutup
              if (_open)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggle,
                  ),
                ),

              // Busur menu
              Positioned(
                left: cx - _ringOuter,
                top: cy - _ringOuter,
                child: IgnorePointer(ignoring: !_open, child: _radialMenu()),
              ),

              // Tombol utama
              Positioned(
                right: _fabRight,
                bottom: _fabBottom + bottomInset,
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
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
