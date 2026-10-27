import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  final _formKey = GlobalKey<FormState>();
  final _receiverController = TextEditingController();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();

  late final SupabaseSessionManager _session;
  late final SupabaseTransactionRepository _transaction;
  late final SupabaseBlockChainGateway _gateway;
  late final SupabaseWalletGateway _wallet;
  late final BlockchainService _service;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();

    _session = SupabaseSessionManager();
    _transaction = SupabaseTransactionRepository();
    _gateway = SupabaseBlockChainGateway(1);
    _wallet = SupabaseWalletGateway();
    _service = BlockchainService(_gateway, _transaction, _session, _wallet);
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final session = _session.currentSession;
    if (session == null) {
      _snack('Please log in before creating a transaction.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    String giverAddress;
    try {
      giverAddress = await _wallet.getWalletAddressById(session.userId);
    } catch (_) {
      if (mounted) _snack('Could not find your wallet.');
      if (mounted) setState(() => _submitting = false);
      return;
    }

    try {
      await _service.addTransactionAsync(
        Transaction(
          giverAddress,
          _receiverController.text.trim(),
          double.parse(_amountController.text.trim()),
          _memoController.text.trim(),
        ),
      );
      if (!mounted) return;
      _formKey.currentState!.reset();
      _receiverController.clear();
      _amountController.clear();
      _memoController.clear();
      _snack('Transaction submitted');
    } catch (_) {
      if (mounted) _snack('Could not create the transaction. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ---------- Komponen dasar (sama dengan profile page) ----------

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
            'Create Transaction',
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
        word('Send'),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
          ),
          child: word('a transaction'),
        ),
        word('to'),
        word('another'),
        word('wallet.'),
      ],
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
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

  // ---------- Form ----------

  Widget _field(
    TextEditingController controller,
    String hint, {
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.poppins(fontSize: 14.5, color: _ink),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.poppins(fontSize: 14, color: _grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'This field is required';
    return null;
  }

  String? _amount(String? value) {
    final required = _required(value);
    if (required != null) return required;
    final amount = double.tryParse(value!.trim());
    if (amount == null || amount <= 0) {
      return 'Enter an amount greater than zero';
    }
    return null;
  }

  Widget _submitButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _submitting ? null : _submit,
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _submitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.swap_horiz,
                      size: 20,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Submit',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    _heading(
                      'Transfer Details',
                      Icons.swap_horiz,
                      caption: 'Amount, recipient, and an optional memo',
                    ),
                    _field(
                      _receiverController,
                      'Recipient wallet address',
                      validator: _required,
                    ),
                    _field(
                      _amountController,
                      'Amount',
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _amount,
                    ),
                    _field(_memoController, 'Memo (optional)'),
                    _submitButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
