import 'package:bubble/bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';

class OwnedChat extends StatelessWidget {
  new({required this.message, super.key});

  static const _green = Color(0xFF103D17);
  static const _gold = Color(0xFFC99A4A);

  Message message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Bubble(
          nip: BubbleNip.rightTop,
          style: BubbleStyle(color: _green),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 5,
            children: [
              Text(message.username, style: TextStyle(color: _gold)),
              Container(
                constraints: BoxConstraints(maxWidth: 250),
                child: Text(
                  message.message,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),

        message.avatarUrl != ""
            ? Container(
                constraints: BoxConstraints(maxWidth: 50, maxHeight: 50),
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(message.avatarUrl, scale: 1),
                ),
              )
            : const Placeholder(strokeWidth: 50),
      ],
    );
  }
}
