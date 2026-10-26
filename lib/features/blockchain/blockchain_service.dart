import 'package:sekitaran/features/blockchain/block.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_blockchain_gateway.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_transaction_repository.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_wallet_gateway.dart';
import 'package:sekitaran/features/blockchain/transaction.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';

class BlockchainService {
  new(this._gateway, this._transaction, this._session, this._wallet);

  late final SupabaseBlockChainGateway _gateway;
  late final SupabaseTransactionRepository _transaction;
  late final SupabaseSessionManager _session;
  late final SupabaseWalletGateway _wallet;

  Future<void> miningAsync() async {
    if (_session.currentSession == null) return;

    final transactions = await _transaction.getAllAsync();

    for (Transaction transaction in transactions) {
      Block block = Block(
        (await _gateway.getLatestBlockAsync())!.hash,
        transaction.toString(),
      );

      _gateway.addBlockAsync(block);
      _wallet.addAmount(_session.currentSession!.userId, 0.01);
    }
  }

  Future<void> addTransactionAsync(Transaction transaction) async {
    if (_session.currentSession == null) return;

    await _transaction.addAsync(transaction);
  }
}
