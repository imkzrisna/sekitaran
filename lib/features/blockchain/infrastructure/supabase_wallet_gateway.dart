import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseWalletGateway {
  Future<void> addAmount(String userId, double amount) async {
    final currentAmountRow = await Supabase.instance.client
        .from("blockchain_wallet")
        .select("amount")
        .eq("user_id", userId);

    if (currentAmountRow.firstOrNull == null) {
      throw Exception("wallet not found");
    }

    final currentAmount = currentAmountRow.firstOrNull!["amount"];

    await Supabase.instance.client
        .from("blockchain_wallet")
        .update({"amount": currentAmount + amount})
        .eq("user_id", userId);
  }

  Future<void> removeAmount(String userId, double amount) async {
    final currentAmountRow = await Supabase.instance.client
        .from("blockchain_wallet")
        .select("amount")
        .eq("user_id", userId);

    if (currentAmountRow.firstOrNull == null) {
      throw Exception("wallet not found");
    }

    final currentAmount = currentAmountRow.firstOrNull!["amount"];

    await Supabase.instance.client
        .from("blockchain_wallet")
        .update({"amount": currentAmount - amount})
        .eq("user_id", userId);
  }

  Future<void> registerWallet(String userId) async {
    await Supabase.instance.client.from("blockchain_wallet").insert({
      "user_id": userId,
      "ballance": 0,
    });
  }
}
