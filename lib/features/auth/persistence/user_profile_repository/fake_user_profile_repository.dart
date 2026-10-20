import 'package:sekitaran/features/auth/entity/user_profile.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/user_profile_repository_interface.dart';

class FakeUserProfileRepository implements UserProfileRepositoryInterface {
  var users = <UserProfile>[];

  @override
  Future<void> insertAsync(UserProfile userProfile) async {
    users.add(userProfile);
  }

  @override
  Future<List<UserProfile>> getAllAsync() async {
    return users;
  }

  @override
  Future<UserProfile?> getByUsernameAsync(String username) async {
    return users.where((user) => user.username == username).firstOrNull;
  }
}
