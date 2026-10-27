import 'package:sekitaran/features/blockchain/transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTransactionRepository {
  Future<void> addAsync(Transaction transaction) async {
    await Supabase.instance.client.from("blockchain_transaction").insert({
      "id": transaction.id,
      "transaction_date": transaction.transactionDate.toIso8601String(),
      "giver_address": transaction.giverAddress,
      "receiver_address": transaction.receiverAddress,
      "transaction_amount": transaction.transactionAmount,
      "memo": transaction.memo,
      "status": transaction.status,
    });
  }

  Future<List<Transaction>> getAllAsync() async {
    final rows = await Supabase.instance.client
        .from("blockchain_transaction")
        .select("*");

    return rows.map((row) => _toTransaction(row)).toList();
  }

  Future<Transaction?> getByIdAsync(String id) async {
    final row = await Supabase.instance.client
        .from("blockchain_transaction")
        .select("*")
        .eq("id", id);

    return row.map((row) => _toTransaction(row)).toList().firstOrNull;
  }

  Future<void> updateAsync(Transaction transaction) async {
    await Supabase.instance.client
        .from("blockchain_transaction")
        .update({
          "transaction_date": transaction.transactionDate.toIso8601String(),
          "giver_address": transaction.giverAddress,
          "receiver_address": transaction.receiverAddress,
          "transaction_amount": transaction.transactionAmount,
          "memo": transaction.memo,
          "status": transaction.status,
        })
        .eq("id", transaction.id);
  }

  Transaction _toTransaction(Map<String, dynamic> row) {
    return Transaction(
          row["giver_address"],
          row["receiver_address"],
          row["transaction_amount"],
          row["memo"],
        )
        .withId(row["id"])
        .withTransactionDate(DateTime.parse(row["transaction_date"]))
        .withStatus(row["status"]);
  }
}
