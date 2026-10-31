import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sekitaran/features/blockchain/block.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_blockchain_gateway.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_transaction_repository.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_wallet_gateway.dart';
import 'package:sekitaran/features/blockchain/transaction.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';

class BlockchainService {
  BlockchainService(
    this._gateway,
    this._transaction,
    this._session,
    this._wallet,
  );

  final SupabaseBlockChainGateway _gateway;
  final SupabaseTransactionRepository _transaction;
  final SupabaseSessionManager _session;
  final SupabaseWalletGateway _wallet;

  bool _isMining = false;
  final ValueNotifier<bool> isMiningNotifier = ValueNotifier(false);
  bool get isMining => _isMining;

  bool _stopRequested = false;

  Future<bool> miningAsync() async {
    if (_session.currentSession == null) return false;

    final transactions = await _transaction.getAllAsync();
    if (transactions.isEmpty) return false;

    // Validate the existing chain before mining new blocks
    final isChainValid = await _gateway.isValidChain();
    if (!isChainValid) {
      print('chain is not valid');
      _isMining = false;
      isMiningNotifier.value = false;
      return false;
    }

    _stopRequested = false;
    _isMining = true;
    isMiningNotifier.value = true;

    for (Transaction transaction in transactions) {
      if (_stopRequested) break;

      final latestBlock = await _gateway.getLatestBlockAsync();

      if (latestBlock == null) {
        await _gateway.addGenesisBlockAsync();
      }

      Block block = Block(
        (await _gateway.getLatestBlockAsync())!.hash,
        transaction.toJson().toString(),
      );

      // // Validate the block's proof-of-work before adding to chain
      // if (!Block.isHashValid(block.hash, _gateway.difficulty)) {
      //   // Block doesn't meet difficulty target; skip this transaction
      //   continue;
      // }

      final userAddress = await _wallet.getWalletAddressById(
        _session.currentSession!.userId,
      );

      await _transaction.updateAsync(
        Transaction(
              transaction.giverAddress,
              transaction.receiverAddress,
              transaction.transactionAmount,
              transaction.memo,
            )
            .withId(transaction.id)
            .withTransactionDate(transaction.transactionDate)
            .withStatus("mined"),
      );

      _gateway.addBlockAsync(block);
      _transaction.addAsync(
        Transaction("", userAddress!, 0.01, "mining reward"),
      );
    }

    _isMining = false;
    isMiningNotifier.value = false;
    return true;
  }

  Future<void> abortAsync() async {
    _stopRequested = true;
  }

  Future<void> addTransactionAsync(Transaction transaction) async {
    if (_session.currentSession == null) return;

    await _transaction.addAsync(transaction);
  }

  Future<double> getBallanceAsync(String walletAddress) async {
    final creditTransactions = (await _transaction.getAllAsync())
        .where((transaction) => transaction.receiverAddress == walletAddress)
        .toList();

    final debitTransactions = (await _transaction.getAllAsync())
        .where((transaction) => transaction.giverAddress == walletAddress)
        .toList();

    var credit = 0.0;

    for (var creditTransaction in creditTransactions) {
      credit += creditTransaction.transactionAmount;
    }

    var debit = 0.0;

    for (var debitTransaction in debitTransactions) {
      debit += debitTransaction.transactionAmount;
    }

    return credit - debit;
  }

  Future<double> getCurrentUserBalanceAsync() async {
    final session = _session.currentSession;
    if (session == null) return 0.0;

    final address = await _wallet.getWalletAddressById(session.userId);

    if (address == null) return 0.0;

    if (address.isEmpty) return 0.0;

    return getBallanceAsync(address);
  }

  Future<String?> getWalletAddressAsync() async {
    final session = _session.currentSession;
    if (session == null) return null;

    final address = await _wallet.getWalletAddressById(session.userId);

    if (address == null) return null;

    if (address.isEmpty) return null;

    return address;
  }
}
