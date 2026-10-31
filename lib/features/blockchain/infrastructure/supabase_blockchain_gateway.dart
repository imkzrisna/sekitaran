import 'package:sekitaran/features/blockchain/block.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseBlockChainGateway {
  new(this.difficulty);

  int difficulty;

  Future<void> addGenesisBlockAsync() async {
    final genesisBlock = Block("", "GENESIS_BLOCK");

    await Supabase.instance.client.from("block").insert({
      "hash": genesisBlock.hash,
      "data": genesisBlock.data,
      "previous_hash": genesisBlock.previousHash,
      "nonce": genesisBlock.nonce,
    });
  }

  Future<Block?> getLatestBlockAsync() async {
    final rows = await Supabase.instance.client.from("block").select("*");

    final length = rows.length;
    final singleRow = rows.firstOrNull;

    if (singleRow == null) {
      return null;
    }

    return Block(singleRow["previous_hash"], singleRow["data"])
        .withId(singleRow["id"])
        .withNonce(singleRow["nonce"])
        .withCreationDate(DateTime.parse(singleRow["created_at"]))
        .withHash(singleRow["hash"]);
  }

  Future<void> addBlockAsync(Block block) async {
    block.previousHash = (await getLatestBlockAsync())!.hash;
    block.mineBlock(difficulty);

    await Supabase.instance.client.from("block").insert({
      "hash": block.hash,
      "data": block.data,
      "previous_hash": block.previousHash,
      "nonce": block.nonce,
    });
  }

  Future<bool> isValidChain() async {
    final blockchainRow = await Supabase.instance.client
        .from("block")
        .select("*");

    final blockChain = blockchainRow
        .map(
          (row) => Block(row["previous_hash"], row["data"])
              .withId(row["id"])
              .withNonce(row["nonce"])
              .withCreationDate(DateTime.parse(row["created_at"]))
              .withHash(row["hash"]),
        )
        .toList();

    // Start at 1 because genesis block (i=0) has no previous block to validate against
    for (var i = 1; i < blockChain.length; i++) {
      Block currentBlock = blockChain[i];
      Block previousBlock = blockChain[i - 1];

      // Validate hash is correctly calculated from block data
      if (currentBlock.hash != currentBlock.calculateHash()) return false;

      // Validate chain linkage: previous hash must match previous block's hash
      if (currentBlock.previousHash != previousBlock.hash) return false;
    }

    return true;
  }
}
