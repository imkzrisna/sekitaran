import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/wordle_page.dart';

/// Warna bagian Games. Ubah di sini.
class GameColors {
  const GameColors._();
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFE1E7E6);
  static const iconBackground = Color(0xFFEFF3F2);
  static const tileIdle = Color(0xFFB8BFBE);
  static const tileActive = Color(0xFF103D17);
  static const title = Color(0xFF252525);
  static const subtitle = Color(0xFF7A7A7A);
  static const arrow = Color(0xFF7A7A7A);
}

/// Ikon 2x2: satu kotak hijau tua berpindah searah jarum jam.
class AnimatedBlocksIcon extends StatefulWidget {
  const AnimatedBlocksIcon({super.key, this.size = 52});

  final double size;

  @override
  State<AnimatedBlocksIcon> createState() => _AnimatedBlocksIconState();
}

class _AnimatedBlocksIconState extends State<AnimatedBlocksIcon>
    with SingleTickerProviderStateMixin {
  /// Lama satu langkah (tahan lalu pindah). Perbesar untuk lebih santai.
  static const _stepMs = 900;

  /// Urutan posisi pada grid 2x2 (0 kiri atas, 1 kanan atas, 2 kiri bawah,
  /// 3 kanan bawah): kanan atas -> kanan bawah -> kiri bawah -> kiri atas.
  static const _path = [1, 3, 2, 0];

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _stepMs * 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0; // diam: kotak aktif di kanan atas
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 1 saat [q] tepat di langkah [k], menurun ke 0 saat bergeser menjauh.
  double _intensity(double q, int k) {
    final d = (q - k).abs();
    final circular = math.min(d, 4 - d);
    return (1 - circular).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final pad = s * 0.2;
    final gap = s * 0.1;
    final inner = s - 2 * pad;
    final tile = (inner - gap) / 2;

    return Container(
      width: s,
      height: s,
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: GameColors.iconBackground,
        borderRadius: BorderRadius.circular(s * 0.28),
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          final p = _c.value * 4;
          final step = p.floor();
          final frac = p - step;
          // Tahan di posisi sekarang, lalu pindah di sisa waktu langkah.
          final move = Curves.easeInOutCubic.transform(
            ((frac - 0.45) / 0.55).clamp(0.0, 1.0),
          );
          final q = step + move;

          return SizedBox(
            width: inner,
            height: inner,
            child: Stack(
              children: [
                for (var k = 0; k < 4; k++)
                  Positioned(
                    left: (_path[k] % 2) * (tile + gap),
                    top: (_path[k] ~/ 2) * (tile + gap),
                    child: _tile(tile, _intensity(q, k)),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _tile(double size, double i) {
    return Transform.scale(
      scale: 0.82 + 0.18 * i,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color.lerp(GameColors.tileIdle, GameColors.tileActive, i),
          borderRadius: BorderRadius.circular(size * 0.3),
        ),
      ),
    );
  }
}

class _GameEntry {
  const _GameEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });

  final String title;
  final String subtitle;
  final Widget Function() icon;
  final Widget Function() page;
}

/// Menambah game baru cukup menambah satu entri di daftar ini.
final _games = <_GameEntry>[
  _GameEntry(
    title: 'Wordle',
    subtitle: 'Tebak kata 5 huruf',
    icon: () => const AnimatedBlocksIcon(),
    page: () => const WordlePage(),
  ),
];

class GamesSection extends StatelessWidget {
  const GamesSection({super.key});

  Widget _card(BuildContext context, _GameEntry g) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: GameColors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => g.page()));
          },
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: GameColors.cardBorder),
            ),
            child: Row(
              children: [
                ExcludeSemantics(child: g.icon()),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: GameColors.title,
                        ),
                      ),
                      Text(
                        g.subtitle,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: GameColors.subtitle,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: GameColors.arrow,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final g in _games) _card(context, g)],
    );
  }
}
