import 'package:uuid/uuid.dart';

class User {
  new(this.username, this.email, this.passwordHash);

  Uuid id = Uuid();
  String username = "";
  String email = "";
  String passwordHash = "";
}
