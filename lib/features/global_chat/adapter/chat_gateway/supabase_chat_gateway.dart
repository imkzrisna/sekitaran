import 'package:sekitaran/features/global_chat/adapter/chat_gateway/chat_gateway_interface.dart';
import 'package:sekitaran/features/global_chat/value_object/message.dart';

class SupabaseChatGateway implements ChatGatewayInterface {
  @override
  Future<void> dispose() {
    throw UnimplementedError();
  }

  @override
  Future<void> sendMessage(Message message) {
    throw UnimplementedError();
  }

  @override
  Stream<List<Message>> watchMessages() {
    throw UnimplementedError();
  }
}
