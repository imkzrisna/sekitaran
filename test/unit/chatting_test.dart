import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/persistence/user_repository/fake_user_profile_repository.dart';
import 'package:sekitaran/features/global_chat/adapter/chat_gateway/fake_chat_gateway.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';
import 'package:sekitaran/features/global_chat/chat_service.dart';
import 'package:sekitaran/features/global_chat/value_object/message.dart';

void main() {
  group("chatting test", () {
    late FakeChatGateway gateway;
    late ChatService service;
    late FakeSessionManager session;
    late FakeUserProfileRepository userRepo;

    setUp(() async {
      gateway = FakeChatGateway();
      userRepo = FakeUserProfileRepository();
      session = FakeSessionManager(userRepo);
      service = ChatService(gateway, session);

      session.signInWithPassword(email: "email@email.com", password: "password");
    });

    test("when not sending any message, should not have message stored", () async {
      expect(gateway.getAll(), []);
    });

    test("when sending one message, message storage should not be emtpy", () async {
      final message = Message("hello", "user1");
      await service.sendChat(message);

      expect(gateway.getAll().contains(message), true);
    });

    test("when loading one message and then send another message, it should update the chatlist", () async {
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

    test("when user is not authorized, it should not be able to send message", () async { 
      session.signOut();
      final message = Message("I'm not authorized", "unauthorizedUser");
      await service.sendChat(message);

      expect(gateway.getAll(), []);
    });
  });
}
