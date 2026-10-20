import 'package:uuid/uuid.dart';

class UserProfile {
  new(this.username, this.email);

  Uuid userId = Uuid(); 
  String username = "";
  String email = "";
  String avatarUrl = "";
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  String fullName = "";
  String role = "";

  UserProfile withId(Uuid id) {
    final profile = UserProfile(username, email);

    profile.userId = id;

    return profile;
  }

  UserProfile withAvatarUrl(String url) {
    final profile = UserProfile(username, email);

    profile.avatarUrl = url;

    return profile;
  }

  UserProfile withRole(String role) {
    final profile = UserProfile(username, email);

    profile.role = role;

    return profile;
  }

  UserProfile withFullName(String fullName) {
    final profile = UserProfile(username, email);

    profile.fullName = fullName;

    return profile;
  }
}
