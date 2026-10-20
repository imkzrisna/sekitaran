import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sekitaran/features/auth/entity/user.dart';
import 'package:sekitaran/features/auth/persistence/fake_user_repository.dart';
import 'package:sekitaran/features/auth/value_object/login_request_dto.dart';
import 'package:sekitaran/features/auth/value_object/register_request_dto.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';

class AuthService {
  new(this.repo, this.session);

  FakeUserRepository repo;
  FakeSessionManager session;

  Future<void> registerAsync(RegisterRequestDto dto) async {
    if (dto.username.isEmpty || dto.password.isEmpty || dto.confirmPassword.isEmpty) return;

    if (dto.password != dto.confirmPassword) return;

    if (await repo.getByUsernameAsync(dto.username) != null) return;

    final passwordHash = sha256.convert(utf8.encode(dto.password)).toString();

    await repo.insertAsync(User(dto.username, passwordHash));
  }

  Future<void> login(LoginRequestDto dto) async {
    if (dto.username == "" || dto.password == "") return;

    final user = await repo.getByUsernameAsync(dto.username);

    if (user == null) return;

    final passwordHash = sha256.convert(utf8.encode(dto.password)).toString();

    if (user.passwordHash == passwordHash) {
      session.sessionValue["username"] = user.username;
    }
  }
}
