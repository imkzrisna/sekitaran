import 'package:sekitaran/features/blockchain/transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTransactionRepository {
  Future<void> addAsync(Transaction transaction) async {
    await Supabase.instance.client.from("blockchain_transaction").insert({
      "transaction_date": transaction.transactionDate,
      "transaction_amount": transaction.transactionAmount,
      "user_id": transaction.userId,
      "memo": transaction.memo,
      "status": transaction.status,
    });
  }

  Future<List<Transaction>> getAllAsync() async {
    final rows = await Supabase.instance.client
        .from("blockchain_transaction")
        .select("*");

    return rows
        .map(
          (row) =>
              Transaction(
                    row["user_id"],
                    row["transaction_amount"],
                    row["memo"],
                  )
                  .withId(row["id"])
                  .withTransactionDate(row["transaction_date"])
                  .withStatus(row["status"]),
        )
        .toList();
  }

  Future<Transaction?> getByIdAsync(String id) async {
    final row = await Supabase.instance.client
        .from("blockchain_transaction")
        .select("*")
        .eq("id", id);

    return row
        .map(
          (row) =>
              Transaction(
                    row["user_id"],
                    row["transaction_amount"],
                    row["memo"],
                  )
                  .withId(row["id"])
                  .withTransactionDate(row["transaction_date"])
                  .withStatus(row["status"]),
        )
        .toList()
        .firstOrNull;
  }

  Future<void> updateAsync(Transaction transaction) async {
    await Supabase.instance.client
        .from("blockchain_transaction")
        .update({
          "transaction_date": transaction.transactionDate,
          "transaction_amount": transaction.transactionAmount,
          "user_id": transaction.userId,
          "memo": transaction.memo,
          "status": transaction.status,
        })
        .eq("id", transaction.id);
  }
}
