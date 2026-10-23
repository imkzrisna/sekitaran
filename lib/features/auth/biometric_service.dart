import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Login sidik jari: memeriksa sidik jari lewat local_auth, lalu menyimpan
/// kredensial terenkripsi (Keystore/Keychain) lewat flutter_secure_storage.
class BiometricService {
  BiometricService._();
  static final instance = BiometricService._();

  static const _kId = 'bio_identifier';
  static const _kPw = 'bio_password';

  final _auth = LocalAuthentication();
  final _storage = const FlutterSecureStorage();

  /// true jika perangkat punya sensor dan sudah ada sidik jari terdaftar.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Menampilkan prompt sidik jari bawaan sistem. true jika berhasil.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<String?> _read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasCredentials() async =>
      await _read(_kId) != null && await _read(_kPw) != null;

  Future<({String identifier, String password})?> readCredentials() async {
    final id = await _read(_kId);
    final pw = await _read(_kPw);
    if (id == null || pw == null) return null;
    return (identifier: id, password: pw);
  }

  Future<void> saveCredentials({
    required String identifier,
    required String password,
  }) async {
    await _storage.write(key: _kId, value: identifier);
    await _storage.write(key: _kPw, value: password);
  }

  Future<void> clear() async {
    try {
      await _storage.delete(key: _kId);
      await _storage.delete(key: _kPw);
    } catch (_) {}
  }
}
