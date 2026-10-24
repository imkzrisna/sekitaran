import 'package:sekitaran/features/blockchain/block.dart';
import 'package:uuid/uuid.dart';

class Blockchain {
  new(this.difficulty);

  List<Block> blockChain = [];
  int difficulty;

  Blockchain withBlockChain(List<Block> blockChain) {
    this.blockChain = blockChain;

    return this;
  }

  void addGenesisBlock() {
    blockChain.add(Block("", "GENESIS_BLOCK").withId(Uuid().v4()));
  }

  Block getLatestBlock() {
    return blockChain[blockChain.length - 1];
  }

  void addBlock(Block block) {
    block.previousHash = getLatestBlock().hash;
    block.mineBlock(difficulty);

    blockChain.add(block);
  }

  bool isValidChain() {
    for (var i = 0; i < blockChain.length; i++) {
      Block currentBlock = blockChain[i];
      Block previousBlock = blockChain[i - 1];

      if (currentBlock.hash != currentBlock.calculateHash()) return false;

      if (currentBlock.previousHash != previousBlock.hash) return false;
    }

    return true;
  }
}
