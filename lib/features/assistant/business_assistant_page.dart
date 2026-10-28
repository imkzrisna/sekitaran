import 'package:flutter/material.dart';
import 'package:sekitaran/features/assistant/business_assistant_service.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';

class BusinessAssistantPage extends StatefulWidget {
  const BusinessAssistantPage({
    super.key,
    this.repository,
    this.businessId,
    this.businessName,
  });

  final BusinessAssistantRepository? repository;
  final String? businessId;
  final String? businessName;

  @override
  State<BusinessAssistantPage> createState() => _BusinessAssistantPageState();
}

class _BusinessAssistantPageState extends State<BusinessAssistantPage> {
  static const _green = Color(0xFF103D17);
  static const _bg = Color(0xFFF2F9F8);
  static const _ink = Color(0xFF252525);
  static const _grey = Color(0xFF7A7A7A);
  static const _maxQuestionLength = 500;

  final _input = TextEditingController();
  final _scroll = ScrollController();
  late final BusinessAssistantRepository _repository;
  final _turns = <_ConversationTurn>[];

  bool _sending = false;
  String? _error;
  String? _lastQuestion;

  late Future<void> _initStateAsyncFuture;

  Future<void> _initStateAsync() async {
    final session = SupabaseSessionManager();
    await session.signInWithPasswordAsync(
      email: "124240154@student.upnyk.ac.id",
      password: "sayakurangtawu3",
    );
  }

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? SupabaseBusinessAssistantRepository();

    _initStateAsyncFuture = _initStateAsync();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final question = _input.text.trim();
    if (question.length < 3) {
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
    _input.clear();
    await _ask(question);
  }

  Future<void> _retry() async {
    final question = _lastQuestion;
    if (question != null) await _ask(question, appendUser: false);
  }

  Future<void> _ask(String question, {bool appendUser = true}) async {
    if (_sending) return;
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
        _turns.add(_ConversationTurn(text: question, isAssistant: false));
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
            sources: reply.sources,
          ),
        );
      });
    } on BusinessAssistantFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
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
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  Widget _welcome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome, size: 38, color: _green),
            const SizedBox(height: 12),
            Text(
              'Tanyakan apa yang pelanggan bilang soal bisnis lokal',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(color: _green, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tanyakan pertanyaan umum about suatu toko atau pengalaman pelanggan. Jawaban berbasis komentar dengan bukti yang dipaparkan',
              textAlign: TextAlign.center,
              style: TextStyle(color: _grey, height: 1.5),
            ),
            const SizedBox(height: 12),
            const Text(
              'Pertanyaanmu dan komentar publik yang relevant akan dikirim ke Gemini, percakapan ini tidak di save',
              textAlign: TextAlign.center,
              style: TextStyle(color: _grey, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _source(AssistantSource source) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${source.businessName} · ${_date(source.createdAt)}',
            style: const TextStyle(
              color: _green,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '\u201C${source.excerpt}\u201D',
            style: const TextStyle(color: _ink, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _turn(_ConversationTurn turn) {
    return Align(
      alignment: turn.isAssistant
          ? Alignment.centerLeft
          : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: turn.isAssistant ? Colors.white : _green,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              turn.text,
              style: TextStyle(
                color: turn.isAssistant ? _ink : Colors.white,
                height: 1.45,
              ),
            ),
            if (turn.sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Sources',
                style: TextStyle(
                  color: _green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              for (final source in turn.sources) _source(source),
            ],
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  if (_lastQuestion != null)
                    TextButton(
                      onPressed: _sending ? null : _retry,
                      child: const Text('Retry'),
                    ),
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: _maxQuestionLength,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText:
                          'Tanyakan apa yang pelanggan bilang soal suatu toko',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Kirim pesan',
                  onPressed: _sending ? null : _send,
                  style: IconButton.styleFrom(backgroundColor: _green),
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Business Assistant'),
            Text(
              'Jawaban berbasis komentar pelanggan',
              style: TextStyle(fontSize: 12, color: _grey),
            ),
          ],
        ),
        backgroundColor: _bg,
      ),
      body: FutureBuilder(
        future: _initStateAsyncFuture,
        builder: (context, snapshot) {
          return Column(
            children: [
              Expanded(
                child: _turns.isEmpty
                    ? _welcome()
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        children: [
                          for (final turn in _turns) _turn(turn),
                          if (_sending)
                            const Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _green,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              _composer(),
            ],
          );
        },
      ),
    );
  }
}

class _ConversationTurn {
  const _ConversationTurn({
    required this.text,
    required this.isAssistant,
    this.sources = const [],
  });

  final String text;
  final bool isAssistant;
  final List<AssistantSource> sources;
}
