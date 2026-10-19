import 'dart:collection';

class FakeSessionManager {
  HashMap<String, dynamic> sessionValue = HashMap<String, dynamic>();

  bool isAuthorized() {
    return sessionValue.isNotEmpty;
  }
}
