import 'package:sekitaran/features/global_chat/vo/message.dart';

abstract interface class ChatGatewayInterface {
  Stream<List<Message>> watchMessages();

  Future<void> sendMessage(Message message);

  Future<void> dispose();
}
