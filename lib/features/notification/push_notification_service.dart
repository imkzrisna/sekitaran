import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PushNotificationService {
  PushNotificationService({
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// Meminta izin notifikasi.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    return settings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        settings.authorizationStatus ==
            AuthorizationStatus.provisional;
  }

  /// Memeriksa kesiapan APNs pada perangkat Apple.
  Future<bool> _isPlatformReady() async {
    if (kIsWeb) return true;

    if (Platform.isIOS || Platform.isMacOS) {
      final apnsToken = await _messaging.getAPNSToken();
      return apnsToken != null;
    }

    return true;
  }

  /// Mendengarkan Firebase Installation ID.
  void listenRegistration() {
    _messaging.onRegistered.listen(
      (installationId) {
        debugPrint('Firebase Installation ID: $installationId');
      },
      onError: (error) {
        debugPrint('Registration error: $error');
      },
    );
  }

  /// Mendengarkan pesan saat aplikasi terbuka.
  void listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint(
        'Notification title: ${message.notification?.title}',
      );

      debugPrint(
        'Notification body: ${message.notification?.body}',
      );

      debugPrint(
        'Notification data: ${message.data}',
      );
    });
  }

  /// Menangani notifikasi yang ditekan pengguna.
  void listenNotificationTap() {
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('Notification opened: ${message.data}');
    });
  }

  /// Memeriksa pesan yang membuka aplikasi dari kondisi terminated.
  Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  /// Menginisialisasi layanan notifikasi.
  Future<void> initialize() async {
    final permissionGranted = await requestPermission();

    if (!permissionGranted) {
      debugPrint('Notification permission was not granted.');
      return;
    }

    final platformReady = await _isPlatformReady();

    if (!platformReady) {
      debugPrint('APNs token is not available yet.');
      return;
    }

    // Subscribe before registration to avoid missing the event.
    listenRegistration();

    listenForegroundMessages();
    listenNotificationTap();

    // Register app instance with Firebase.
    await _messaging.register();
  }
}
