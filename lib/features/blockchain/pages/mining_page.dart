import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/blockchain/blockchain_service.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_blockchain_gateway.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_transaction_repository.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_wallet_gateway.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';

class MiningPage extends StatefulWidget {
  const MiningPage({super.key});

  @override
  State<MiningPage> createState() => _MiningPageState();
}

class _MiningPageState extends State<MiningPage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);

  late SupabaseSessionManager _session;
  late SupabaseTransactionRepository _transaction;
  late SupabaseBlockChainGateway _gateway;
  late SupabaseWalletGateway _wallet;
  late BlockchainService _service;

  bool _mining = false;
  bool _isLoggedIn = false;

  late Future<void> _initAsyncFuture;

  Future<void> _initAsync() async {
    _session = SupabaseSessionManager();
    _transaction = SupabaseTransactionRepository();
    _gateway = SupabaseBlockChainGateway(1);
    _wallet = SupabaseWalletGateway();
    _service = BlockchainService(_gateway, _transaction, _session, _wallet);
    _service.isMiningNotifier.addListener(_onMiningChanged);

    await _session.signInWithPasswordAsync(
      email: "124240154@student.upnyk.ac.id",
      password: "sayakurangtawu3",
    );

    if (mounted) {
      setState(() => _isLoggedIn = _session.currentSession != null);
    }
  }

  @override
  void initState() {
    super.initState();
    _initAsyncFuture = _initAsync();
  }

  void _onMiningChanged() {
    if (!mounted) return;
    setState(() => _mining = _service.isMiningNotifier.value);
  }

  @override
  void dispose() {
    _service.isMiningNotifier.removeListener(_onMiningChanged);
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _startMining() async {
    final started = await _service.miningAsync();
    if (!mounted) return;
    if (!started) {
      _snack('Nothing to mine right now.');
    }
  }

  Future<void> _stopMining() async {
    await _service.abortAsync();
    if (!mounted) return;
    _snack('Mining stopped.');
  }

  Widget _underlined(String text, {double size = 16}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: _green, width: 1.2),
          foregroundColor: _green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _reveal({required int index, required Widget child}) {
    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 350),
      child: AnimatedSlide(
        offset: Offset.zero,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 140),
              child: FutureBuilder<void>(
                future: _initAsyncFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _green),
                    );
                  }

                  if (snapshot.hasError || !_isLoggedIn) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login, size: 48, color: _green),
                          const SizedBox(height: 16),
                          Text(
                            'Please log in to start mining',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You need to be logged in to mine blocks.',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _reveal(
                        index: 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 20),
                            _underlined('Mining'),
                            const SizedBox(height: 14),
                            Text(
                              'Mine blocks and earn rewards',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: _ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _reveal(index: 1, child: const SizedBox(height: 24)),
                      _reveal(
                        index: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (!_mining)
                              _primaryButton(
                                label: 'Start mining',
                                onPressed: _startMining,
                              )
                            else
                              _outlineButton(
                                label: 'Stop mining',
                                onPressed: _stopMining,
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
