import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
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
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _hidePass = true;
  bool _hideConfirm = true;
  bool _agree = true;
  bool _agreeError = false;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();
    setState(() => _agreeError = !_agree);
    if (valid && _agree) {
      // TODO: backend di tahap berikutnya
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Validasi berhasil (frontend only)')),
      );
    }
  }

  InputDecoration _decoration(String hint, String helper, {Widget? suffix}) {
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
      helperText: helper.isEmpty ? null : helper,
      helperMaxLines: 2,
      helperStyle: GoogleFonts.poppins(fontSize: 11, color: _grey),
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

  Widget _eye(bool hidden, VoidCallback onTap) => IconButton(
    icon: Icon(
      hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
      color: _grey,
      size: 20,
    ),
    onPressed: onTap,
  );

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
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border, width: 1.2),
            ),
            padding: const EdgeInsets.all(20),
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
                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Create Account',
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.w600,
                                color: _green,
                              ),
                            ),
                            WidgetSpan(
                              alignment: PlaceholderAlignment.top,
                              child: Transform.translate(
                                offset: const Offset(4, -2),
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
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text.rich(
                        textAlign: TextAlign.center,
                        TextSpan(
                          style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: _label,
                          ),
                          children: [
                            const TextSpan(
                              text: 'Join Sekitaran and discover ',
                            ),
                            TextSpan(
                              text: "what's around you.",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: _label,
                                decoration: TextDecoration.underline,
                                decorationColor: _green,
                                decorationThickness: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    _fieldLabel('Username'),
                    TextFormField(
                      controller: _username,
                      style: GoogleFonts.poppins(fontSize: 15, color: _label),
                      decoration: _decoration(
                        'Enter your username',
                        'Panjang karakter username minimal 8',
                      ),
                      validator: (v) => (v == null || v.trim().length < 8)
                          ? 'Username minimal 8 karakter'
                          : null,
                    ),

                    _fieldLabel('Email'),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      style: GoogleFonts.poppins(fontSize: 15, color: _label),
                      decoration: _decoration(
                        'Enter your email',
                        'Gunakan email yang valid',
                      ),
                      validator: (v) {
                        final t = v?.trim() ?? '';
                        final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(t);
                        return ok ? null : 'Format email tidak valid';
                      },
                    ),

                    _fieldLabel('Password'),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePass,
                      style: GoogleFonts.poppins(fontSize: 15, color: _label),
                      decoration: _decoration(
                        'Enter your password',
                        'Minimal password mengandung (min panjang 5 karakter dengan kombinasi angka)',
                        suffix: _eye(
                          _hidePass,
                          () => setState(() => _hidePass = !_hidePass),
                        ),
                      ),
                      validator: (v) {
                        final t = v ?? '';
                        if (t.length < 5) return 'Password minimal 5 karakter';
                        if (!RegExp(r'\d').hasMatch(t)) {
                          return 'Password harus mengandung angka';
                        }
                        return null;
                      },
                    ),

                    _fieldLabel('Confirm password'),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hideConfirm,
                      style: GoogleFonts.poppins(fontSize: 15, color: _label),
                      decoration: _decoration(
                        'Re-enter your password',
                        '',
                        suffix: _eye(
                          _hideConfirm,
                          () => setState(() => _hideConfirm = !_hideConfirm),
                        ),
                      ),
                      validator: (v) =>
                          v != _password.text ? 'Password tidak sama' : null,
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        SizedBox(
                          height: 26,
                          width: 26,
                          child: Checkbox(
                            value: _agree,
                            activeColor: _green,
                            checkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(3),
                            ),
                            side: const BorderSide(color: _green, width: 1.5),
                            onChanged: (v) =>
                                setState(() => _agree = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Agree to the',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: _label,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () {
                            // TODO: navigasi ke halaman Terms & Conditions
                          },
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 1),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: _gold, width: 1.2),
                              ),
                            ),
                            child: Text(
                              'Terms & Conditions',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _gold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_agreeError)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 38),
                        child: Text(
                          'Anda harus menyetujui Terms & Conditions',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),

                    const SizedBox(height: 28),
                    InkWell(
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
                            'Sign Up',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
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
                            'Or sign up with',
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
