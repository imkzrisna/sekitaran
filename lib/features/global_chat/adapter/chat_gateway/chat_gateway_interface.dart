import 'package:sekitaran/features/global_chat/entity/message.dart';

abstract interface class ChatGatewayInterface {
  Stream<List<Message>> watchMessages();

  Future<void> sendMessage(Message message);

  Future<void> dispose();

  Future<void> deleteMessageAsync(String chatUuid);

  Future<Message?> getMessageById(String chatUuid);
}
