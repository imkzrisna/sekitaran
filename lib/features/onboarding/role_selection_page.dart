import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/home/business_home_page.dart';
import 'package:sekitaran/features/auth/auth_service.dart';

enum UserRole { regular, business }

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  UserRole? _selected;
  bool _saving = false;

  Future<void> _continue() async {
    final role = _selected;
    if (role == null || _saving) return;
    setState(() => _saving = true);
    try {
      await AuthService.instance.saveRole(role.name); // 'regular' / 'business'
      if (!mounted) return;
      if (role == UserRole.business) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const BusinessHomePage()),
          (_) => false,
        );
      } else {
        // TODO: homepage Reguler User (belum ada desain)
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Role tersimpan.')));
      }
    } on AuthFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _radio(bool selected) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? _green : Colors.white,
        border: Border.all(color: selected ? _green : _border, width: 1.5),
      ),
    );
  }

  Widget _feature({
    required String iconAsset,
    required IconData fallbackIcon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Image.asset(
              iconAsset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(fallbackIcon, size: 20, color: _label),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: _label,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleSection({
    required UserRole role,
    required String name,
    required List<Widget> features,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _selected = role),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _radio(_selected == role),
                const SizedBox(width: 12),
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: _label,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(children: features),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Text(
          'Welcome to Sekitaran',
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
              color: _accent,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _subtitle() {
    final base = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _label,
      height: 1.5,
    );
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(
            text: 'Choose how you want to use Sekitaran and\ndiscover ',
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Container(
              padding: const EdgeInsets.only(bottom: 3),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
              ),
              child: Text('what you can do.', style: base),
            ),
          ),
        ],
      ),
    );
  }

  Widget _continueButton() {
    final isBusiness = _selected == UserRole.business;
    return InkWell(
      onTap: _continue,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: _green, width: 2)),
        child: Container(
          height: 76,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: _green,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isBusiness
                          ? 'Continue as Business Owner'
                          : 'Continue as Reguler User',
                      maxLines: 1,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_circle_right_outlined,
                color: Colors.white,
                size: 30,
              ),
            ],
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
                  _title(),
                  const SizedBox(height: 16),
                  _subtitle(),
                  const SizedBox(height: 16),
                  Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: 250,
                      child: Image.asset(
                        'assets/images/welcome_roles.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.storefront_outlined,
                            size: 100,
                            color: _green,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _roleSection(
                    role: UserRole.regular,
                    name: 'Reguler User',
                    features: [
                      _feature(
                        iconAsset: 'assets/images/icon_find_places.png',
                        fallbackIcon: Icons.my_location,
                        title: 'Find nearby places',
                        description:
                            'Explore local shops and services on a map.',
                      ),
                      _feature(
                        iconAsset: 'assets/images/icon_prices_reviews.png',
                        fallbackIcon: Icons.sell_outlined,
                        title: 'Check prices and reviews',
                        description:
                            'See listed prices and community opinions.',
                      ),
                      _feature(
                        iconAsset: 'assets/images/icon_currency.png',
                        fallbackIcon: Icons.currency_exchange,
                        title: 'Currency tools',
                        description:
                            'Convert currencies and find money changers.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _roleSection(
                    role: UserRole.business,
                    name: 'Business Owner',
                    features: [
                      _feature(
                        iconAsset: 'assets/images/icon_business_profile.png',
                        fallbackIcon: Icons.storefront_outlined,
                        title: 'Create a business profile',
                        description:
                            'Add your business name, category, and location.',
                      ),
                      _feature(
                        iconAsset: 'assets/images/icon_manage_items.png',
                        fallbackIcon: Icons.monetization_on_outlined,
                        title: 'Manage items and prices',
                        description:
                            'List products or services with their prices.',
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.topCenter,
                    child: _selected == null
                        ? const SizedBox(width: double.infinity)
                        : Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: _continueButton(),
                          ),
                  ),
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
