import 'package:sekitaran/features/auth/entity/user.dart';
import 'package:sekitaran/features/auth/persistence/user_repository/user_profile_repository_interface.dart';

class FakeUserRepository implements UserProfileRepositoryInterface {
  var users = <User>[];

  @override
  Future<void> insertAsync(User user) async {
    users.add(user);
  }

  @override
  Future<List<User>> getAllAsync() async {
    return users;
  }

  @override
  Future<User?> getByUsernameAsync(String username) async {
    return users.where((user) => user.username == username).firstOrNull;
  }
}
