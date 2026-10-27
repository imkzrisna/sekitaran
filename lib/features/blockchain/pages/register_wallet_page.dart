import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sekitaran/features/blockchain/blockchain_service.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_blockchain_gateway.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_transaction_repository.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_wallet_gateway.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';

class RegisterWalletPage extends StatefulWidget {
  const new({super.key});

  @override
  State<RegisterWalletPage> createState() => _RegisterWalletPageState();
}

class _RegisterWalletPageState extends State<RegisterWalletPage> {
  late final Future<void> _initAsyncFuture;

  late SupabaseSessionManager _session;
  late SupabaseTransactionRepository _transaction;
  late SupabaseBlockChainGateway _gateway;
  late SupabaseWalletGateway _wallet;
  late BlockchainService _service;

  Future<void> _initAsync() async {
    await _session.signInWithPasswordAsync(
      email: "krizsna.mz@gmail.com",
      password: "sayakurangtawu2",
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _session = SupabaseSessionManager();
    _transaction = SupabaseTransactionRepository();
    _gateway = SupabaseBlockChainGateway(1);
    _wallet = SupabaseWalletGateway();
    _service = BlockchainService(_gateway, _transaction, _session, _wallet);

    _initAsyncFuture = _initAsync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _initAsyncFuture,
        builder: (context, snapshot) {
          return Column(
            children: [
              FilledButton(
                onPressed: () async {
                  await _wallet.registerWallet(_session.currentSession!.userId);
                },
                child: Text("register for current user"),
              ),
            ],
          );
        },
      ),
    );
  }
}
