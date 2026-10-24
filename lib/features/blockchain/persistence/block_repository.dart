import 'package:sekitaran/features/blockchain/block.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBlockRepository {
  final client = Supabase.instance.client;

  Future<void> insertAsync(Block block) {
    await client
      .from("block")
      .insert({
        ""
      })
  }
}
