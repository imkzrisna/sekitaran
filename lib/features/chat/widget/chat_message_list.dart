import 'package:flutter/material.dart';
import 'package:sekitaran/features/chat/widget/chat_bubble.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';

/// Daftar pesan terbalik (reverse): pesan terbaru menempel di bawah, dan
/// posisi tetap di bawah saat keyboard muncul atau pesan baru masuk.
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
  final _scroll = ScrollController();
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 160;
      if (show != _showJump) setState(() => _showJump = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
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
            final first = prev == null || prev.username != m.username;
            final last = next == null || next.username != m.username;
            return Padding(
              padding: EdgeInsets.only(top: first ? 10 : 3),
              child: ChatBubble(
                text: m.message,
                name: m.username,
                avatarUrl: m.avatarUrl,
                mine: m.username == widget.currentUsername,
                firstInGroup: first,
                lastInGroup: last,
              ),
            );
          },
        ),
        if (_showJump)
          Positioned(
            right: 16,
            bottom: 12,
            child: Material(
              color: Colors.white,
              elevation: 2,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _jumpToLatest,
                child: const SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: ChatColors.green,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
