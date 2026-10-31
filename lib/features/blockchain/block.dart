import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

class Block {
  new(this.previousHash, this.data);

  String index = Uuid().v4();
  DateTime createdAt = DateTime.now();
  late String hash = calculateHash();
  String data;
  String previousHash;
  int nonce = 0;

  Block withId(String uuidString) {
    index = uuidString;

    return this;
  }

  Block withCreationDate(DateTime createdAt) {
    this.createdAt = createdAt;

    return this;
  }

  Block withNonce(int nonce) {
    this.nonce = nonce;

    return this;
  }

  Block withHash(String hash) {
    this.hash = hash;

    return this;
  }

  String calculateHash() {
    final inputHash = utf8.encode(
      "$index-$createdAt-$data-$previousHash-$nonce",
    );
    final outputHash = sha256.convert(inputHash);

    return outputHash.toString();
  }

  void mineBlock(int difficulty) {
    String leadingZero = "0" * difficulty;

    while (hash.substring(0, difficulty) != leadingZero) {
      nonce++;
      hash = calculateHash();
    }
  }

  /// Validates that the block's hash meets the proof-of-work difficulty requirement.
  /// The hash must start with [difficulty] number of leading zeros.
  static bool isHashValid(String hash, int difficulty) {
    if (difficulty <= 0) return true;
    if (hash.length < difficulty) return false;
    final expectedLeadingZeros = "0" * difficulty;
    return hash.substring(0, difficulty) == expectedLeadingZeros;
  }
}
