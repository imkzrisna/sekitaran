import 'package:uuid/uuid.dart';

class Transaction {
  new(this.userId, this.transactionAmount, this.memo);

  String id = Uuid().v4();
  String userId;
  DateTime transactionDate = DateTime.now();
  double transactionAmount;
  String memo;
}
