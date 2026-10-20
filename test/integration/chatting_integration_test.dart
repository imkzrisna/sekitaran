import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() async {
    await Supabase.initialize(
      url: dotenv.env["SUPABASE_URLL"]!,
      publishableKey: dotenv.env["PUBLISHABLE_KEY"]!
    );
  });
}

