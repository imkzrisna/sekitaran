import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/features/assistant/business_assistant_service.dart';
import 'package:sekitaran/features/home/user_radial_menu.dart';

class BusinessAssistantPage extends StatefulWidget {
  const BusinessAssistantPage({
    super.key,
    this.repository,
    this.businessId,
    this.businessName,
    this.menu = const UserRadialMenu(),
  });

  final BusinessAssistantRepository? repository;
  final String? businessId;
  final String? businessName;

  /// Menu melingkar di pojok kanan bawah. Ganti sesuai peran yang membuka halaman ini.
  final Widget menu;

  @override
  State<BusinessAssistantPage> createState() => _BusinessAssistantPageState();
}

class _BusinessAssistantPageState extends State<BusinessAssistantPage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _bg = Color(0xFFF2F9F8);
  static const _ink = Color(0xFF252525);
  static const _grey = Color(0xFF7A7A7A);
  static const _border = Color(0xFFC9C9C9);
  static const _maxQuestionLength = 500;
  static const _minQuestionLength = 3;

  static const _suggestions = [
    'Toko apa saja yang ada di sekitar sini?',
    'Toko mana yang paling sering dipuji pelanggan?',
    'Apa keluhan pelanggan yang paling sering muncul?',
  ];

  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  late final BusinessAssistantRepository _repository;
  final _turns = <_ConversationTurn>[];

  bool _sending = false;
  String? _error;
  String? _lastQuestion;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseBusinessAssistantRepository();
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _ink,
    double? height,
  }) => GoogleFonts.poppins(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  // ---------- Logika ----------

  /// Asisten memakai sesi user yang sedang login.
  bool _ensureSession() {
    if (widget.repository != null ||
        Supabase.instance.client.auth.currentSession != null) {
      return true;
    }
    setState(() {
      _error = 'Silakan login dulu untuk memakai asisten.';
      _lastQuestion = null;
    });
    return false;
  }

  Future<void> _send() async {
    if (_sending) return;
    final question = _input.text.trim();
    if (question.length < _minQuestionLength) {
      setState(() {
        _error = 'Isi minimal tiga karakter';
        _lastQuestion = null;
      });
      return;
    }
    if (question.length > _maxQuestionLength) {
      setState(() {
        _error = 'Maksimal 500 huruf';
        _lastQuestion = null;
      });
      return;
    }
    if (!_ensureSession()) return;
    _input.clear();
    await _ask(question);
  }

  Future<void> _retry() async {
    final question = _lastQuestion;
    if (question != null) await _ask(question, appendUser: false);
  }

  Future<void> _ask(String question, {bool appendUser = true}) async {
    if (_sending) return;
    if (!_ensureSession()) return;
    final history = [
      for (final turn in _turns)
        AssistantTurn(
          role: turn.isAssistant ? 'assistant' : 'user',
          text: turn.text.length > 1000
              ? turn.text.substring(0, 1000)
              : turn.text,
        ),
    ];
    if (!appendUser && history.isNotEmpty && history.last.role == 'user') {
      history.removeLast();
    }
    if (history.length > 8) history.removeRange(0, history.length - 8);
    setState(() {
      _sending = true;
      _error = null;
      _lastQuestion = question;
      if (appendUser) {
        _turns.add(
          _ConversationTurn(
            text: question,
            isAssistant: false,
            time: DateTime.now(),
          ),
        );
      }
    });
    _scrollToBottom();

    try {
      final reply = await _repository.ask(
        question,
        history: history,
        businessId: widget.businessId,
      );
      if (!mounted) return;
      setState(() {
        _turns.add(
          _ConversationTurn(
            text: reply.answer,
            isAssistant: true,
            time: DateTime.now(),
            sources: reply.sources,
          ),
        );
      });
    } on BusinessAssistantFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      // Daftar dibalik (reverse), jadi posisi 0 adalah bagian paling bawah.
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Pesan disalin')));
  }

  String _clock(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  // ---------- Header ----------

  Widget _title() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            'Business Assistant',
            maxLines: 1,
            softWrap: false,
            style: _t(26, weight: FontWeight.w600, color: _green),
          ),
          Positioned(
            top: -14,
            right: -22,
            child: Text(
              '*',
              style: _t(44, weight: FontWeight.w500, color: _green, height: 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitle() {
    final name = widget.businessName?.trim();
    final text = (name == null || name.isEmpty)
        ? 'Answers based on customer comments'
        : 'About $name';
    return Container(
      padding: const EdgeInsets.only(bottom: 3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _t(15, weight: FontWeight.w500),
      ),
    );
  }

  Widget _header(bool compact) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(28, compact ? 24 : 56, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_title(), const SizedBox(height: 12), _subtitle()],
      ),
    );
  }

  // ---------- Tampilan awal ----------

  Widget _suggestionChip(String q) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _sending ? null : () => _ask(q),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border, width: 1.2),
        ),
        child: Text(q, style: _t(12.5)),
      ),
    );
  }

  Widget _welcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFE6F0E7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, size: 28, color: _green),
            ),
            const SizedBox(height: 14),
            Text(
              'Tanyakan apa kata pelanggan soal bisnis lokal',
              textAlign: TextAlign.center,
              style: _t(16, weight: FontWeight.w600, color: _green),
            ),
            const SizedBox(height: 8),
            Text(
              'Jawaban berbasis komentar pelanggan, lengkap dengan kutipan sebagai buktinya.',
              textAlign: TextAlign.center,
              style: _t(13, color: _grey, height: 1.5),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [for (final q in _suggestions) _suggestionChip(q)],
            ),
            const SizedBox(height: 18),
            Text(
              'Pertanyaanmu dan komentar publik yang relevan dikirim ke Gemini. Percakapan ini tidak disimpan.',
              textAlign: TextAlign.center,
              style: _t(11.5, color: _grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Percakapan ----------

  Widget _datePill() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border.withValues(alpha: 0.7)),
        ),
        child: Text(
          'Hari ini',
          style: _t(
            12,
            weight: FontWeight.w500,
            color: const Color(0xFF5F5F5F),
          ),
        ),
      ),
    );
  }

  BorderRadius _bubbleRadius(bool mine) => BorderRadius.only(
    topLeft: const Radius.circular(18),
    topRight: const Radius.circular(18),
    bottomLeft: Radius.circular(mine ? 18 : 4),
    bottomRight: Radius.circular(mine ? 4 : 18),
  );

  Widget _source(AssistantSource source) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${source.businessName} \u00B7 ${_date(source.createdAt)}',
            style: _t(12, weight: FontWeight.w600, color: _green),
          ),
          const SizedBox(height: 4),
          Text('\u201C${source.excerpt}\u201D', style: _t(12.5, height: 1.4)),
        ],
      ),
    );
  }

  Widget _sources(_ConversationTurn turn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => turn.showSources = !turn.showSources),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _accent, width: 1.5),
                  ),
                ),
                child: Text(
                  'Sources \u00B7 ${turn.sources.length}',
                  style: _t(12.5, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedRotation(
                turns: turn.showSources ? 0.25 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.chevron_right, size: 18, color: _grey),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: turn.showSources
              ? Column(children: [for (final s in turn.sources) _source(s)])
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _bubble(_ConversationTurn turn) {
    final mine = !turn.isAssistant;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GestureDetector(
          onLongPress: () => _copy(turn.text),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: mine ? _green : Colors.white,
              borderRadius: _bubbleRadius(mine),
              border: mine
                  ? null
                  : Border.all(color: _border.withValues(alpha: 0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: turn.text,
                        style: _t(
                          14.5,
                          color: mine ? Colors.white : _ink,
                          height: 1.45,
                        ),
                      ),
                      const WidgetSpan(child: SizedBox(width: 10)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Text(
                          _clock(turn.time),
                          style: _t(11, color: mine ? Colors.white70 : _grey),
                        ),
                      ),
                    ],
                  ),
                ),
                if (turn.sources.isNotEmpty) _sources(turn),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: _bubbleRadius(false),
          border: Border.all(color: _border.withValues(alpha: 0.6)),
        ),
        child: const _TypingDots(),
      ),
    );
  }

  Widget _messages() {
    final items = <Widget>[
      _datePill(),
      for (final t in _turns) _bubble(t),
      if (_sending) _typingBubble(),
    ];
    return ListView(
      controller: _scroll,
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
      children: items.reversed.toList(),
    );
  }

  // ---------- Kolom tulis ----------

  Widget _errorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _error!,
              style: _t(12, color: Colors.red.shade700, height: 1.35),
            ),
          ),
          if (_lastQuestion != null)
            TextButton(
              onPressed: _sending ? null : _retry,
              child: Text(
                'Retry',
                style: _t(12.5, weight: FontWeight.w600, color: _green),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field() {
    OutlineInputBorder border(double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: _green, width: width),
    );
    return TextField(
      controller: _input,
      focusNode: _focus,
      minLines: 1,
      maxLines: 4,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.send,
      textCapitalization: TextCapitalization.sentences,
      inputFormatters: [LengthLimitingTextInputFormatter(_maxQuestionLength)],
      onChanged: (_) {
        // Pesan validasi hilang begitu user mengetik lagi.
        if (_error != null && _lastQuestion == null) {
          setState(() => _error = null);
        }
      },
      onSubmitted: (_) async {
        await _send();
        if (mounted) _focus.requestFocus();
      },
      style: _t(14.5),
      decoration: InputDecoration(
        hintText: 'Tanya soal toko...',
        hintStyle: _t(14, weight: FontWeight.w300, color: _grey),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 15,
        ),
        border: border(1.5),
        enabledBorder: border(1.5),
        focusedBorder: border(1.8),
      ),
    );
  }

  Widget _sendButton(bool enabled) {
    return Semantics(
      button: true,
      label: 'Kirim pesan',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _send : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (enabled || _sending) ? _green : _border,
          ),
          child: Center(
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 22, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _composer(MediaQueryData mq) {
    final keyboard = mq.viewInsets.bottom > 0;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      // Sisakan ruang untuk tombol menu melingkar saat keyboard tertutup.
      padding: EdgeInsets.fromLTRB(
        28,
        8,
        keyboard ? 28 : 88,
        keyboard ? 12 : 43 + mq.padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) _errorBanner(),
          ListenableBuilder(
            listenable: _input,
            builder: (context, _) {
              final len = _input.text.length;
              final enabled =
                  _input.text.trim().length >= _minQuestionLength && !_sending;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (len >= 450)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 4),
                      child: Text(
                        '$len/$_maxQuestionLength',
                        style: _t(11, color: _grey),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _field()),
                      const SizedBox(width: 10),
                      _sendButton(enabled),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom > 0;
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    _header(keyboard),
                    const SizedBox(height: 8),
                    Expanded(child: _turns.isEmpty ? _welcome() : _messages()),
                    _composer(mq),
                  ],
                ),
              ),
            ),
          ),
        ),
        widget.menu,
      ],
    );
  }
}

class _ConversationTurn {
  _ConversationTurn({
    required this.text,
    required this.isAssistant,
    required this.time,
    this.sources = const [],
  });

  final String text;
  final bool isAssistant;
  final DateTime time;
  final List<AssistantSource> sources;
  bool showSources = false;
}

/// Tiga titik yang bergelombang, penanda asisten sedang menjawab.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _wave(int i) {
    final t = (_c.value - i * 0.16) % 1.0;
    return (math.sin(t * 2 * math.pi - math.pi / 2) + 1) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
              width: 8,
              height: 8,
              transform: Matrix4.translationValues(0, -3 * _wave(i), 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _green.withValues(alpha: 0.35 + 0.65 * _wave(i)),
              ),
            ),
        ],
      ),
    );
  }
}
