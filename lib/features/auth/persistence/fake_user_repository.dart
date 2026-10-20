import 'package:sekitaran/features/auth/entity/user.dart';

class FakeUserRepository {
  var users = <User>[];

  Future<void> insertAsync(User user) async {
    users.add(user);
  }

  Future<List<User>> getAllAsync() async {
    return users;
  }

  Future<User?> getByUsernameAsync(String username) async {
    return users.where((user) => user.username == username).firstOrNull;
  }
}
