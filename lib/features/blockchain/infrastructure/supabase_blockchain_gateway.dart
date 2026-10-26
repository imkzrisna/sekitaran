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
      "previousHash": genesisBlock.previousHash,
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
        .withCreationDate(singleRow["created_at"])
        .withHash(singleRow["hash"]);
  }

  Future<void> addBlockAsync(Block block) async {
    block.previousHash = (await getLatestBlockAsync())!.hash;
    block.mineBlock(difficulty);

    await Supabase.instance.client.from("block").insert({
      "hash": block.hash,
      "data": block.data,
      "previousHash": block.previousHash,
      "nonce": block.nonce,
    });
  }

  Future<bool> isValidChainAsync() async {
    final blockchainRow = await Supabase.instance.client
        .from("block")
        .select("*");
    final blockChain = blockchainRow
        .map(
          (row) => Block(row["previous_hash"], row["data"])
              .withId(row["id"])
              .withNonce(row["nonce"])
              .withCreationDate(row["created_at"])
              .withHash(row["hash"]),
        )
        .toList();

    for (var i = 0; i < blockChain.length; i++) {
      Block currentBlock = blockChain[i];
      Block previousBlock = blockChain[i - 1];

      if (currentBlock.hash != currentBlock.calculateHash()) return false;

      if (currentBlock.previousHash != previousBlock.hash) return false;
    }

    return true;
  }
}
