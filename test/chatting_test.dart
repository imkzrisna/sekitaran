import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/global_chat/adapter/fake_chat_gateway.dart';
import 'package:sekitaran/features/global_chat/usecase/chat_service.dart';
import 'package:sekitaran/features/global_chat/usecase/send_chat_usecase_interactor.dart';
import 'package:sekitaran/features/global_chat/value_object/message.dart';

void main() {
  test("when not sending any message, should not have message stored", () async {
    final gateway = FakeChatGateway();
    final service = ChatService(gateway);

    expect(gateway.getAll(), []);
  });

  test("when sending one message, message storage should not be emtpy", () async {
    final gateway = FakeChatGateway();
    final service = ChatService(gateway);

    final message = Message("hello", "user");
    await service.sendChat(message);

    expect(gateway.getAll().contains(message), true);
  });

  test("when loading one message and then send another message, it should update the chatlist", () async {
    final gateway = FakeChatGateway();
    final service = ChatService(gateway);

    final first = Message("hello", "user1");
    final second = Message("world", "user2");

    // given: one message already exists
    gateway.seed([first]);

    // observe the gateway chat list before sending
    final emittedChatLists = <List<Message>>[];
    final subscription = gateway.watchMessages().listen(emittedChatLists.add);
    addTearDown(subscription.cancel);

    // when
    await service.sendChat(second);
    await pumpEventQueue();

    // then: the gateway emits a snapshot with the loaded message and the new one
    expect(
      emittedChatLists,
      isNotEmpty,
      reason: "sendChat must publish an updated chat list",
    );
    expect(emittedChatLists.last, [first, second]);
  });
}
