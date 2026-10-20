import 'dart:async';

import 'package:sekitaran/features/global_chat/adapter/chat_gateway/chat_gateway_interface.dart';
import 'package:sekitaran/features/global_chat/vo/message.dart';

class FakeChatGateway implements ChatGatewayInterface {
  final List<Message> _messages = <Message>[];

  final StreamController<List<Message>> _chatListController =
      StreamController<List<Message>>.broadcast(sync: true);

  @override
  Stream<List<Message>> watchMessages() => _chatListController.stream;

  @override
  Future<void> sendMessage(Message message) async {
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

  // Kept temporarily so the current ChatService keeps compiling
  // until it is migrated to sendMessage/watchMessages.
  List<Message> getAll() => List.unmodifiable(_messages);

  void insert(Message message) {
    unawaited(sendMessage(message));
  }

  Future<void> dispose() => _chatListController.close();
}
