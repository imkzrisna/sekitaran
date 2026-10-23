import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/core/app_confirm_dialog.dart';
import 'package:sekitaran/features/auth/auth_service.dart';
import 'package:sekitaran/features/auth/biometric_service.dart';

const _green = Color(0xFF103D17);
const _ink = Color(0xFF252525);
const _grey = Color(0xFF7A7A7A);
const _bg = Color(0xFFF2F9F8);

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Mengaktifkan login sidik jari untuk akun yang sedang login.
/// Dipakai bersama oleh halaman profil semua role. true jika berhasil.
Future<bool> enableFingerprintFlow(BuildContext context) async {
  final bio = BiometricService.instance;
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    _snack(context, 'Session expired. Please log in again.');
    return false;
  }
  if (!await bio.isAvailable()) {
    if (context.mounted) {
      _snack(
        context,
        'No fingerprint is set up on this phone. Add one in Settings > Biometrics and security.',
      );
    }
    return false;
  }
  if (!context.mounted) return false;
  final password = await _askPassword(context);
  if (password == null || password.isEmpty || !context.mounted) return false;

  final raw = user.userMetadata?['username'];
  final username = (raw is String && raw.trim().isNotEmpty)
      ? raw.trim()
      : (user.email ?? '');

  // Verifikasi password dulu agar kredensial yang disimpan pasti benar.
  try {
    await AuthService.instance.signIn(identifier: username, password: password);
  } on AuthFailure catch (e) {
    if (context.mounted) _snack(context, e.message);
    return false;
  }
  if (!context.mounted) return false;

  final ok = await bio.authenticate(
    'Confirm your fingerprint to enable login with it',
  );
  if (!context.mounted) return false;
  if (!ok) {
    _snack(context, 'Fingerprint was not confirmed.');
    return false;
  }

  String? role;
  try {
    role = (await AuthService.instance.fetchMyProfile())?['role'] as String?;
  } catch (_) {}

  await bio.saveAccount(
    BiometricAccount(
      uid: user.id,
      identifier: username,
      password: password,
      username: username,
      role: role,
    ),
  );
  if (context.mounted) _snack(context, 'Fingerprint login enabled');
  return true;
}

/// Mematikan login sidik jari hanya untuk akun yang sedang login.
Future<bool> disableFingerprintFlow(BuildContext context) async {
  final uid = Supabase.instance.client.auth.currentUser?.id;
  if (uid == null) return false;
  final ok = await showConfirmDialog(
    context,
    title: 'Turn off fingerprint login?',
    message: 'You will need your username and password to log in.',
    confirmLabel: 'Turn off',
    icon: Icons.fingerprint,
  );
  if (!ok || !context.mounted) return false;
  await BiometricService.instance.removeAccount(uid);
  if (context.mounted) _snack(context, 'Fingerprint login turned off');
  return true;
}

Future<String?> _askPassword(BuildContext context) {
  final c = TextEditingController();
  var hide = true;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm your password',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Needed once to enable fingerprint login on this device.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: c,
              obscureText: hide,
              autofocus: true,
              style: GoogleFonts.poppins(fontSize: 14, color: _ink),
              decoration: InputDecoration(
                hintText: 'Enter your password',
                suffixIcon: IconButton(
                  icon: Icon(
                    hide
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: _grey,
                  ),
                  onPressed: () => setLocal(() => hide = !hide),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(ctx, v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: _grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: Text(
              'Continue',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
