import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/auth/fingerprint_scan_sheet.dart';
import 'package:sekitaran/features/auth/auth_service.dart';
import 'package:sekitaran/features/auth/biometric_service.dart';
import 'package:sekitaran/features/auth/create_account_page.dart';
import 'package:sekitaran/features/onboarding/role_selection_page.dart';
import 'package:sekitaran/features/home/business_home_page.dart';
import 'package:sekitaran/features/home/regular_home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _green = Color(0xFF103D17);
  static const _star = Color(0xFF010C03);
  static const _label = Color(0xFF252525);
  static const _gold = Color(0xFFC99A4A);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);
  static const _required = Color(0xFFB00000);

  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _hidePass = true;
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await AuthService.instance.signIn(
        identifier: _username.text,
        password: _password.text,
      );
      await _finishLogin();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Dipakai bersama oleh login password dan login sidik jari.
  Future<void> _finishLogin() async {
      var profile = await AuthService.instance.fetchMyProfile();
      if (profile == null) {
        // Email sudah terverifikasi tapi profil belum sempat dibuat.
        await AuthService.instance.ensureProfile();
        profile = await AuthService.instance.fetchMyProfile();
      }
      if (!mounted) return;
      if (profile == null || profile['role'] == null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
        );
        return;
      }

      _snack('Login berhasil sebagai ${profile['username']}');
      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      final Widget next = profile['role'] == 'business'
          ? const BusinessHomePage()
          : const RegularHomePage();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
        (_) => false,
      );
  }

  Future<void> _fingerprintLogin() async {
    if (_loading) return;
    final bio = BiometricService.instance;
    if (!await bio.hasCredentials()) {
      _snack(
        'Login sidik jari belum diaktifkan. Masuk dengan password, lalu aktifkan di halaman Profile.',
      );
      return;
    }
    if (!await bio.isAvailable()) {
      _snack('Sidik jari tidak tersedia atau belum terdaftar di perangkat ini.');
      return;
    }
    final ok = await bio.authenticate('Verifikasi sidik jari untuk masuk ke Sekitaran');
    if (!ok || !mounted) return;
    final cred = await bio.readCredentials();
    if (cred == null) {
      if (!mounted) return;
      _snack('Data login sidik jari tidak ditemukan. Aktifkan ulang di halaman Profile.');
      return;
    }
    setState(() => _loading = true);
    try {
      await AuthService.instance.signIn(
        identifier: cred.identifier,
        password: cred.password,
      );
      await _finishLogin();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
      borderSide: BorderSide(color: c, width: 1.2),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: const Color(0xFF9A9A9A),
        fontSize: 15,
        fontWeight: FontWeight.w300,
      ),
      errorStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade700),
      errorMaxLines: 2,
      filled: true,
      fillColor: _bg,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: border(_border),
      focusedBorder: border(_green),
      errorBorder: border(Colors.red.shade400),
      focusedErrorBorder: border(Colors.red.shade400),
    );
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, top: 14),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
            style: GoogleFonts.poppins(
              color: _label,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Text(
                '*',
                style: GoogleFonts.poppins(
                  color: _required,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _title() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            'Welcome Back',
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
    );
  }

  Widget _subtitle() {
    final style = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _label,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'Log in and keep exploring',
            maxLines: 1,
            softWrap: false,
            style: style,
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.only(bottom: 3),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _green, width: 1.5)),
            ),
            child: Text(
              "what's around you.",
              maxLines: 1,
              softWrap: false,
              style: style,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldLink(String text, VoidCallback onTap, {double size = 13}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 1),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: _gold, width: 1.2)),
        ),
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: size,
            fontWeight: FontWeight.w500,
            color: _gold,
          ),
        ),
      ),
    );
  }

  Widget _googleButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {}, // UI saja, tanpa auth
          child: Container(
            width: 106,
            height: 90,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border, width: 1.2),
            ),
            child: Image.asset(
              'assets/images/google.png',
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  'G',
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: _green,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 106,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _border, width: 1.2),
          ),
          child: Text(
            'Google',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B6B6B),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    _title(),
                    const SizedBox(height: 14),
                    _subtitle(),
                    const SizedBox(height: 40),

                    _fieldLabel('Username'),
                    TextFormField(
                      controller: _username,
                      keyboardType: TextInputType.text,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      style: GoogleFonts.poppins(fontSize: 15, color: _label),
                      decoration: _decoration('Enter your username'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Username wajib diisi'
                          : null,
                    ),

                    _fieldLabel('Password'),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePass,
                      style: GoogleFonts.poppins(fontSize: 15, color: _label),
                      decoration: _decoration(
                        'Enter your password',
                        suffix: IconButton(
                          icon: Icon(
                            _hidePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _grey,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _hidePass = !_hidePass),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Password wajib diisi'
                          : null,
                    ),

                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _goldLink('Forgot password?', () {
                        // TODO: halaman reset password
                      }),
                    ),

                    const SizedBox(height: 28),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
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
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 28,
                                          height: 28,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 3,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Login',
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
                          const SizedBox(width: 12),
                          FingerprintButton(onTap: _fingerprintLogin),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(color: _border, thickness: 2),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Or login with',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: _grey,
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(color: _border, thickness: 2),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),
                    Center(child: _googleButton()),

                    const SizedBox(height: 28),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            "Don't have an account?",
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _label,
                            ),
                          ),
                          _goldLink('Sign Up', () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const CreateAccountPage(),
                              ),
                            );
                          }, size: 14),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
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
