import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _green = Color(0xFF103D17);
const _accent = Color(0xFF5BAA5F);
const _ink = Color(0xFF252525);
const _muted = Color(0xFF5F5F5F);
const _border = Color(0xFFC9C9C9);
const _bg = Color(0xFFF2F9F8);

/// Tombol sidik jari persegi hijau. Tingginya mengikuti induknya (stretch).
class FingerprintButton extends StatelessWidget {
  const FingerprintButton({super.key, required this.onTap, this.size = 56});

  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Login with fingerprint',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.fingerprint,
            color: Colors.white,
            size: size * 0.55,
          ),
        ),
      ),
    );
  }
}

/// Menampilkan sheet pemindaian. Mengembalikan true jika berhasil.
/// TODO: ganti simulasi dengan paket local_auth di tahap berikutnya.
Future<bool> showFingerprintScan(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: _bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ScanSheet(title: title, message: message),
  );
  return r == true;
}

class _ScanSheet extends StatefulWidget {
  const _ScanSheet({required this.title, required this.message});

  final String title;
  final String message;

  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  bool _done = false;
  Timer? _scan;
  Timer? _close;

  @override
  void initState() {
    super.initState();
    // Simulasi: dianggap berhasil setelah 2,4 detik.
    _scan = Timer(const Duration(milliseconds: 2400), () {
      if (!mounted) return;
      _pulse.stop();
      setState(() => _done = true);
      _close = Timer(const Duration(milliseconds: 900), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    });
  }

  @override
  void dispose() {
    _scan?.cancel();
    _close?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 22),
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, _) {
                final v = _done ? 0.0 : _pulse.value;
                return SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 92 + 38 * v,
                        height: 92 + 38 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _accent.withValues(alpha: 0.22 * (1 - v)),
                        ),
                      ),
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _done ? _accent : _green,
                        ),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Icon(
                            _done ? Icons.check : Icons.fingerprint,
                            key: ValueKey(_done),
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Text(
              _done ? 'Fingerprint recognized' : widget.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _done ? 'You\'re all set.' : widget.message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _muted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            AnimatedOpacity(
              opacity: _done ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _done ? null : () => Navigator.of(context).pop(false),
                child: Container(
                  width: double.infinity,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green, width: 1.2),
                  ),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
