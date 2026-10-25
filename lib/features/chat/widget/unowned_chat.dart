import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';

class UnownedChat extends StatelessWidget {
  new({required this.message, super.key});

  static const _green = Color(0xFF103D17);

  Message message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        message.avatarUrl != ""
            ? Image.network(message.avatarUrl, width: 50)
            : const Placeholder(strokeWidth: 50),
        Card(
          color: Colors.white,

          child: Container(
            padding: EdgeInsets.all(15),
            child: Column(
              children: [
                Text(message.username, style: TextStyle(color: Colors.black)),
                Text(message.message, style: TextStyle(color: Colors.black)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
