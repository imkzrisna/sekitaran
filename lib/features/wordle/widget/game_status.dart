import 'package:flutter/material.dart';
import 'package:sekitaran/features/wordle/wordle_status.dart';

class GameStatus extends StatelessWidget {
  const GameStatus({
    super.key,
    required this.status,
    this.correctWord,
    this.onRetry,
  });

  final WordleStatus status;
  final String? correctWord;
  final VoidCallback? onRetry;

  bool get _isGameOver =>
      status == WordleStatus.correct || status == WordleStatus.outOfTries;

  @override
  Widget build(BuildContext context) {
    final (message, color, icon) = switch (status) {
      WordleStatus.correct => (
        '🎉 Selamat! Kamu menang!',
        const Color(0xFF103D17),
        Icons.check_circle_outline,
      ),
      WordleStatus.outOfTries => (
        'Game Over! Kata yang benar: ${correctWord?.toUpperCase() ?? '—'}',
        const Color(0xFFC62828),
        Icons.cancel_outlined,
      ),
      _ => ('Coba tebak!', const Color(0xFF7A7A7A), Icons.help_outline),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 16),
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
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
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
                label: const Text(
                  'Main lagi',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(color: color, width: 2),
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

