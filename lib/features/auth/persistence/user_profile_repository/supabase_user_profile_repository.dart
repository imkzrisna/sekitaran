import 'package:sekitaran/features/auth/entity/user_profile.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/user_profile_repository_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUserProfileRepository implements UserProfileRepositoryInterface {
  final SupabaseClient client = Supabase.instance.client;

  @override
  Future<List<UserProfile>> getAllAsync() async {
    final queried = await client
      .from("profiles")
      .select("*");

    return queried
      .map((profile) => UserProfile(profile["username"])
        .withId(profile["id"])
        .withAvatarUrl(profile["avatar_url"] ?? "")
        .withRole(profile["role"] ?? "")
        .withFullName(profile["full_name"] ?? ""))
      .toList();
  }

  @override
  Future<UserProfile?> getByUsernameAsync(String username) async {
    final query = await client
      .from("profiles")
      .select("*")
      .eq("username", username);

    final userProfile = query
      .map((profile) =>
        UserProfile(profile["username"])
          .withId(profile["id"])
          .withAvatarUrl(profile["avatar_url"] ?? "")
          .withFullName(profile["full_name"] ?? "")
          .withRole(profile["role"] ?? "")
      )
      .firstOrNull;

    return userProfile;
  }

  @override
  Future<void> insertAsync(UserProfile user) async {
    await client
      .from("profiles")
      .insert({
        "username": user.username,
        "avatar_url": user.avatarUrl,
        "full_name": user.fullName,
        "created_at": DateTime.now(),
        "updated_at": DateTime.now()
      });
  }

  @override
  Future<UserProfile?> getByIdAsync(String id) async {
    final queried = await client
      .from("profiles")
      .select("*")
      .eq("id", id);

    return queried.map((profile) => UserProfile(profile["username"])
      .withId(profile["id"])
      .withFullName(profile["full_name"] ?? "")
      .withRole(profile["role"] ?? "")
      .withAvatarUrl(profile["avatar_url"] ?? "")).firstOrNull;
  }
}
