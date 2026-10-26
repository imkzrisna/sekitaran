import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:sekitaran/features/wordle/wordle_words.dart';

class WordlePage extends StatefulWidget {
  const WordlePage({super.key});

  @override
  State<WordlePage> createState() => _WordlePageState();
}

class _WordlePageState extends State<WordlePage> {
  static const _maxTries = 6;
  static const _wordLength = 5;
  static const _tileGap = 6.0;

  /// Tinggi tetap area tombol Tebak + petunjuk (atau kotak hasil).
  static const _slotHeight = 128.0;

  // Word list for the game (kata + petunjuk ada di wordle_words.dart)
  static final _words = kWordleHints.keys.toList();

  late final WordleInstance _instance;
  WordleGuessResult? _lastResult;
  bool _isGameOver = false;

  String _current = ''; // huruf yang sedang diketik
  String? _error;
  bool _showHint = true; // petunjuk aktif atau mati

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
            child: LayoutBuilder(
              builder: (context, c) {
                // Layar pendek: header dipadatkan, legenda disembunyikan.
                final compact = c.maxHeight < 700;
                return Padding(
                  padding: EdgeInsets.fromLTRB(24, compact ? 4 : 8, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(compact),
                      SizedBox(height: compact ? 6 : 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _subtitleRow(),
                      ),
                      if (!compact) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _legend(),
                        ),
                      ],
                      SizedBox(height: compact ? 4 : 10),
                      Expanded(child: _boardArea()),
                      SizedBox(
                        height: 22,
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
                      SizedBox(height: _slotHeight, child: _statusSlot()),
                      const SizedBox(height: 8),
                      WordleKeyboard(
                        onLetter: _onLetter,
                        onBackspace: _onBackspace,
                        keyStates: _keyStates(),
                        enabled: !_isGameOver,
                        keyHeight: compact ? 44 : 50,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(bool compact) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, compact ? 14 : 24, 4, 0),
      child: _title(),
    );
  }

  /// Papan mengisi sisa tinggi; ukuran kotak mengikuti ruang yang tersedia.
  Widget _boardArea() {
    return LayoutBuilder(
      builder: (context, c) {
        final byWidth =
            (c.maxWidth - _tileGap * (_wordLength - 1)) / _wordLength;
        final byHeight = (c.maxHeight - _tileGap * (_maxTries - 1)) / _maxTries;
        final size = min(byWidth, byHeight).clamp(24.0, 56.0).toDouble();
        return Center(
          // Jaga-jaga bila ruang lebih kecil dari ukuran minimum.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: WordleBoard(
              history: _lastResult?.history ?? [],
              currentGuess: _current,
              maxGuesses: _maxTries,
              wordLength: _wordLength,
              tileSize: size,
            ),
          ),
        );
      },
    );
  }

  Widget _statusSlot() {
    final status = _lastResult?.status ?? WordleStatus.incorrect;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameStatus(
          status: status,
          correctWord: _isGameOver && status == WordleStatus.outOfTries
              ? _instance.correctWord
              : null,
          onRetry: _isGameOver ? _retryGame : null,
          onSubmit: _isGameOver ? null : _onEnter,
          canSubmit: _current.length == _wordLength,
        ),
        if (!_isGameOver) _hintLine(),
      ],
    );
  }

  Widget _hintLine() {
    final hint = kWordleHints[_instance.correctWord.toLowerCase()];
    final visible = _showHint && hint != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: visible ? 1 : 0,
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Petunjuk : ',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: WordleColors.ink,
                ),
              ),
              TextSpan(
                text: hint ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: WordleColors.grey,
                ),
              ),
            ],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(height: 1.4),
        ),
      ),
    );
  }

  Widget _subtitleRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(child: _subtitle()),
        const SizedBox(width: 7),
        _hintToggle(),
      ],
    );
  }

  /// Tombol lingkaran: hijau + lampu menyala = petunjuk aktif.
  Widget _hintToggle() {
    final on = _showHint;
    return Tooltip(
      message: on ? 'Petunjuk aktif' : 'Petunjuk mati',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _showHint = !_showHint);
        },
        // Padding memperbesar area ketuk menjadi 48 tanpa mengubah tampilan.
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? WordleColors.correct : Colors.white,
              border: Border.all(
                color: on ? WordleColors.correct : WordleColors.tileBorder,
                width: 1.5,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                on ? Icons.lightbulb : Icons.lightbulb_outline,
                key: ValueKey(on),
                size: 20,
                color: on ? Colors.white : WordleColors.grey,
              ),
            ),
          ),
        ),
      ),
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
        'Guess the five-letter word in 6 tries',
        style: GoogleFonts.poppins(
          fontSize: 14,
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
