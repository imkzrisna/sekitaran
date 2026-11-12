import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';
import 'package:sekitaran/core/supabase_config.dart';
import 'package:sekitaran/features/auth/login_page.dart';
import 'package:sekitaran/features/store/offline/offline_store_cache.dart';

// Background notification handler.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  debugPrint(
    'Background message received: ${message.messageId}',
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 2. Register Firebase background handler.
  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // 3. Initialize local storage.
  await Hive.initFlutter();
  await OfflineStoreCache.instance.initialize();

  // 4. Initialize Supabase.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  // 5. Run application.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sekitaran',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF103D17),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android:
                FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS:
                CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LoginPage(),
    );
  }
}
