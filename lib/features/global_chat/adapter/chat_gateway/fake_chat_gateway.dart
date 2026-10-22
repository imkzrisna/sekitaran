import 'dart:async';

import 'package:sekitaran/features/global_chat/adapter/chat_gateway/chat_gateway_interface.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';

class FakeChatGateway implements ChatGatewayInterface {
  List<Message> _messages = <Message>[];

  final StreamController<List<Message>> _chatListController =
      StreamController<List<Message>>.broadcast(sync: true);

  @override
  Stream<List<Message>> watchMessages() => _chatListController.stream;

  @override
  Future<void> sendMessageAsync(Message message) async {
    _messages.add(message);
    _publish();
  }

  void seed(List<Message> seeded) {
    _messages.addAll(seeded);
    _publish();
  }

  void _publish() {
    _chatListController.add(List.unmodifiable(_messages));
  }

  List<Message> getAll() => List.unmodifiable(_messages);

  @override
  Future<void> dispose() => _chatListController.close();

  @override
  Future<void> deleteMessageAsync(String chatUuid) async {
    _messages.removeWhere((message) => message.id == chatUuid);
  }

  @override
  Future<Message?> getMessageByIdAsync(String chatUuid) async {
    return _messages.where((message) => message.id == chatUuid).firstOrNull;
  }

  @override
  Future<void> editMessageByIdAsync(String chatUuid, Message newMessage) async {
    final index = _messages.indexWhere((message) => message.id == chatUuid);
    if (index != -1) {
      _messages[index] = newMessage;
      _publish();
    }
  }
}
