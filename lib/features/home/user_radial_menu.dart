import 'package:flutter/material.dart';
import 'package:sekitaran/features/chat/global_chat_page.dart';
import 'package:sekitaran/features/explore/currency_page.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/profile/profile_page.dart';

/// Menu melingkar Regular User dengan navigasi lengkap antar halaman.
/// Dashboard adalah route pertama; halaman lain selalu ditumpuk langsung di
/// atasnya, sehingga tombol back selalu kembali ke dashboard.
class UserRadialMenu extends StatelessWidget {
  const UserRadialMenu({super.key, this.current});

  /// Halaman yang sedang dibuka (diberi lingkaran putih).
  final RadialNavItem? current;

  void _go(BuildContext context, RadialNavItem target, Widget Function() page) {
    if (current == target) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RadialNavMenu.regular(
      current: current,
      onHome: () => Navigator.of(context).popUntil((route) => route.isFirst),
      onProfile: () => _go(
        context,
        RadialNavItem.profile,
        () => const ProfilePage(isRegularUser: true),
      ),
      onChat: () =>
          _go(context, RadialNavItem.chat, () => const GlobalChatPage()),
      onCurrency: () =>
          _go(context, RadialNavItem.currency, () => const CurrencyPage()),
    );
  }
}
