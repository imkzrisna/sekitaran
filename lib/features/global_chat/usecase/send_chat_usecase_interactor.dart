import 'package:sekitaran/features/global_chat/adapter/fake_chat_gateway.dart';
import 'package:sekitaran/features/global_chat/value_object/message.dart';

class SendChatUsecaseInteractor {
  new(this.messageRepository);

  FakeChatGateway messageRepository;

}
