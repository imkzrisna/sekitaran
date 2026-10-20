import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sekitaran/features/auth/create_account_page.dart';
import 'package:sekitaran/features/global_chat/scratchpad/chat_scratchpad.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  
  Supabase.initialize(
    url: dotenv.env["SUPABASE_URL"]!,
    publishableKey: dotenv.env["PUBLISHABLE_KEY"]
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
      ),
      home: ChatScratchpad()
    );
  }
}
