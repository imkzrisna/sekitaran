import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static const AndroidNotificationChannel _commentsChannel =
      AndroidNotificationChannel(
        'comments',
        'Komentar Toko',
        description: 'Notifikasi komentar baru pada toko Anda.',
        importance: Importance.high,
      );

  final FirebaseMessaging _messaging;
  final SupabaseClient _supabase;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _installationId;

  bool _initialized = false;
  bool _localNotificationsInitialized = false;
  bool _shouldRegisterDevice = false;

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

  /// Menyiapkan plugin notifikasi lokal.
  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    final initialized = await _localNotifications.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Local notification opened: ${response.payload}');
      },
    );

    if (initialized != true) {
      throw StateError('Local notification initialization failed.');
    }

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(_commentsChannel);
    await androidPlugin?.requestNotificationsPermission();

    _localNotificationsInitialized = true;

    debugPrint('Local notifications initialized successfully.');
  }

  /// Menampilkan notifikasi ketika aplikasi sedang terbuka.
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title;
    final body = message.notification?.body;

    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      debugPrint('Foreground message has no notification content.');
      return;
    }

    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'comments',
        'Komentar Toko',
        channelDescription: 'Notifikasi komentar baru pada toko Anda.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localNotifications.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title ?? 'Komentar Baru',
      body: body ?? '',
      notificationDetails: notificationDetails,
      payload: message.data.toString(),
    );

    debugPrint('Foreground notification displayed.');
  }

  /// Menyimpan FID secara lokal dan menyinkronkannya ke Supabase.
  Future<void> _saveInstallationId(String installationId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint('Device registration skipped: user is not logged in.');
      return;
    }

    if (!_shouldRegisterDevice) {
      debugPrint(
        'Device registration skipped: current role is not Business Owner.',
      );
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
      }, onConflict: 'token,user_id');

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
    _foregroundSubscription ??= FirebaseMessaging.onMessage.listen((
      message,
    ) async {
      debugPrint('Notification title: ${message.notification?.title}');
      debugPrint('Notification body: ${message.notification?.body}');
      debugPrint('Notification data: ${message.data}');

      try {
        await _showForegroundNotification(message);
      } catch (error) {
        debugPrint('Failed to display foreground notification: $error');
      }
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
  ///
  /// registerDevice = true  : Business Owner.
  /// registerDevice = false : Regular User.
  Future<void> initialize({bool registerDevice = true}) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      debugPrint('Push notification skipped: user is not logged in.');
      return;
    }

    // Perbarui role setiap kali akun login.
    _shouldRegisterDevice = registerDevice;

    final permissionGranted = await requestPermission();

    if (!permissionGranted) {
      debugPrint('Notification permission was not granted.');
      return;
    }

    try {
      // Listener dan notifikasi lokal cukup diinisialisasi satu kali.
      if (!_initialized) {
        await _initializeLocalNotifications();

        _listenRegistration();
        _listenForegroundMessages();
        _listenNotificationTap();

        _initialized = true;
      }

      if (!registerDevice) {
        debugPrint(
          'Notification listener active for Regular User. '
          'Device registration unchanged.',
        );
        return;
      }

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
      debugPrint('Firebase Messaging initialization failed: $error');
    }
  }

  /// Menghapus registrasi perangkat dari akun yang sedang logout.
  /// Tidak dipanggil pada proses logout normal.
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
