import 'package:sekitaran/features/global_chat/value_object/message.dart';

abstract interface class ChatGatewayInterface {
  Stream<List<Message>> watchMessages();

  Future<void> sendMessage(Message message);

  Future<void> dispose();
}
