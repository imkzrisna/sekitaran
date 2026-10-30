import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/blockchain/blockchain_service.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_blockchain_gateway.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_transaction_repository.dart';
import 'package:sekitaran/features/blockchain/infrastructure/supabase_wallet_gateway.dart';
import 'package:sekitaran/features/auth/login_page.dart';
import 'package:sekitaran/features/blockchain/pages/create_transaction_page.dart';
import 'package:sekitaran/features/blockchain/pages/mining_page.dart';
import 'package:sekitaran/features/blockchain/pages/register_wallet_page.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Dashboard showing the current user's SKT coin balance with buttons to
/// navigate to the mining page and the transaction page.
///
/// Styled to mirror `lib/features/profile/profile_page.dart` (green palette,
/// `GoogleFonts.poppins`, `ConstrainedBox(maxWidth: 440)` scrollable shell and
/// staggered reveal animations).
class BlockchainDashboardPage extends StatefulWidget {
  const BlockchainDashboardPage({super.key, this.blockchainService});

  /// Optional pre-configured service (useful for testing). When omitted the
  /// page creates and signs in with its own service, mirroring the other
  /// blockchain pages (`MiningPage`, `CreateTransactionPage`).
  final BlockchainService? blockchainService;

  @override
  State<BlockchainDashboardPage> createState() =>
      _BlockchainDashboardPageState();
}

class _BlockchainDashboardPageState extends State<BlockchainDashboardPage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  late final SupabaseSessionManager _session;
  late final SupabaseWalletGateway _wallet;
  late final BlockchainService _service;
  bool _loading = true;
  double _balance = 0.0;
  String? _error;
  bool _hasWallet = false;
  String _username = 'Sekitaran user';

  @override
  void initState() {
    super.initState();
    if (widget.blockchainService != null) {
      _service = widget.blockchainService!;
      _load();
    } else {
      _initDefault();
    }
  }

  /// Creates and signs in with a standalone service, mirroring `MiningPage` so
  /// the page works when used directly as the app `home` without an existing
  /// persisted session.
  Future<void> _initDefault() async {
    _session = SupabaseSessionManager();
    final transaction = SupabaseTransactionRepository();
    final gateway = SupabaseBlockChainGateway(1);
    _wallet = SupabaseWalletGateway();
    _service = BlockchainService(gateway, transaction, _session, _wallet);

    if (!mounted) return;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      // Requirement: not logged in -> redirect to the login page.
      if (user == null) {
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
        return;
      }

      final meta = user.userMetadata?['username'];
      final name = (meta is String && meta.trim().isNotEmpty)
          ? meta.trim()
          : null;
      if (name != null) _username = name;

      final address = await _service.getWalletAddressAsync();
      if (!mounted) return;
      _hasWallet = address != null && address.isNotEmpty;

      if (_hasWallet) {
        final balance = await _service.getCurrentUserBalanceAsync();
        if (!mounted) return;
        setState(() {
          _balance = balance;
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "terdapat error: " + e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _registerWallet() async {
    if (_session.currentSession == null) return;

    await _wallet.registerWallet(_session.currentSession!.userId);

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const BlockchainDashboardPage()));
  }

  Future<void> _goToMining() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MiningPage()));
    if (mounted) _load();
  }

  Future<void> _goToTransactions() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const CreateTransactionPage()));
    if (mounted) _load();
  }

  // ---------- Components (mirror profile_page.dart) ----------

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

  Widget _title() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            'Your Wallet',
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
          Positioned(
            top: -14,
            right: -22,
            child: Text(
              '*',
              style: GoogleFonts.poppins(
                fontSize: 44,
                fontWeight: FontWeight.w500,
                color: _green,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitle() {
    final style = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _ink,
      height: 1.5,
    );
    Widget word(String t) => Text(t, style: style);
    return Wrap(
      spacing: 5,
      children: [
        word('Hey,'),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
          ),
          child: word('$_username!'),
        ),
        word('berikut'),
        word('saldo'),
        word('SKT'),
        word('mu.'),
      ],
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SizedBox(height: 28),
        _title(),
        const SizedBox(height: 14),
        _subtitle(),
      ],
    );
  }

  Widget _heading(String text, IconData icon, {String? caption}) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _underlined(text)),
              const SizedBox(width: 6),
              Icon(icon, color: _green, size: 22),
            ],
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                caption,
                style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line({required Widget child, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _border.withValues(alpha: 0.6))),
      ),
      child: child,
    );
  }

  /// Memunculkan anak dengan fade dan geser sedikit, bergantian per [index].
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

  Widget _balanceCard() {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Saldo', style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _balance.toStringAsFixed(2),
              style: GoogleFonts.poppins(
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'SKT',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            onPressed: _loading ? null : _load,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: _green, width: 1.2),
              foregroundColor: _green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _green,
                    ),
                  )
                : Text(
                    'Refresh',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );

    if (_error != null) {
      return _line(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saldo',
              style: GoogleFonts.poppins(fontSize: 13, color: _grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Tidak dapat memuat saldo!',
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: _loading ? null : _load,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _green, width: 1.2),
                  foregroundColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _green,
                        ),
                      )
                    : Text(
                        'Coba lagi',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      );
    }

    return _line(child: content);
  }

  Widget _primaryOutlineButton({
    required String label,
    required IconData icon,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: _green),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _registerWalletSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Dompet',
          Icons.account_balance_wallet_outlined,
          caption:
              'Regiser dompet untuk memulai mendapatkan dan mentransfer SKT',
        ),
        const SizedBox(height: 16),
        _primaryOutlineButton(
          label: 'Register Dompet',
          icon: Icons.add,
          onPressed: _registerWallet,
        ),
      ],
    );
  }

  Widget _actions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Actions',
          Icons.send_outlined,
          caption: 'Tambang SKT atau buat transaksi',
        ),
        const SizedBox(height: 16),
        _primaryOutlineButton(
          label: 'Tambang',
          icon: Icons.work_outline,
          onPressed: _goToMining,
        ),
        const SizedBox(height: 12),
        _primaryOutlineButton(
          label: 'Transaksi',
          icon: Icons.receipt_outlined,
          onPressed: _goToTransactions,
        ),
      ],
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_loading)
                    const Center(
                      child: CircularProgressIndicator(color: _green),
                    )
                  else if (_error != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const SizedBox(height: 28),
                        Text(
                          'Error',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: GoogleFonts.poppins(fontSize: 15, color: _ink),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _reveal(index: 0, child: _header()),
                        if (!_hasWallet)
                          _reveal(index: 1, child: _registerWalletSection())
                        else ...[
                          _reveal(index: 1, child: _balanceCard()),
                          _reveal(index: 2, child: _actions()),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
