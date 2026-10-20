import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sekitaran/features/auth/entity/user.dart';
import 'package:sekitaran/features/auth/persistence/user_repository/user_profile_repository_interface.dart';
import 'package:sekitaran/features/auth/value_object/login_request_dto.dart';
import 'package:sekitaran/features/auth/value_object/register_request_dto.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';

class AuthService {
  new(this.repo, this.session);

  UserProfileRepositoryInterface repo;
  FakeSessionManager session;

  Future<Map<String, String>> registerAsync(RegisterRequestDto dto) async {
    if (dto.email.isEmpty || dto.password.isEmpty || dto.confirmPassword.isEmpty) {
      return <String, String>{
        "status": "EmptyInputField"
      };
    }

    if (dto.password != dto.confirmPassword) {
      return <String, String>{
        "status": "PasswordDontMatch"
      };
    }

    if (await repo.getByUsernameAsync(dto.username) != null) {
      return <String, String> {
        "status": "UsernameAlreadyTaken"
      };
    }

    final passwordHash = sha256.convert(utf8.encode(dto.password)).toString();

    await session.signUpWithPassword(email: dto.email, password: passwordHash, username: dto.username);

    return <String, String> {
      "status": "Success"
    };
  }

  Future<void> login(LoginRequestDto dto) async {
    if (dto.username == "" || dto.password == "") return;

    final user = await repo.getByUsernameAsync(dto.username);

    if (user == null) return;

    final passwordHash = sha256.convert(utf8.encode(dto.password)).toString();

    if (user.passwordHash == passwordHash) {
      session.signInWithPassword(email: user.email, password: dto.password);
    }
  }
}
