import 'package:supabase_flutter/supabase_flutter.dart';

enum SignUpResult { needsOtp, signedIn }

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthService {
  AuthService._();
  static final instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<SignUpResult> signUp({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // disimpan ke profiles di akhir alur
      );
      final user = res.user;
      if (user == null) {
        throw const AuthFailure('Registrasi gagal. Silakan coba lagi.');
      }
      // Email sudah terdaftar & terverifikasi: Supabase tidak melempar error,
      // tetapi mengembalikan user dengan identities kosong.
      if (user.identities != null && user.identities!.isEmpty) {
        throw const AuthFailure('Email sudah terdaftar. Silakan login.');
      }
      return res.session == null
          ? SignUpResult.needsOtp
          : SignUpResult.signedIn;
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const AuthFailure(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    } on AuthException catch (e) {
      throw AuthFailure(_mapSignUpError(e));
    } catch (_) {
      throw const AuthFailure(
        'Terjadi kesalahan. Periksa koneksi internet lalu coba lagi.',
      );
    }
  }

  String _mapSignUpError(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'user_already_exists' || code == 'email_exists') {
      return 'Email sudah terdaftar. Silakan login.';
    }
    if (code == 'weak_password') {
      return 'Password terlalu lemah. Gunakan kombinasi huruf dan angka.';
    }
    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return 'Format email tidak valid.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit') {
      return 'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba lagi.';
    }
    if (code == 'signup_disabled') {
      return 'Pendaftaran sedang dinonaktifkan.';
    }
    if (msg.contains('database error saving new user')) {
      return 'Username tidak dapat digunakan. Coba username lain.';
    }
    return 'Registrasi gagal: ${e.message}';
  }
}
