import 'dart:async';

import 'package:sekitaran/features/global_chat/adapter/session_manager/session_manager_interface.dart';
import 'package:sekitaran/features/global_chat/vo/auth_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSessionManager implements SessionManagerInterface {
  final client = Supabase.instance.client;

  AuthSession? _currentSession;

  final _sessionController = StreamController<AuthSession?>.broadcast(
    sync: true,
  );

  @override
  AuthSession? get currentSession => _currentSession ?? _fromClient();

  AuthSession? _fromClient() {
    final s = client.auth.currentSession;
    if (s == null) return null;
    final exp = s.expiresAt;
    return AuthSession(
      userId: s.user.id,
      email: s.user.email ?? '',
      accessToken: s.accessToken,
      refreshToken: s.refreshToken ?? '',
      expiresAt: exp == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(exp * 1000),
    );
  }

  @override
  Stream<AuthSession?> get sessionChanges => _sessionController.stream;

  @override
  Future<AuthSession> signInWithPasswordAsync({
    required String email,
    required String password,
  }) async {
    await client.auth.signInWithPassword(email: email, password: password);

    final currentSupabaseSession = client.auth.currentSession;

    _currentSession = AuthSession(
      userId: currentSupabaseSession!.user.id,
      email: email,
      accessToken: currentSupabaseSession.accessToken,
      refreshToken: currentSupabaseSession.refreshToken!,
      expiresAt: DateTime.now().add(
        Duration(seconds: currentSupabaseSession.expiresAt!),
      ),
    );

    _sessionController.add(_currentSession);

    return _currentSession!;
  }

  @override
  Future<void> signOutAsync() async {
    await client.auth.signOut();
    _currentSession = null;
    _sessionController.add(null);
  }

  @override
  Future<void> signUpWithPasswordAsync({
    required String email,
    required String password,
    required String username,
  }) async {
    await client.auth.signUp(
      email: email,
      password: password,
      data: {"username": username},
    );
  }
}
