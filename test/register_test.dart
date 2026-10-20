import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/auth_service.dart';
import 'package:sekitaran/features/auth/persistence/fake_user_repository.dart';
import 'package:sekitaran/features/auth/value_object/register_request_dto.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';

void main() {
  late AuthService auth;
  late FakeUserRepository userRepo;
  late FakeSessionManager session;

  setUp(() {
    userRepo = FakeUserRepository();
    session = FakeSessionManager();
    auth = AuthService(userRepo, session);
  });
  
  test("when not inputing username, password, and confirm password, should not register a new user", () async {
    await auth.registerAsync(RegisterRequestDto("", "", ""));
    
    expect(await userRepo.getAllAsync(), []);
  });

  test("when inputing username, password, and confirm password correctly, shoudl register user", () async {
    await auth.registerAsync(RegisterRequestDto("user1", "password", "password"));
    
    expect(await userRepo.getAllAsync(), isNotEmpty);
  });

  test("when password and confirm password do not match, should not register user", () async {
    await auth.registerAsync(RegisterRequestDto("user1", "ftom", "phigros"));
    
    expect(await userRepo.getAllAsync(), isEmpty);
  });

  test("when registering a user, the password should be hashed", () async {
    await auth.registerAsync(RegisterRequestDto("user1", "password", "password"));

    final queriedUser = await userRepo.getByUsernameAsync("user1");

    expect(queriedUser!.passwordHash, isNot("password"));
  });

  test("when user already exists, should not register user", () async {
    await auth.registerAsync(RegisterRequestDto("user1", "password", "password"));
    await auth.registerAsync(RegisterRequestDto("user1", "password", "password"));

    final queriedAllUser = await userRepo.getAllAsync();

    expect(queriedAllUser.length, 1);
  });
}
