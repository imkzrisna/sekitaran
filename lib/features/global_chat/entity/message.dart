import 'package:uuid/uuid.dart';

class Message {
  String id = Uuid().v4();
  String username;
  String message;
  String avatarUrl = "";

  new(this.message, this.username);

  Message withId(String uuidString) {
    id = uuidString;

    return this;
  }

  Message withAvatarUrl(String avatarUrl) {
    this.avatarUrl = avatarUrl;

    return this;
  }
}
