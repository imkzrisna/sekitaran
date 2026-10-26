import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChatColors {
  const ChatColors._();
  static const green = Color(0xFF103D17);
  static const accent = Color(0xFF5BAA5F);
  static const ink = Color(0xFF252525);
  static const bg = Color(0xFFF2F9F8);
  static const grey = Color(0xFF7A7A7A);
  static const border = Color(0xFFC9C9C9);
  static const bubbleBorder = Color(0xFFE1E7E6);
}

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({super.key, required this.name, this.url, this.size = 36});

  final String name;
  final Object? url;
  final double size;

  Widget _fallback() {
    final initial = name.isEmpty
        ? '?'
        : String.fromCharCode(name.runes.first).toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: ChatColors.green,
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: GoogleFonts.poppins(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u is! String || u.isEmpty) return _fallback();
    return ClipOval(
      child: Image.network(
        u,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
        loadingBuilder: (_, child, progress) =>
            progress == null ? child : _fallback(),
      ),
    );
  }
}

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.name,
    required this.avatarUrl,
    required this.mine,
    required this.firstInGroup,
    required this.lastInGroup,
    this.createdAt,
  });

  static const _avatar = 36.0;
  static const _gap = 8.0;
  static const _timeGap = '\u2003\u2003\u2003';

  final String text;
  final String name;
  final Object? avatarUrl;
  final bool mine;
  final bool firstInGroup;
  final bool lastInGroup;
  final DateTime? createdAt;

  Widget _bubble() {
    const big = Radius.circular(18);
    const small = Radius.circular(4);
    final radius = mine
        ? BorderRadius.only(
            topLeft: big,
            topRight: big,
            bottomLeft: big,
            bottomRight: lastInGroup ? small : big,
          )
        : BorderRadius.only(
            topLeft: firstInGroup ? small : big,
            topRight: big,
            bottomLeft: big,
            bottomRight: big,
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: mine ? ChatColors.green : Colors.white,
        border: mine ? null : Border.all(color: ChatColors.bubbleBorder),
        borderRadius: radius,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!mine && firstInGroup)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ChatColors.green,
                    ),
                  ),
                ),
              _CollapsibleText(
                text: text,
                mine: mine,
                suffix: createdAt != null ? _timeGap : '',
              ),
            ],
          ),
          if (createdAt != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Text(
                _hhmm(createdAt!),
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  color: mine ? Colors.white60 : ChatColors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (mine) {
          return Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: c.maxWidth * 0.78),
              child: _bubble(),
            ),
          );
        }
        final maxBubble = (c.maxWidth - _avatar - _gap) * 0.9;
        return Align(
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _avatar,
                child: firstInGroup
                    ? ChatAvatar(name: name, url: avatarUrl, size: _avatar)
                    : null,
              ),
              const SizedBox(width: _gap),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxBubble),
                child: _bubble(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Teks pesan: pesan panjang dipotong 8 baris dengan tombol selengkapnya.
class _CollapsibleText extends StatefulWidget {
  const _CollapsibleText({
    required this.text,
    required this.mine,
    this.suffix = '',
  });

  final String text;
  final bool mine;
  final String suffix;

  @override
  State<_CollapsibleText> createState() => _CollapsibleTextState();
}

class _CollapsibleTextState extends State<_CollapsibleText> {
  static const _maxLines = 8;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.mine ? Colors.white : ChatColors.ink;
    final style = GoogleFonts.poppins(fontSize: 14, height: 1.4, color: color);

    return LayoutBuilder(
      builder: (context, c) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text + widget.suffix, style: style),
          textDirection: Directionality.of(context),
          maxLines: _maxLines,
        )..layout(maxWidth: c.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(
              widget.text + widget.suffix,
              style: style,
              maxLines: (!overflows || _expanded) ? null : _maxLines,
            ),
            if (overflows)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? 'Tutup' : 'Baca selengkapnya',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: widget.mine ? Colors.white70 : ChatColors.accent,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
