import 'package:sekitaran/features/global_chat/value_object/auth_session.dart';

abstract interface class SessionManagerInterface {
  AuthSession? get currentSession;
  Stream<AuthSession?> get sessionChanges;

  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String username,
  });

  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
