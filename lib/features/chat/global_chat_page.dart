import 'package:flutter/material.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/profile/profile_page.dart';

/// Halaman Global Chat. Sengaja kosong; isinya menyusul.
class GlobalChatPage extends StatelessWidget {
  const GlobalChatPage({super.key});

  static const _bg = Color(0xFFF2F9F8);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const Scaffold(backgroundColor: _bg, body: SizedBox.expand()),
        RadialNavMenu.regular(
          current: RadialNavItem.chat,
          onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onProfile: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProfilePage(isRegularUser: true),
            ),
          ),
          onChat: () {}, // sudah berada di halaman ini
          onCurrency: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Coming soon'))),
        ),
      ],
    );
  }
}
