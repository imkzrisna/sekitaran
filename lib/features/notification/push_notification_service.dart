import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
    SupabaseClient? supabase,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _supabase = supabase ?? Supabase.instance.client;

  static final PushNotificationService instance = PushNotificationService();

  static const String _installationIdKey = 'sekitaran_firebase_installation_id';

  final FirebaseMessaging _messaging;
  final SupabaseClient _supabase;

  String? _installationId;
  bool _initialized = false;

  StreamSubscription<String>? _registrationSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  /// Meminta izin notifikasi.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Menentukan platform perangkat.
  String get _platform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  /// Menyimpan FID secara lokal dan menyinkronkannya ke Supabase.
  Future<void> _saveInstallationId(String installationId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint('Device registration skipped: user is not logged in.');
      return;
    }

    _installationId = installationId;

    try {
      final preferences = await SharedPreferences.getInstance();

      await preferences.setString(_installationIdKey, installationId);

      await _supabase.from('device_tokens').upsert({
        'token': installationId,
        'user_id': user.id,
        'platform': _platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');

      debugPrint('Device registration synchronized successfully.');
    } catch (error) {
      debugPrint('Failed to synchronize device registration: $error');
    }
  }

  /// Mendengarkan registrasi Firebase.
  void _listenRegistration() {
    _registrationSubscription ??= _messaging.onRegistered.listen(
      (installationId) async {
        debugPrint('Firebase Installation ID received.');
        await _saveInstallationId(installationId);
      },
      onError: (error) {
        debugPrint('Firebase registration error: $error');
      },
    );
  }

  /// Mendengarkan pesan ketika aplikasi terbuka.
  void _listenForegroundMessages() {
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((message) {
      debugPrint('Notification title: ${message.notification?.title}');
      debugPrint('Notification body: ${message.notification?.body}');
      debugPrint('Notification data: ${message.data}');
    });
  }

  /// Menangani notifikasi yang dibuka pengguna.
  void _listenNotificationTap() {
    _openedSubscription ??= FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      debugPrint('Notification opened: ${message.data}');
    });
  }

  /// Mengambil pesan yang membuka aplikasi dari kondisi terminated.
  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  /// Menginisialisasi notifikasi setelah pengguna login.
  Future<void> initialize() async {
    if (_initialized) return;

    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint('Push notification skipped: user is not logged in.');
      return;
    }

    final permissionGranted = await requestPermission();

    if (!permissionGranted) {
      debugPrint('Notification permission was not granted.');
      return;
    }

    _listenRegistration();
    _listenForegroundMessages();
    _listenNotificationTap();

    _initialized = true;

    try {
      // Sinkronkan FID yang tersimpan ketika aplikasi dibuka kembali.
      final preferences = await SharedPreferences.getInstance();

      final savedInstallationId = preferences.getString(_installationIdKey);

      if (savedInstallationId != null) {
        await _saveInstallationId(savedInstallationId);
      }

      // Mendaftarkan instance aplikasi ke Firebase.
      await _messaging.register();

      debugPrint('Firebase Messaging registration requested.');
    } catch (error) {
      _initialized = false;
      debugPrint('Firebase Messaging initialization failed: $error');
    }
  }

  /// Menghapus registrasi perangkat dari akun yang sedang logout.
  /// FID lokal tetap disimpan agar dapat digunakan kembali saat login.
  Future<void> removeCurrentDeviceToken() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    try {
      final preferences = await SharedPreferences.getInstance();

      final installationId =
          _installationId ?? preferences.getString(_installationIdKey);

      if (installationId == null) {
        debugPrint('No saved device registration found.');
        _initialized = false;
        return;
      }

      await _supabase
          .from('device_tokens')
          .delete()
          .eq('token', installationId)
          .eq('user_id', user.id);

      _installationId = installationId;
      _initialized = false;

      debugPrint('Device registration removed from current account.');
    } catch (error) {
      debugPrint('Failed to remove device registration: $error');
    }
  }

  /// Melepas listener ketika service benar-benar tidak digunakan.
  Future<void> dispose() async {
    await _registrationSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();

    _registrationSubscription = null;
    _foregroundSubscription = null;
    _openedSubscription = null;

    _initialized = false;
  }
}
