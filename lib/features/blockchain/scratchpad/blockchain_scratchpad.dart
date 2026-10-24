import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';

class BlockchainScratchpad extends StatefulWidget {
  const new({super.key});

  @override
  State<BlockchainScratchpad> createState() => _BlockchainScratchpadState();
}

class _BlockchainScratchpadState extends State<BlockchainScratchpad> {
  late Future<void> _initFuture;
  final _session = SupabaseSessionManager();

  Future<void> _initStateAsync() async {
    await _session.signInWithPasswordAsync(
      email: "example@gmail.com",
      password: "password",
    );
  }

  @override
  void initState() {
    super.initState();

    _initFuture = _initStateAsync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("an error occured: ${snapshot.error.toString()}"),
            );
          }

          return Container();
        },
      ),
    );
  }
}
