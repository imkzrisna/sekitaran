import 'dart:async';

import 'package:sekitaran/features/global_chat/adapter/chat_gateway_interface.dart';
import 'package:sekitaran/features/global_chat/value_object/message.dart';

class ChatService {
  ChatService(this._gateway);

  final ChatGatewayInterface _gateway;

  Stream<List<Message>> get chatList => _gateway.watchMessages();

  Future<void> sendChat(Message message) => _gateway.sendMessage(message);

  Future<void> dispose() => _gateway.dispose();
}
