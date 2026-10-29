import 'package:flutter_test/flutter_test.dart';
import 'package:sekitaran/features/auth/password_transform.dart';

void main() {
  test('uses the same deterministic SHA-256 transform for auth flows', () {
    const password = 'password';

    final transformed = transformPasswordForSupabase(password);

    expect(
      transformed,
      '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8',
    );
    expect(transformPasswordForSupabase(password), transformed);
  });

  test('does not alter password whitespace before transforming', () {
    expect(
      transformPasswordForSupabase(' password '),
      isNot(transformPasswordForSupabase('password')),
    );
  });
}
