import 'package:uuid/uuid.dart';

class UserProfile {
  new(this.username);

  String userId = Uuid().v4(); 
  String username = "";
  String email = "";
  String avatarUrl = "";
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();
  String fullName = "";
  String role = "";

  UserProfile withId(String id) {
    userId = id;

    return this;
  }

  UserProfile withAvatarUrl(String url) {
    avatarUrl = url;

    return this;
  }

  UserProfile withRole(String role) {
    this.role = role;

    return this;
  }

  UserProfile withFullName(String fullName) {
    this.fullName = fullName;

    return this;
  }

  UserProfile withEmail(String email) {
    this.email = email;

    return this;
  }
}
