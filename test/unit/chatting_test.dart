import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/fake_user_profile_repository.dart';
import 'package:sekitaran/features/global_chat/adapter/chat_gateway/fake_chat_gateway.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';
import 'package:sekitaran/features/global_chat/chat_service.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';
import 'package:sekitaran/features/global_chat/status/delete_status.dart';
import 'package:uuid/uuid.dart';

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
      service = ChatService(gateway, session, userRepo);

      await session.signUpWithPasswordAsync(
        email: "email@email.com",
        password: "password",
        username: "user1",
      );

      await session.signUpWithPasswordAsync(
        email: "email2@gmail.com",
        password: "password",
        username: "user2",
      );

      await session.signInWithPasswordAsync(
        email: "email@email.com",
        password: "password",
        username: "user1",
      );
    });

    test(
      "when not sending any message, should not have message stored",
      () async {
        expect(gateway.getAll(), []);
      },
    );

    test(
      "when sending one message, message storage should not be emtpy",
      () async {
        final message = Message("hello", "user1");
        await service.sendChatAsync(message);

        expect(gateway.getAll().contains(message), true);
      },
    );

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
      await service.sendChatAsync(second);
      await pumpEventQueue();

      // then: the gateway emits a snapshot with the loaded message and the new one
      expect(
        emittedChatLists,
        isNotEmpty,
        reason: "sendChat must publish an updated chat list",
      );
      expect(emittedChatLists.last, [first, second]);
    });

    test(
      "when user is not authorized, it should not be able to send message",
      () async {
        session.signOutAsync();
        final message = Message("I'm not authorized", "unauthorizedUser");
        await service.sendChatAsync(message);

        expect(gateway.getAll(), []);
      },
    );

    test(
      "when a user enters a chat and then deletes it, chatlist should be empty",
      () async {
        final id = Uuid().v4();
        final message = Message("this will be deleted", "user1").withId(id);

        await service.sendChatAsync(message);

        final result = await service.deleteChatById(id);

        expect(result["status"], DeleteStatus.success);
        expect(gateway.getAll(), []);
      },
    );

    test("when unauthenticated user tries to delete a chat, should not delete a chat", () async {
      final id = Uuid().v4();

      await service.sendChatAsync(Message("hello", "user1").withId(id));

      session.signOutAsync();

      final result = await service.deleteChatById(id);

      expect(result["status"], isNot(DeleteStatus.success));
      expect(gateway.getAll(), isNotEmpty);
    });

    test("when trying to delete a chat that is not owned by the user. should not delete chat", () async {
      final id = Uuid().v4();

      final message = Message("hello", "user1").withId(id);
      await service.sendChatAsync(message);

      print("message id in test: $message");

      await session.signOutAsync();

      await session.signInWithPasswordAsync(
        email: "email2@gmail.com",
        password: "password",
        username: "user2",
      );

      final result = await service.deleteChatById(id);

      expect(result["status"], isNot(DeleteStatus.userIsNotAuthenticated));
      expect(result["status"], isNot(DeleteStatus.success));
      expect(result["status"], DeleteStatus.userDoesNotOwnTheMessage);
      expect(gateway.getAll(), isNotEmpty);
    });

    test(
      "when a user edits a chat, the chat should be different from the older one",
      () async {},
      skip: true,
    );

    test(
      "when an unauthenticated user tries to edit a chat, should not edit a chat",
      () async {},
      skip: true,
    );

    test(
      "when a user tries to edit chat that is not owned by them, should not edit a chat",
      () async {},
      skip: true,
    );
  });
}
