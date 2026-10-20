import 'package:sekitaran/features/auth/entity/user_profile.dart';

abstract interface class UserProfileRepositoryInterface {
  Future<void> insertAsync(UserProfile user);

  Future<List<UserProfile>> getAllAsync();

  Future<UserProfile?> getByUsernameAsync(String username);
}
