import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart'
    show WordleColors;
import 'package:sekitaran/features/wordle/wordle_status.dart';

class GameStatus extends StatelessWidget {
  const GameStatus({
    super.key,
    required this.status,
    this.correctWord,
    this.onRetry,
    this.triesLeft,
  });

  final WordleStatus status;
  final String? correctWord;
  final VoidCallback? onRetry;
  final int? triesLeft;

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
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
    );
  }
}
