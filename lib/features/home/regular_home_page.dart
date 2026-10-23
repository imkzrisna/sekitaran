import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/profile/profile_page.dart';

/// Dashboard Regular User. Sengaja sederhana; styling menyusul.
class RegularHomePage extends StatelessWidget {
  const RegularHomePage({super.key});

  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  String get _username {
    final v =
        Supabase.instance.client.auth.currentUser?.userMetadata?['username'];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : 'there';
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  Widget _underlined(String text, {double size = 16}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 2),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: size,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    );
  }

  Widget _title() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            'Welcome to Sekitaran',
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
          Positioned(
            top: -14,
            right: -22,
            child: Text(
              '*',
              style: GoogleFonts.poppins(
                fontSize: 44,
                fontWeight: FontWeight.w500,
                color: _green,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subtitle() {
    final style = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _ink,
      height: 1.5,
    );
    Widget word(String t) => Text(t, style: style);
    return Wrap(
      spacing: 5,
      children: [
        word('Hey,'),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
          ),
          child: word('$_username!'),
        ),
        for (final w in 'Ready to explore around you?'.split(' ')) word(w),
      ],
    );
  }

  Widget _feature(
    BuildContext context, {
    required String asset,
    required IconData fallback,
    required String title,
    required String caption,
    bool last = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _soon(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(color: _border.withValues(alpha: 0.6)),
                ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              height: 26,
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) =>
                    Icon(fallback, size: 24, color: _green),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                  Text(
                    caption,
                    style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 22, color: _grey),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 56, 28, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(),
                      const SizedBox(height: 16),
                      _subtitle(),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          _underlined('What you can do'),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.explore_outlined,
                            color: _green,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _feature(
                        context,
                        asset: 'assets/images/icon_find_places.png',
                        fallback: Icons.my_location,
                        title: 'Find nearby places',
                        caption: 'Explore local shops and services on a map.',
                      ),
                      _feature(
                        context,
                        asset: 'assets/images/icon_prices_reviews.png',
                        fallback: Icons.sell_outlined,
                        title: 'Check prices and reviews',
                        caption: 'See listed prices and community opinions.',
                      ),
                      _feature(
                        context,
                        asset: 'assets/images/icon_currency.png',
                        fallback: Icons.currency_exchange,
                        title: 'Currency tools',
                        caption: 'Convert currencies and find money changers.',
                        last: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        RadialNavMenu.regular(
          current: RadialNavItem.home,
          onHome: () {}, // sudah berada di halaman ini
          onProfile: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProfilePage(isRegularUser: true),
            ),
          ),
          onExplore: () => _soon(context),
          onCurrency: () => _soon(context),
        ),
      ],
    );
  }
}
