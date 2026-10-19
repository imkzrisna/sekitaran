import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AccountCreatedPage extends StatelessWidget {
  const AccountCreatedPage({super.key});

  static const _green = Color(0xFF103D17);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);

  Widget _statusItem({
    required String iconAsset,
    required IconData fallbackIcon,
    required String title,
    required String description,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Icon(fallbackIcon, size: 30, color: _green),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: _label,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: _label,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _continueButton() {
    return InkWell(
      onTap: () {
        // TODO: arahkan ke halaman utama Sekitaran
      },
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
            'Continue to Sekitaran',
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 64),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Account Created Successfully!',
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Your account is ready. Welcome to Sekitaran!',
                        maxLines: 1,
                        softWrap: false,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _label,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: SizedBox(
                      width: 340,
                      height: 320,
                      child: Image.asset(
                        'assets/images/account_created.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.verified_outlined,
                            size: 110,
                            color: _green,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _statusItem(
                    iconAsset: 'assets/images/icon_email_verified.png',
                    fallbackIcon: Icons.mark_email_read,
                    title: 'Email verified',
                    description:
                        'Your email address has been verified successfully.',
                  ),
                  const SizedBox(height: 16),
                  _statusItem(
                    iconAsset: 'assets/images/icon_human_verified.png',
                    fallbackIcon: Icons.how_to_reg_outlined,
                    title: 'Human verification complete',
                    description: 'Your device verification is complete.',
                  ),
                  const SizedBox(height: 16),
                  _statusItem(
                    iconAsset: 'assets/images/icon_account_ready.png',
                    fallbackIcon: Icons.check_box_outlined,
                    title: 'Account ready',
                    description: 'Start discovering local places and everyday needs around you.',
                  ),
                  const SizedBox(height: 32),
                  _continueButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
