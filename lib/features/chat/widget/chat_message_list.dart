import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/chat/widget/chat_bubble.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';

/// Daftar pesan terbalik (reverse): pesan terbaru menempel di bawah.
class ChatMessageList extends StatefulWidget {
  const ChatMessageList({
    super.key,
    required this.messages,
    required this.currentUsername,
  });

  final List<Message> messages;
  final String currentUsername;

  @override
  State<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends State<ChatMessageList> {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  static const _noFresh = 1 << 30;

  final _scroll = ScrollController();
  Timer? _freshTimer;
  bool _showJump = false;
  int _unread = 0;

  /// Pesan dengan index >= nilai ini dianimasikan (pop-in).
  int _freshFrom = _noFresh;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 160;
      if (show != _showJump) {
        setState(() {
          _showJump = show;
          if (!show) _unread = 0;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLen = oldWidget.messages.length;
    final msgs = widget.messages;
    final diff = msgs.length - oldLen;
    if (diff <= 0) return;

    // Animasikan hanya pesan yang masuk setelah load awal.
    if (oldLen > 0) {
      _freshFrom = oldLen;
      _freshTimer?.cancel();
      _freshTimer = Timer(const Duration(milliseconds: 700), () {
        _freshFrom = _noFresh;
      });
    }

    final incoming = msgs.sublist(oldLen);
    final mineSent = incoming.any((m) => m.username == widget.currentUsername);
    final fromOthers = incoming
        .where((m) => m.username != widget.currentUsername)
        .length;

    if (mineSent) {
      // Pengguna baru mengirim: selalu turun ke pesan terbaru.
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
    } else if (_showJump && fromOthers > 0) {
      // Sedang membaca pesan lama: hitung pesan baru dari orang lain.
      _unread += fromOthers;
    }
  }

  @override
  void dispose() {
    _freshTimer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Satu grup = pengirim sama, hari sama, selisih < 10 menit.
  bool _sameGroup(Message a, Message b) {
    if (a.username != b.username) return false;
    final ta = a.createdAt, tb = b.createdAt;
    if (ta == null || tb == null) return true;
    return _sameDay(ta, tb) && tb.difference(ta).inMinutes.abs() < 10;
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Hari ini';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Kemarin';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  Widget _dateChip(DateTime d) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ChatColors.bubbleBorder),
          ),
          child: Text(
            _dateLabel(d),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: ChatColors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _jumpButton() {
    final hasNew = _unread > 0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 12,
      child: IgnorePointer(
        ignoring: !_showJump,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          offset: _showJump ? Offset.zero : const Offset(0, 1.5),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: _showJump ? 1 : 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                decoration: ShapeDecoration(
                  color: hasNew ? ChatColors.green : Colors.white,
                  shape: const StadiumBorder(),
                  shadows: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: _jumpToLatest,
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: hasNew ? 14 : 10,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 20,
                              color: hasNew ? Colors.white : ChatColors.green,
                            ),
                            if (hasNew) ...[
                              const SizedBox(width: 4),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Text(
                                  _unread > 99
                                      ? '99+ pesan baru'
                                      : '$_unread pesan baru',
                                  key: ValueKey(_unread),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.messages;
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          itemCount: msgs.length,
          itemBuilder: (_, i) {
            final idx = msgs.length - 1 - i;
            final m = msgs[idx];
            final prev = idx > 0 ? msgs[idx - 1] : null;
            final next = idx < msgs.length - 1 ? msgs[idx + 1] : null;
            final first = prev == null || !_sameGroup(prev, m);
            final last = next == null || !_sameGroup(m, next);
            final t = m.createdAt;
            final newDay =
                t != null &&
                (prev == null ||
                    prev.createdAt == null ||
                    !_sameDay(prev.createdAt!, t));
            final mine = m.username == widget.currentUsername;

            return _PopIn(
              // Key per posisi: pesan baru ditambah di akhir, jadi index stabil.
              key: ValueKey(idx),
              animate: idx >= _freshFrom,
              fromRight: mine,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (newDay) _dateChip(t),
                  Padding(
                    padding: EdgeInsets.only(top: first ? 12 : 3),
                    child: ChatBubble(
                      text: m.message,
                      name: m.username,
                      avatarUrl: m.avatarUrl,
                      mine: mine,
                      firstInGroup: first,
                      lastInGroup: last,
                      createdAt: m.createdAt,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        _jumpButton(),
      ],
    );
  }
}

/// Animasi muncul: fade + naik sedikit + membesar dari sisi pengirim.
class _PopIn extends StatelessWidget {
  const _PopIn({
    super.key,
    required this.animate,
    required this.fromRight,
    required this.child,
  });

  final bool animate;
  final bool fromRight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: animate ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 18),
          child: Transform.scale(
            scale: 0.88 + 0.12 * v,
            alignment: fromRight ? Alignment.bottomRight : Alignment.bottomLeft,
            child: child,
          ),
        ),
      ),
      child: child,
    );
  }
}
