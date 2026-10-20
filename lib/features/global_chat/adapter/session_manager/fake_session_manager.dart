import 'dart:collection';

class FakeSessionManager {
  HashMap<String, dynamic> sessionValue = HashMap<String, dynamic>();

  HashMap<String, dynamic> loadSessionValue() {
    return sessionValue;
  }
}
