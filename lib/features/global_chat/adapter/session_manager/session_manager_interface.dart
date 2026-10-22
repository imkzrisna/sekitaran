import 'package:sekitaran/features/global_chat/vo/auth_session.dart';

abstract interface class SessionManagerInterface {
  AuthSession? get currentSession;
  Stream<AuthSession?> get sessionChanges;

  Future<void> signUpWithPasswordAsync({
    required String email,
    required String password,
    required String username,
  });

  Future<AuthSession> signInWithPasswordAsync({
    required String email,
    required String password,
  });

  Future<void> signOutAsync();
}
