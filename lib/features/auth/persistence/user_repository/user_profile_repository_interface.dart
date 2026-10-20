import 'package:sekitaran/features/auth/entity/user.dart';

abstract interface class UserProfileRepositoryInterface {
  Future<void> insertAsync(User user);

  Future<List<User>> getAllAsync();

  Future<User?> getByUsernameAsync(String username);
}
