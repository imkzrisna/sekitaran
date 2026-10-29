import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sekitaran/features/assistant/business_assistant_page.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/core/supabase_config.dart';
import 'package:sekitaran/features/auth/login_page.dart';
import 'package:sekitaran/features/store/offline/offline_store_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local storage.
  await Hive.initFlutter();
  await OfflineStoreCache.instance.initialize();

  // Initialize Supabase as before.
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF103D17)),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const LoginPage(),
    );
  }
}
