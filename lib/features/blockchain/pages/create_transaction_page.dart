import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sekitaran/features/blockchain/blockchain_service.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_blockchain_gateway.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_transaction_repository.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_wallet_gateway.dart';
import 'package:sekitaran/features/blockchain/transaction.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';

class CreateTransactionPage extends StatefulWidget {
  const new({super.key});

  @override
  State<CreateTransactionPage> createState() => _CreateTransactionPageState();
}

class _CreateTransactionPageState extends State<CreateTransactionPage> {
  late Future<void> _initAsyncFuture;
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
    final amountController = TextEditingController();
    final memoController = TextEditingController();

    return Scaffold(
      body: FutureBuilder(
        future: _initAsyncFuture,
        builder: (context, snapshot) {
          return Column(
            children: [
              TextField(controller: amountController),
              TextField(controller: memoController),

              FilledButton(
                onPressed: () async {
                  await _service.addTransactionAsync(
                    Transaction(
                      _session.currentSession!.userId,
                      double.parse(amountController.text),
                      memoController.text,
                    ),
                  );
                },
                child: Text("submit"),
              ),
            ],
          );
        },
      ),
    );
  }
}
