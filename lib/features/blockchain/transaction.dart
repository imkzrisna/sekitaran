import 'package:uuid/uuid.dart';

class Transaction {
  new(
    this.giverAddress,
    this.receiverAddress,
    this.transactionAmount,
    this.memo,
  );

  String id = Uuid().v4();
  String giverAddress;
  String receiverAddress;
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

  Map<String, dynamic> toJson() => {
    "id": id,
    "giverAddress": giverAddress,
    "receiverAddress": receiverAddress,
    "transactionDate": transactionDate,
    "transactionAmount": transactionAmount,
    "memo": memo,
    "status": status,
  };
}
