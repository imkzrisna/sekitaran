import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Satu akun yang diizinkan login dengan sidik jari di perangkat ini.
class BiometricAccount {
  const BiometricAccount({
    required this.uid,
    required this.identifier,
    required this.password,
    required this.username,
    this.role,
  });

  final String uid;
  final String identifier;
  final String password;
  final String username;
  final String? role;

  String get roleLabel => switch (role) {
    'business' => 'Business Owner',
    'regular' => 'Regular',
    _ => '',
  };

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'identifier': identifier,
    'password': password,
    'username': username,
    'role': role,
  };

  static BiometricAccount? fromJson(Object? j) {
    if (j is! Map) return null;
    final uid = j['uid'];
    final identifier = j['identifier'];
    final password = j['password'];
    final username = j['username'];
    if (uid is! String ||
        identifier is! String ||
        password is! String ||
        username is! String) {
      return null;
    }
    final role = j['role'];
    return BiometricAccount(
      uid: uid,
      identifier: identifier,
      password: password,
      username: username,
      role: role is String ? role : null,
    );
  }
}

/// Login sidik jari: sidik jari diperiksa lewat local_auth, kredensial tiap
/// akun disimpan terenkripsi (Keystore/Keychain) lewat flutter_secure_storage.
class BiometricService {
  BiometricService._();
  static final instance = BiometricService._();

  static const _kAccounts = 'bio_accounts';
  // Kunci lama (satu slot per HP), dihapus saat pertama kali dibaca.
  static const _kLegacyId = 'bio_identifier';
  static const _kLegacyPw = 'bio_password';

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

  Future<List<BiometricAccount>> accounts() async {
    try {
      await _storage.delete(key: _kLegacyId);
      await _storage.delete(key: _kLegacyPw);
      final raw = await _storage.read(key: _kAccounts);
      if (raw == null || raw.isEmpty) return const [];
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.map(BiometricAccount.fromJson).whereType<BiometricAccount>().toList();
    } catch (_) {
      return const [];
    }
  }

  Future<bool> hasAccount(String uid) async =>
      (await accounts()).any((a) => a.uid == uid);

  Future<void> _write(List<BiometricAccount> list) async {
    if (list.isEmpty) {
      await _storage.delete(key: _kAccounts);
    } else {
      await _storage.write(
        key: _kAccounts,
        value: jsonEncode(list.map((a) => a.toJson()).toList()),
      );
    }
  }

  /// Menambah akun, atau memperbarui jika akun itu sudah ada.
  Future<void> saveAccount(BiometricAccount account) async {
    final list = (await accounts()).where((a) => a.uid != account.uid).toList()
      ..add(account);
    await _write(list);
  }

  Future<void> removeAccount(String uid) async {
    final list = (await accounts()).where((a) => a.uid != uid).toList();
    await _write(list);
  }
}
