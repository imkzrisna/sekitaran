import 'package:sekitaran/features/auth/persistence/user_profile_repository/user_profile_repository_interface.dart';
import 'package:sekitaran/features/auth/vo/login_request_dto.dart';
import 'package:sekitaran/features/auth/vo/register_request_dto.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/fake_session_manager.dart';

class AuthService {
  new(this._repo, this._session);

  final UserProfileRepositoryInterface _repo;
  final FakeSessionManager _session;

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

    if (await _repo.getByUsernameAsync(dto.username) != null) {
      return <String, String> {
        "status": "UsernameAlreadyTaken"
      };
    }

    await _session.signUpWithPassword(email: dto.email, password: dto.password, username: dto.username);

    return <String, String> {
      "status": "Success"
    };
  }

  Future<Map<String, String>> loginAsync(LoginRequestDto dto) async {
    if (dto.username == "" || dto.password == "") {
      return {
        "status": "EmptyInputField"
      };
    }

    final user = await _repo.getByUsernameAsync(dto.username);

    if (user == null) {
      return {
        "status": "UserNotFound"
      };
    }

    await _session.signInWithPassword(email: user.email, password: dto.password);

    return {
      "status": "Success"
    };
  }
}
