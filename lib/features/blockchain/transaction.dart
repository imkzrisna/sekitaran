import 'package:uuid/uuid.dart';

class Transaction {
  new(this.giverUserId, this.transactionAmount, this.memo);

  String id = Uuid().v4();
  String giverUserId;
  DateTime transactionDate = DateTime.now();
  double transactionAmount;
  String memo;
  String status = "pending";

  Transaction withId(String id) {
    this.id = id;

    return this;
  }

  Transaction withTransactionDate(DateTime date) {
    transactionDate = date;

    return this;
  }

  Transaction withStatus(String status) {
    this.status = status;

    return this;
  }
}
