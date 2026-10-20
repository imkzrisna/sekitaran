import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/auth_service.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/fake_user_profile_repository.dart';
import 'package:sekitaran/features/auth/vo/login_request_dto.dart';
import 'package:sekitaran/features/auth/vo/register_request_dto.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';

void main() {
  group("login test", () {
    late FakeUserProfileRepository repo;
    late FakeSessionManager session;
    late AuthService auth;

    setUp(() {
      repo = FakeUserProfileRepository();
      session = FakeSessionManager(repo);
      auth = AuthService(repo, session);
    });
    
    test("when not providing any credential, should not logged the user in", () async {
      await auth.registerAsync(RegisterRequestDto("user1", "user1@email.com", "password", "password"));

      await auth.loginAsync(LoginRequestDto("", ""));

      expect(session.currentSession, isNull);
    });

    test("when username or password is correct, should logged the user in", () async {
      await auth.registerAsync(RegisterRequestDto("user1", "user1@email.com", "password", "password"));

      final result = await auth.loginAsync(LoginRequestDto("user1", "password"));

      expect(result["status"], "Success");
      expect(session.currentSession, isNotNull);
    });

    test("when user does not exists, should not logged the user in", () async { 
      await auth.loginAsync(LoginRequestDto("user1", "password"));

      expect(session.currentSession, isNull);
    });

    test("when username or password is correct, should set the current user as the logged in user", () async {
      await auth.registerAsync(RegisterRequestDto("user1", "user1@gmail.com", "password", "password"));

      final result = await auth.loginAsync(LoginRequestDto("user1", "password"));

      expect(result["status"], "Success");
      expect(session.currentSession, isNotNull);
      expect(session.currentSession!.email, "user1@gmail.com");
    });
  });
}
