import 'dart:convert';

import 'package:crypto/crypto.dart';
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
      if (!await isUsernameAvailable(username)) {
        throw const AuthFailure('Username sudah dipakai. Coba username lain.');
      }

      final hashedPassword = sha256.convert(utf8.encode(password)).toString();

      final res = await _client.auth.signUp(
        email: email,
        password: hashedPassword,
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

  Future<bool> isUsernameAvailable(String username) async {
    final res = await _client.rpc(
      'is_username_available',
      params: {'p_username': username},
    );
    return res == true;
  }

  Future<void> verifySignupOtp({
    required String email,
    required String token,
  }) async {
    try {
      final res = await _client.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: token,
      );
      if (res.session == null) {
        throw const AuthFailure('Verifikasi gagal. Silakan coba lagi.');
      }
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const AuthFailure('Tidak dapat terhubung ke server.');
    } on AuthException catch (e) {
      final code = e.code ?? '';
      if (code == 'over_request_rate_limit') {
        throw const AuthFailure('Terlalu banyak percobaan. Tunggu sebentar.');
      }
      // Supabase memakai kode yang sama untuk OTP salah dan kedaluwarsa.
      throw const AuthFailure('Kode salah atau sudah kedaluwarsa.');
    } catch (_) {
      throw const AuthFailure('Terjadi kesalahan. Periksa koneksi internet.');
    }
  }

  Future<void> resendSignupOtp(String email) async {
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
    } on AuthRetryableFetchException {
      throw const AuthFailure('Tidak dapat terhubung ke server.');
    } on AuthException catch (e) {
      final code = e.code ?? '';
      if (code == 'over_email_send_rate_limit' ||
          code == 'over_request_rate_limit') {
        throw const AuthFailure(
          'Terlalu cepat. Tunggu sebentar sebelum meminta kode baru.',
        );
      }
      throw AuthFailure('Gagal mengirim ulang kode: ${e.message}');
    } catch (_) {
      throw const AuthFailure('Terjadi kesalahan. Periksa koneksi internet.');
    }
  }

  /// Membuat baris profil setelah email terverifikasi (dipanggil di
  /// AccountCreatedPage). Upsert per id, jadi aman dipanggil ulang dan
  /// tidak menimpa kolom role.
  Future<void> ensureProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthFailure('Sesi tidak ditemukan. Silakan daftar ulang.');
    }
    final username = (user.userMetadata?['username'] as String?)?.trim();
    if (username == null || username.isEmpty) {
      throw const AuthFailure('Data username tidak ditemukan.');
    }
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'username': username,
      }, onConflict: 'id');
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AuthFailure('Username sudah dipakai orang lain.');
      }
      throw AuthFailure('Gagal menyimpan profil: ${e.message}');
    } catch (_) {
      throw const AuthFailure('Gagal menyimpan profil. Periksa koneksi.');
    }
  }

  Future<void> saveRole(String role) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const AuthFailure('Sesi berakhir. Silakan masuk kembali.');
    }
    try {
      final rows = await _client
          .from('profiles')
          .update({'role': role})
          .eq('id', uid)
          .select();
      if (rows.isEmpty) {
        throw const AuthFailure('Profil belum tersedia.');
      }
    } on AuthFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw AuthFailure('Gagal menyimpan role: ${e.message}');
    } catch (_) {
      throw const AuthFailure('Gagal menyimpan role. Periksa koneksi.');
    }
  }

  /// [identifier] boleh username atau email.
  Future<void> signIn({
    required String identifier,
    required String password,
  }) async {
    try {
      var email = identifier.trim();
      if (!email.contains('@')) {
        final res = await _client.rpc(
          'get_login_email',
          params: {'p_username': email},
        );
        if (res is! String || res.isEmpty) {
          // Pesan sama dengan password salah, agar username tidak bisa ditebak.
          throw const AuthFailure('Username atau password salah.');
        }
        email = res;
      }

      final hashedPassword = sha256.convert(utf8.encode(password)).toString();

      await _client.auth.signInWithPassword(
        email: email,
        password: hashedPassword,
      );
    } on AuthFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const AuthFailure(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    } on AuthException catch (e) {
      throw AuthFailure(_mapSignInError(e));
    } on PostgrestException {
      throw const AuthFailure('Gagal memeriksa akun. Coba lagi.');
    } catch (_) {
      throw const AuthFailure(
        'Terjadi kesalahan. Periksa koneksi internet lalu coba lagi.',
      );
    }
  }

  String _mapSignInError(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Username/email atau password salah.';
      case 'email_not_confirmed':
        return 'Email belum diverifikasi. Selesaikan verifikasi kode terlebih dahulu.';
      case 'over_request_rate_limit':
        return 'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba lagi.';
      case 'user_banned':
        return 'Akun ini dinonaktifkan.';
    }
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Username/email atau password salah.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email belum diverifikasi. Selesaikan verifikasi kode terlebih dahulu.';
    }
    return 'Login gagal: ${e.message}';
  }

  /// null = baris profil belum ada.
  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      return await _client
          .from('profiles')
          .select('username, role')
          .eq('id', uid)
          .maybeSingle();
    } on PostgrestException catch (e) {
      throw AuthFailure('Gagal memuat profil: ${e.message}');
    } catch (_) {
      throw const AuthFailure('Gagal memuat profil. Periksa koneksi.');
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
