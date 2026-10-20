import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/auth/auth_service.dart';
import 'package:sekitaran/features/auth/verify_device_page.dart';

class VerifyEmailPage extends StatefulWidget {
  const VerifyEmailPage({super.key, required this.email});

  final String email;

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  static const _green = Color(0xFF103D17);
  static const _star = Color(0xFF010C03);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);
  static const _length = 6;

  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _showError = false;
  String? _errorText;
  bool _loading = false;
  bool _resending = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
    _startCooldown(); // email baru saja dikirim saat signUp
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _timer?.cancel();
    _cooldown = seconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_controller.text.length != _length) {
      setState(() {
        _errorText = null;
        _showError = true;
      });
      return;
    }
    setState(() {
      _loading = true;
      _showError = false;
      _errorText = null;
    });
    try {
      await AuthService.instance.verifySignupOtp(
        email: widget.email,
        token: _controller.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const VerifyDevicePage()),
      );
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _showError = true;
        _errorText = e.message;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    setState(() => _resending = true);
    try {
      await AuthService.instance.resendSignupOtp(widget.email);
      if (!mounted) return;
      setState(() => _startCooldown());
      _snack('Kode baru dikirim ke ${widget.email}');
    } on AuthFailure catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Widget _codeBoxes() {
    final code = _controller.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final size = ((constraints.maxWidth - gap * (_length - 1)) / _length)
            .clamp(40.0, 66.0);
        return Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_length, (i) {
                final filled = i < code.length;
                final active =
                    _focus.hasFocus &&
                    i == (code.length < _length ? code.length : _length - 1);
                return Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                  child: Container(
                    width: size,
                    height: size,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: filled ? _green : Colors.white,
                      border: Border.all(
                        color: active ? _green : _border,
                        width: active ? 2 : 1.2,
                      ),
                    ),
                    child: Text(
                      filled ? code[i] : '',
                      style: GoogleFonts.poppins(
                        fontSize: size * 0.45,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                );
              }),
            ),
            // TextField transparan di atas kotak: menangani ketik, hapus, paste
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(_length),
                  ],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  onChanged: (_) => setState(() {
                    _showError = false;
                    _errorText = null;
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 64),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Text(
                              'Create Account',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: _green,
                              ),
                            ),
                            Positioned(
                              top: -14,
                              right: -24,
                              child: Text(
                                '*',
                                style: GoogleFonts.poppins(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w500,
                                  color: _star,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                'Join Sekitaran and discover',
                                maxLines: 1,
                                softWrap: false,
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: _label,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.only(bottom: 3),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _green,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  "what's around you.",
                                  maxLines: 1,
                                  softWrap: false,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _label,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 260,
                          height: 240,
                          child: Image.asset(
                            'assets/images/amplop.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.mark_email_read_outlined,
                                size: 96,
                                color: _green,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Enter Your Code',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: _label,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'A 6 digit code has been sent to your email address.',
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: _grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _codeBoxes(),
                        if (_showError)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _errorText ?? 'Masukkan 6 digit kode verifikasi',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Didn't receive the code?",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: _grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _cooldown > 0 ? null : _resend,
                              child: Text(
                                _cooldown > 0
                                    ? 'Resend in ${_cooldown}s'
                                    : 'Resend.',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _green,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                  child: InkWell(
                    onTap: _submit,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: _green, width: 2),
                      ),
                      child: Container(
                        height: 76,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _green,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          _loading ? 'Verifying...' : 'Submit',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
