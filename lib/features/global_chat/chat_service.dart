import 'dart:async';

import 'package:sekitaran/features/global_chat/adapter/chat_gateway/chat_gateway_interface.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/session_manager_interface.dart';
import 'package:sekitaran/features/global_chat/vo/message.dart';

class ChatService {
  ChatService(this._gateway, this._session);

  final ChatGatewayInterface _gateway;
  final SessionManagerInterface _session;

  Stream<List<Message>>? get chatList => _session.currentSession != null ? _gateway.watchMessages() : null;

  Future<void> sendChat(Message message) async {
    if (_session.currentSession == null) return;

    _gateway.sendMessage(message);
  } 

  Future<void> dispose() => _gateway.dispose();
}
