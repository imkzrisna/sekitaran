import 'package:flutter/material.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/home/user_radial_menu.dart';

/// Halaman Global Chat. Sengaja kosong; isinya menyusul.
class GlobalChatPage extends StatelessWidget {
  const GlobalChatPage({super.key});

  static const _bg = Color(0xFFF2F9F8);

  @override
  Widget build(BuildContext context) {
    return const Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(backgroundColor: _bg, body: SizedBox.expand()),
        UserRadialMenu(current: RadialNavItem.chat),
      ],
    );
  }
}
