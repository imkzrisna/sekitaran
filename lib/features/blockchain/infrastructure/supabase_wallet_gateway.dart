import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseWalletGateway {
  Future<void> registerWallet(String userId) async {
    final rng = Random();
    final randomNumber = rng.nextInt(userId.toString().length);

    final address = sha256.convert(utf8.encode("$userId-$randomNumber"));

    await Supabase.instance.client.from("blockchain_wallet").insert({
      "user_id": userId,
      "address": address.toString(),
    });
  }

  Future<String> getWalletAddressById(String userId) async {
    final row = await Supabase.instance.client
        .from("blockchain_wallet")
        .select("address")
        .eq("user_id", userId)
        .single();

    return row["address"];
  }
}
