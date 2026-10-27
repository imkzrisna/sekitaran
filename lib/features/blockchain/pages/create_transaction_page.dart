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

  late SupabaseSessionManager _session;
  late SupabaseTransactionRepository _transaction;
  late SupabaseBlockChainGateway _gateway;
  late SupabaseWalletGateway _wallet;
  late BlockchainService _service;

  bool _submitting = false;

  late Future<void> _initStateAsyncFuture;

  Future<void> initStateAsync() async {
    await _session.signInWithPasswordAsync(
      email: "124240154@student.upnyk.ac.id",
      password: "sayakurangtawu3",
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

    _initStateAsyncFuture = initStateAsync();
  }

  @override
  void dispose() {
    _receiverController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_submitting) return;

    final user = _session.currentSession;
    if (user == null) {
      _snack('Please log in first.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final giverAddress = await _wallet.getWalletAddressById(user.userId);
      final amount = double.parse(_amountController.text);

      await _service.addTransactionAsync(
        Transaction(
          giverAddress,
          _receiverController.text.trim(),
          amount,
          _memoController.text.trim(),
        ),
      );

      if (!mounted) return;
      _formKey.currentState?.reset();
      _receiverController.clear();
      _amountController.clear();
      _memoController.clear();
      _snack('Transaction submitted');
    } catch (error) {
      if (!mounted) return;
      _snack('Could not submit the transaction. Please try again.');

      print("failed to submit transaction: $error");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SizedBox(height: 28),
        Text(
          'Create Transaction',
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: _green,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Send funds to another Sekitaran wallet.',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: _ink,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: GoogleFonts.poppins(fontSize: 14, color: _ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _green, width: 1.5),
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
        ],
      ),
    );
  }

  Widget _submitButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _submitting ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: _green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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
              : Text(
                  'Submit',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder(
        future: _initStateAsyncFuture,
        builder: (context, snapshot) {
          return SafeArea(
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
                        const SizedBox(height: 32),
                        _underlined('Recipient'),
                        const SizedBox(height: 6),
                        _formField(
                          controller: _receiverController,
                          label: 'Wallet address',
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Recipient address is required';
                            }
                            return null;
                          },
                        ),
                        _formField(
                          controller: _amountController,
                          label: 'Amount',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Amount is required';
                            }
                            final parsed = double.tryParse(value.trim());
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        _formField(
                          validator: (value) {},
                          controller: _memoController,
                          label: 'Memo (optional)',
                          maxLines: 2,
                        ),
                        _submitButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
