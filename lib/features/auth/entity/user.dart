import 'package:uuid/uuid.dart';

class User {
  new(this.username, this.passwordHash);

  Uuid id = Uuid(); 
  String username = "";
  String passwordHash = "";
}
