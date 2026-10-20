import 'package:sekitaran/features/auth/entity/user_profile.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/user_profile_repository_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUserProfileRepository implements UserProfileRepositoryInterface {
  final SupabaseClient client = Supabase.instance.client;

  @override
  Future<List<UserProfile>> getAllAsync() async {
    final profileQuery = await client
      .from("profiles")
      .select("*")
      .order("id");

    final userQuery = await client
      .from("auth.users")
      .select("*")
      .order("id");

    List<UserProfile> profiles = [];

    for (var profile in profileQuery) {
      for (var user in userQuery) {
        profiles.add(UserProfile(profile["username"]));
      }
    }

    return profiles;
  }

  @override
  Future<UserProfile?> getByUsernameAsync(String username) async {
    final query = await client
      .from("profiles")
      .select("*")
      .eq("username", username);

    return query
      .map((profile) => UserProfile(profile["username"])
        .withId(profile["id"])
        .withAvatarUrl(profile["avatarUrl"]))
      .firstOrNull;
  }

  @override
  Future<void> insertAsync(UserProfile user) async {
    
  }
}
