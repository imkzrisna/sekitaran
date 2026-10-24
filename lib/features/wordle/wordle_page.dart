import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/vo/char_result.dart';
import 'package:sekitaran/features/wordle/vo/green_char.dart';
import 'package:sekitaran/features/wordle/vo/wordle_guess_result.dart';
import 'package:sekitaran/features/wordle/vo/yellow_char.dart';
import 'package:sekitaran/features/wordle/widget/game_status.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart'
    show TileState, WordleColors;
import 'package:sekitaran/features/wordle/widget/wordle_board.dart';
import 'package:sekitaran/features/wordle/widget/wordle_keyboard.dart';
import 'package:sekitaran/features/wordle/wordle_instance.dart';
import 'package:sekitaran/features/wordle/wordle_status.dart';

class WordlePage extends StatefulWidget {
  const WordlePage({super.key});

  @override
  State<WordlePage> createState() => _WordlePageState();
}

class _WordlePageState extends State<WordlePage> {
  static const _maxTries = 6;
  static const _wordLength = 5;

  // Word list for the game
  static const _words = [
    // Tempat tinggal dan kehidupan anak kos
    'kosan',
    'kamar',
    'sewa',
    'papan', // Tempat tinggal
    // Tempat dan usaha di sekitar
    'pasar',
    'halte',
    'taman',
    'dekat',
    'lokal',

    // Belanja dan kebutuhan sehari-hari
    'nyari',
    'bayar',
    'harga',
    'murah',
    'mahal',
    'hemat',
    'belan', // Tidak valid: bukan kata utuh
    'jajan',
    // Makanan dan kebutuhan anak kos
    'lapar',
    'bakso',
    'beras',
    'sikat',
    'sabun',
    'galon',
    'masak',
    'makan',
    'bekal',
    // Kehidupan perantau dan lingkungan
    'teman',
    'warga',
    'rindu',
    'salam',
    'bantu',
    'dekat',
    'jalan',
  ];

  late final WordleInstance _instance;
  WordleGuessResult? _lastResult;
  bool _isGameOver = false;

  String _current = ''; // huruf yang sedang diketik
  String? _error;

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
      _current = '';
      _error = null;
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

  // ---------- Keyboard ----------

  void _onLetter(String ch) {
    if (_isGameOver || _current.length >= _wordLength) return;
    setState(() {
      _current += ch;
      _error = null;
    });
  }

  void _onBackspace() {
    if (_isGameOver || _current.isEmpty) return;
    setState(() {
      _current = _current.substring(0, _current.length - 1);
      _error = null;
    });
  }

  void _onEnter() {
    if (_isGameOver) return;
    if (_current.length != _wordLength) {
      setState(() => _error = 'Masukkan $_wordLength huruf');
      return;
    }
    final word = _current;
    setState(() {
      _current = '';
      _error = null;
    });
    _handleGuess(word);
  }

  /// Status terbaik tiap huruf dari semua tebakan (tepat > salah posisi > tidak ada).
  Map<String, TileState> _keyStates() {
    int rank(TileState s) => switch (s) {
      TileState.correct => 3,
      TileState.present => 2,
      TileState.absent => 1,
      TileState.empty => 0,
    };
    final map = <String, TileState>{};
    final history = _lastResult?.history ?? const <List<CharResult>>[];
    for (final row in history) {
      for (final r in row) {
        final key = r.char.toUpperCase();
        final s = r is GreenChar
            ? TileState.correct
            : r is YellowChar
            ? TileState.present
            : TileState.absent;
        final old = map[key];
        if (old == null || rank(s) > rank(old)) map[key] = s;
      }
    }
    return map;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WordleColors.bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          padding: EdgeInsets.zero,
                          alignment: Alignment.centerLeft,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 20,
                            color: WordleColors.correct,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _title(),
                              const SizedBox(height: 10),
                              _subtitle(),
                              const SizedBox(height: 12),
                              _legend(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        WordleBoard(
                          history: _lastResult?.history ?? [],
                          currentGuess: _current,
                          maxGuesses: _maxTries,
                          wordLength: _wordLength,
                        ),
                        SizedBox(
                          height: 28,
                          child: Center(
                            child: Text(
                              _error ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ),
                        _gameStatus(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: WordleKeyboard(
                    onLetter: _onLetter,
                    onEnter: _onEnter,
                    onBackspace: _onBackspace,
                    keyStates: _keyStates(),
                    enabled: !_isGameOver,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gameStatus() {
    final used = _lastResult?.history.length ?? 0;
    if (_lastResult == null) {
      return const GameStatus(
        status: WordleStatus.incorrect,
        triesLeft: _maxTries,
      );
    }
    return GameStatus(
      status: _lastResult!.status,
      triesLeft: _maxTries - used,
      correctWord: _isGameOver && _lastResult!.status == WordleStatus.outOfTries
          ? _instance.correctWord
          : null,
      onRetry: _isGameOver ? _retryGame : null,
    );
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
            color: WordleColors.correct,
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
              color: WordleColors.correct,
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
        border: Border(
          bottom: BorderSide(color: WordleColors.accent, width: 1.5),
        ),
      ),
      child: Text(
        'Tebak kata lima huruf dengan batas 6 kali',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: WordleColors.ink,
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: WordleColors.grey),
        ),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        item(WordleColors.correct, 'Tepat'),
        item(WordleColors.present, 'Salah posisi'),
        item(WordleColors.absent, 'Tidak ada'),
      ],
    );
  }
}
