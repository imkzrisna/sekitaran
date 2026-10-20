import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/session_manager_interface.dart';
import 'package:sekitaran/features/global_chat/vo/auth_session.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSessionManager implements SessionManagerInterface {
  new() {
    try {
      Supabase.instance.client;
    } catch (_) {
      Supabase.initialize(url: dotenv.env["SUPABASE_URL"]!, publishableKey: dotenv.env["PUBLISHABLE_KEY"]);
    }
  }

  final client = Supabase.instance.client;

  AuthSession? _currentSession;

  @override
  AuthSession? get currentSession => _currentSession;

  @override
  Stream<AuthSession?> get sessionChanges => throw UnimplementedError();

  @override
  Future<AuthSession> signInWithPassword({required String email, required String password}) async {
    await client.auth.signInWithPassword(email: email, password: password);

    final currentSupabaseSession = client.auth.currentSession;

    _currentSession = AuthSession(
      userId: currentSupabaseSession!.user.id, 
      email: email, 
      accessToken: currentSupabaseSession.accessToken, 
      refreshToken: currentSupabaseSession.refreshToken!, 
      expiresAt: DateTime.now().add(Duration(seconds: currentSupabaseSession.expiresAt!))
    );

    return _currentSession!;
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }

  @override
  Future<void> signUpWithPassword({required String email, required String password, required String username}) {
    throw UnimplementedError();
  }
}
