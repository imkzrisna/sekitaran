import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/wordle_page.dart';

/// Warna bagian Games. Sengaja netral: isi sendiri sesuai desain.
class GameColors {
  const GameColors._();
  static const cardBackground = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFC9C9C9);
  static const iconBackground = Color(0xFFEAEAEA);
  static const icon = Color(0xFF7A7A7A);
  static const title = Color(0xFF252525);
  static const subtitle = Color(0xFF7A7A7A);
  static const arrow = Color(0xFF7A7A7A);
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
  final IconData icon;
  final Widget Function() page;
}

/// Menambah game baru cukup menambah satu entri di daftar ini.
final _games = <_GameEntry>[
  _GameEntry(
    title: 'Wordle',
    subtitle: 'Tebak kata 5 huruf',
    icon: Icons.grid_view_rounded,
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
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => g.page())),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GameColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: GameColors.iconBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(g.icon, color: GameColors.icon, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.title,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
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
