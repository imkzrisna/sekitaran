import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/widget/game_status.dart';
import 'package:sekitaran/features/wordle/widget/input_section.dart';
import 'package:sekitaran/features/wordle/widget/wordle_board.dart';
import 'package:sekitaran/features/wordle/wordle_instance.dart';
import 'package:sekitaran/features/wordle/wordle_status.dart';
import 'package:sekitaran/features/wordle/vo/wordle_guess_result.dart';

class WordlePage extends StatefulWidget {
  const WordlePage({super.key});

  @override
  State<WordlePage> createState() => _WordlePageState();
}

class _WordlePageState extends State<WordlePage> {
  // Color palette matching the app design system
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);
  static const _border = Color(0xFFC9C9C9);

  // Word list for the game
  static const _words = [
    'kosan',
    'kopma',
    'dosen',
    'teman',
    'rindu',
    'bekal',
    'kirim',
    'hemat',
    'lapar',
    'murah',
    'kamar',
    'pulau',
    'nasib',
    'mandi',
  ];

  late final WordleInstance _instance;
  WordleGuessResult? _lastResult;
  bool _isGameOver = false;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final rng = Random();
    final chosenWord = _words[rng.nextInt(_words.length)];
    _instance = WordleInstance().setCorrectWord(chosenWord);
    _lastResult = null;
    _isGameOver = false;
  }

  void _retryGame() {
    final rng = Random();
    final newWord = _words[rng.nextInt(_words.length)];
    _instance.reset(newWord);
    setState(() {
      _lastResult = null;
      _isGameOver = false;
    });
  }

  void _handleGuess(String word) {
    if (_isGameOver) return;

    final result = _instance.guess(word.toLowerCase());
    setState(() {
      _lastResult = result;
      _isGameOver =
          result.status == WordleStatus.correct ||
          result.status == WordleStatus.outOfTries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 56, 28, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(),
                  const SizedBox(height: 8),
                  _subtitle(),
                  const SizedBox(height: 32),
                  _gameBoard(),
                  const SizedBox(height: 16),
                  _gameStatus(),
                  const SizedBox(height: 16),
                  _gameInput(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameBoard() {
    return WordleBoard(history: _lastResult?.history ?? []);
  }

  Widget _gameStatus() {
    if (_lastResult == null) {
      return GameStatus(status: WordleStatus.incorrect);
    }
    return GameStatus(
      status: _lastResult!.status,
      correctWord: _isGameOver && _lastResult!.status == WordleStatus.outOfTries
          ? _instance.correctWord
          : null,
      onRetry: _isGameOver ? _retryGame : null,
    );
  }

  Widget _gameInput() {
    return InputSection(onGuess: _handleGuess, enabled: !_isGameOver);
  }

  Widget _title() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'Wordle',
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
    return Container(
      padding: const EdgeInsets.only(bottom: 3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
      ),
      child: Text(
        'tebak kata lima huruf dengan batas 6 kali',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _label,
        ),
      ),
    );
  }

  Widget _emptySectionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _accent, width: 1.5),
                  ),
                ),
                child: Text(
                  'Content Area',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _label,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.dashboard_outlined, color: _green, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.add_circle_outline,
                  size: 48,
                  color: _grey.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'Replace this card with your content',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _grey,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use _sectionCard() pattern for new sections',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _grey.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
