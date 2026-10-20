import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/entity/user_profile.dart';
import 'package:sekitaran/features/auth/persistence/user_repository/supabase_user_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
   
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(url: dotenv.env["SUPABASE_URL"]!, publishableKey: dotenv.env["PUBLISHABLE_KEY"]);
  
    await Supabase.instance.client.auth.signInWithPassword(
      email: dotenv.env["INTEGRATION_TEST_EMAIL"], 
      password: dotenv.env["INTEGRATION_TEST_PASSWORD"]!
    );

  });

  tearDownAll(() {
    Supabase.instance.client.auth.signOut();
  });
  
  group("supabase userprofile repository test", () { 
    test("when inserting new profile, table should not be empty", () async {
      final repo = SupabaseUserProfileRepository();

      repo.insertAsync(UserProfile("user1"));

      expect(await repo.getAllAsync(), isNot([]));
    });
  });
}
