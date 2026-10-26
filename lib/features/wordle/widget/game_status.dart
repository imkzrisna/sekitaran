import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart'
    show WordleColors;
import 'package:sekitaran/features/wordle/wordle_status.dart';

/// Kotak status. Saat permainan berjalan, kotak ini juga tombol "Tebak":
/// abu-abu bila huruf belum lengkap, hijau bila siap dikirim.
class GameStatus extends StatelessWidget {
  const GameStatus({
    super.key,
    required this.status,
    this.correctWord,
    this.onRetry,
    this.triesLeft,
    this.onSubmit,
    this.canSubmit = false,
  });

  final WordleStatus status;
  final String? correctWord;
  final VoidCallback? onRetry;
  final int? triesLeft;
  final VoidCallback? onSubmit;
  final bool canSubmit;

  bool get _isGameOver =>
      status == WordleStatus.correct || status == WordleStatus.outOfTries;

  @override
  Widget build(BuildContext context) {
    final (message, color, icon) = switch (status) {
      WordleStatus.correct => (
        'Selamat! Kamu menang!',
        WordleColors.correct,
        Icons.check_circle_outline,
      ),
      WordleStatus.outOfTries => (
        'Game over! Kata yang benar: ${correctWord?.toUpperCase() ?? '-'}',
        WordleColors.danger,
        Icons.cancel_outlined,
      ),
      _ => (
        triesLeft == null
            ? 'Coba tebak!'
            : 'Coba tebak! Sisa $triesLeft kesempatan',
        WordleColors.grey,
        Icons.help_outline,
      ),
    };

    final playing = !_isGameOver;
    final tappable = playing && onSubmit != null;
    final ready = tappable && canSubmit;
    final fg = ready ? Colors.white : color;
    final bg = ready ? WordleColors.correct : color.withValues(alpha: 0.1);
    final borderColor = ready
        ? WordleColors.correct
        : color.withValues(alpha: 0.3);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tappable ? onSubmit : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: fg, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.poppins(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (tappable)
                    Container(
                      margin: const EdgeInsets.only(left: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: ready
                            ? Colors.white
                            : color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.keyboard_return,
                            size: 16,
                            color: ready ? WordleColors.correct : color,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tebak',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: ready ? WordleColors.correct : color,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (_isGameOver && onRetry != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(
                      'Main lagi',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
