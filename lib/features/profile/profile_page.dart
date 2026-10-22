import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/store/add_store_page.dart';
import 'package:sekitaran/features/store/edit_store_page.dart';

/// Halaman profil sementara: placeholder untuk styling nanti.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _green = Color(0xFF103D17);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final username = (user?.userMetadata?['username'] as String?) ?? '-';
    final email = user?.email ?? '-';

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 64, 28, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile',
                        style: GoogleFonts.poppins(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: _green,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        username,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _label,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: GoogleFonts.poppins(fontSize: 14, color: _grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        RadialNavMenu(
          current: RadialNavItem.profile,
          onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onAddStore: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AddStorePage())),
          onEdit: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const EditStorePage())),
          onProfile: () {}, // sudah berada di halaman ini
        ),
      ],
    );
  }
}
