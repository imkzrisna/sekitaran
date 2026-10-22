import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _green = Color(0xFF103D17);
const _label = Color(0xFF252525);
const _bg = Color(0xFFF2F9F8);
const _border = Color(0xFFC9C9C9);
const _grey = Color(0xFF7A7A7A);

class _Section {
  const _Section(this.title, this.body);
  final String title;
  final String body;
}

const _sections = <_Section>[
  _Section(
    '1. Acceptance of Terms',
    'By creating an account or using Sekitaran, you agree to these Terms & '
        'Conditions. If you do not agree, please do not use the app.',
  ),
  _Section(
    '2. Eligibility and Account',
    'You must provide accurate information when registering and keep your '
        'login details secure. You are responsible for all activity under '
        'your account. Each person may hold only one account.',
  ),
  _Section(
    '3. Account Types',
    'Sekitaran offers Regular User and Business Owner accounts. Business '
        'Owners are responsible for the accuracy of their business profile, '
        'items, and listed prices.',
  ),
  _Section(
    '4. Location Information',
    'Sekitaran uses your location to show nearby places and services. '
        'Location access is requested only with your permission, and you can '
        'turn it off in your device settings at any time.',
  ),
  _Section(
    '5. Prices, Reviews and Content',
    'Prices and information shown in the app are provided by business '
        'owners and the community, and may change without notice. Sekitaran '
        'does not guarantee their accuracy. Currency conversion results are '
        'estimates only.',
  ),
  _Section(
    '6. Acceptable Use',
    'You agree not to post false, offensive, or misleading content, '
        'impersonate others, misuse the app, or attempt to disrupt or gain '
        'unauthorized access to our services.',
  ),
  _Section(
    '7. Privacy',
    'We collect and process personal data, such as your username and email '
        'address, to operate the app. We do not sell your personal data. '
        'Please read our Privacy Policy for details.',
  ),
  _Section(
    '8. Suspension and Termination',
    'We may suspend or remove accounts that violate these terms. You may '
        'stop using Sekitaran and request deletion of your account at any '
        'time.',
  ),
  _Section(
    '9. Limitation of Liability',
    'Sekitaran is provided "as is". To the extent permitted by law, we are '
        'not liable for losses arising from your use of the app or from '
        'dealings with businesses listed in it.',
  ),
  _Section(
    '10. Changes to These Terms',
    'We may update these terms from time to time. Continued use of the app '
        'after changes means you accept the updated terms.',
  ),
];

/// Menampilkan dialog Terms & Conditions.
/// Mengembalikan `true` jika user menekan "I Agree".
Future<bool?> showTermsDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _TermsDialog(),
  );
}

class _TermsDialog extends StatelessWidget {
  const _TermsDialog();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: _bg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: const RoundedRectangleBorder(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 440, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Terms & Conditions',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close, color: _label),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last updated: October 2026',
                  style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1.5, color: _border),

            // Isi (scroll)
            Flexible(
              child: Scrollbar(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  children: [
                    Text(
                      'Welcome to Sekitaran. Please read these terms '
                      'carefully before creating your account.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: _label,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final s in _sections) ...[
                      Text(
                        s.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.body,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: _label,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            const Divider(height: 1, thickness: 1.5, color: _border),
            Padding(
              padding: const EdgeInsets.all(20),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(true),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    border: Border.all(color: _green, width: 2),
                  ),
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _green,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      'I Agree',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
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
    );
  }
}
