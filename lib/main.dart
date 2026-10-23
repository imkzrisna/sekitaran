import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sekitaran/features/auth/login_page.dart';
import 'package:sekitaran/features/global_chat/scratchpad/chat_scratchpad.dart';
import 'package:sekitaran/features/wordle/wordle_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/core/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: WordlePage(),
    );
  }
}
