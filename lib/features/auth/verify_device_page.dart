import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/auth/account_created_page.dart';

class VerifyDevicePage extends StatefulWidget {
  const VerifyDevicePage({super.key});

  @override
  State<VerifyDevicePage> createState() => _VerifyDevicePageState();
}

class _VerifyDevicePageState extends State<VerifyDevicePage> {
  static const _green = Color(0xFF103D17);
  static const _star = Color(0xFF010C03);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);
  static const _spinner = Color(0xFF5BAA5F);

  bool _checking = false;

  void _onVerifyTap() {
    setState(() => _checking = true);
    _startShakeDetection();
  }

  void _startShakeDetection() {
    // TODO: ganti dengan sensor goyang (accelerometer) di tahap berikutnya.
    // Sementara: simulasi sukses setelah 3 detik agar alur UI bisa dicoba.
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AccountCreatedPage()),
      );
    });
  }

  Widget _title() {
    return Column(
      children: [
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
          child: Text.rich(
            softWrap: false,
            maxLines: 1,
            TextSpan(
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _label,
              ),
              children: [
                const TextSpan(text: 'Join Sekitaran and discover '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 3),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: _green, width: 1.5),
                      ),
                    ),
                    child: Text(
                      "what's around you.",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: _label,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomArea() {
    if (_checking) {
      return const SizedBox(
        height: 84,
        child: Center(
          child: SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: _spinner,
              backgroundColor: _green,
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: _onVerifyTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: _green, width: 2)),
        child: Container(
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _green,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            'Verify My Device',
            style: GoogleFonts.poppins(
              fontSize: 18,
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
                        _title(),
                        const SizedBox(height: 36),
                        Text(
                          'One last step!',
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
                            "Let's make sure you're a real person.",
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: _grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 280,
                          height: 300,
                          child: Image.asset(
                            _checking
                                ? 'assets/images/shake_phone_checking.png'
                                : 'assets/images/shake_phone.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.vibration,
                                size: 110,
                                color: _green,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Shake your phone',
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
                            'Gently shake your device to complete human verification.',
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: _grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(_checking),
                      child: _bottomArea(),
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
