import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart'
    show WordleColors;
import 'package:sekitaran/features/wordle/wordle_status.dart';

/// Saat bermain: satu tombol "Tebak". Saat selesai: kotak hasil + "Main lagi".
class GameStatus extends StatelessWidget {
  const GameStatus({
    super.key,
    required this.status,
    this.correctWord,
    this.onRetry,
    this.onSubmit,
    this.canSubmit = false,
  });

  final WordleStatus status;
  final String? correctWord;
  final VoidCallback? onRetry;
  final VoidCallback? onSubmit;

  /// true bila huruf sudah lengkap (tombol tampil penuh).
  final bool canSubmit;

  bool get _isGameOver =>
      status == WordleStatus.correct || status == WordleStatus.outOfTries;

  @override
  Widget build(BuildContext context) {
    return _isGameOver ? _resultBox() : _submitButton();
  }

  Widget _submitButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: canSubmit ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onSubmit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: WordleColors.correct, width: 2),
          ),
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: WordleColors.correct,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.keyboard_return,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tebak',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resultBox() {
    final won = status == WordleStatus.correct;
    final color = won ? WordleColors.correct : WordleColors.danger;
    final icon = won ? Icons.check_circle_outline : Icons.cancel_outlined;
    final message = won
        ? 'Selamat! Kamu menang!'
        : 'Game over! Kata yang benar: ${correctWord?.toUpperCase() ?? '-'}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
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
                  padding: const EdgeInsets.symmetric(vertical: 9),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
