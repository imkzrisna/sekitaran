import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';

class OwnedChat extends StatelessWidget {
  new({required this.message, super.key});

  static const _green = Color(0xFF103D17);

  Message message;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Card(
          color: _green,

          child: Container(
            padding: EdgeInsets.all(15),
            child: Column(
              children: [
                Text(message.username, style: TextStyle(color: Colors.white)),
                Text(message.message, style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ),

        message.avatarUrl != ""
            ? Image.network(message.avatarUrl, width: 50)
            : const Placeholder(strokeWidth: 50),
      ],
    );
  }
}
