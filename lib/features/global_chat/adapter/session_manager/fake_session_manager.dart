import 'dart:async';

import 'package:sekitaran/features/auth/entity/user.dart';
import 'package:sekitaran/features/auth/persistence/user_repository/user_profile_repository_interface.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/session_manager_interface.dart';
import 'package:sekitaran/features/global_chat/value_object/auth_session.dart';

class FakeSessionManager implements SessionManagerInterface {
  new(this.repo);

  UserProfileRepositoryInterface repo;

  final StreamController<AuthSession?> _streamController =
      StreamController<AuthSession?>.broadcast(sync: true);

  AuthSession? _currentSession;

  @override
  AuthSession? get currentSession => _currentSession;

  @override
  Stream<AuthSession?> get sessionChanges => _streamController.stream;

  @override
  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final session = AuthSession(
      userId: email,
      email: email,
      accessToken: 'fake-access-token',
      refreshToken: 'fake-refresh-token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );

    _currentSession = session;
    _streamController.add(session);
    return session;
  }

  @override
  Future<void> signUpWithPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    repo.insertAsync(User(username, email, password));
  }

  @override
  Future<void> signOut() async {
    _currentSession = null;
    _streamController.add(null);
  }
}
