import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/auth_service.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/fake_user_profile_repository.dart';
import 'package:sekitaran/features/auth/vo/register_request_dto.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';

void main() {
  group("register test", () {
    late AuthService auth;
    late FakeUserProfileRepository userRepo;
    late FakeSessionManager session;

    setUp(() {
      userRepo = FakeUserProfileRepository();
      session = FakeSessionManager(userRepo);
      auth = AuthService(userRepo, session);
    });
    
    test("when not inputing username, password, and confirm password, should not register a new user", () async {
      await auth.registerAsync(RegisterRequestDto("", "", "", ""));
      
      expect(await userRepo.getByUsernameAsync(""), null);
    });

    test("when inputing username, password, and confirm password correctly, shoudl register user", () async {
      await auth.registerAsync(RegisterRequestDto("user1", "user1@email.com", "password", "password"));
      
      expect(await userRepo.getByUsernameAsync("user1"), isNotNull);
    });

    test("when password and confirm password do not match, should not register user", () async {
      await auth.registerAsync(RegisterRequestDto("user1", "user1@email.com", "ftom", "phigros"));
      
      expect(await userRepo.getByUsernameAsync("user1"), isNull);
    });

    test("when user already exists, should not register user", () async {
      await auth.registerAsync(RegisterRequestDto("user1", "user1@email.com", "password", "password"));
      final result = await auth.registerAsync(RegisterRequestDto("user1", "user1@email.com", "password", "password"));

      expect(result["status"], "UsernameAlreadyTaken");
    });
  });
}
