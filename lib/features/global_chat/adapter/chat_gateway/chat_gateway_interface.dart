import 'package:sekitaran/features/global_chat/entity/message.dart';

abstract interface class ChatGatewayInterface {
  Stream<List<Message>> watchMessages();

  Future<void> sendMessageAsync(Message message);

  Future<void> dispose();

  Future<void> deleteMessageAsync(String chatUuid);

  Future<Message?> getMessageByIdAsync(String chatUuid);

  Future<void> editMessageByIdAsync(String chatUuid, Message newMessage);
}
