import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/core/app_confirm_dialog.dart';
import 'package:sekitaran/features/auth/login_page.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/store/add_store_page.dart';
import 'package:sekitaran/features/store/edit_store_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);
  static const _sections = 5;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final List<Animation<double>> _anims = List.generate(_sections, (i) {
    final start = i * 0.1;
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, start + 0.5, curve: Curves.easeOutCubic),
    );
  });

  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // ---------- Data ----------

  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _username {
    final v = _user?.userMetadata?['username'];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : 'Sekitaran user';
  }

  String get _email => _user?.email ?? '-';

  String get _initial => _username.characters.first.toUpperCase();

  bool get _emailVerified => _user?.emailConfirmedAt != null;

  String get _memberSince {
    final d = DateTime.tryParse(_user?.createdAt ?? '')?.toLocal();
    if (d == null) return '-';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need to log in again to manage your stores.',
      confirmLabel: 'Log out',
      icon: Icons.logout,
    );
    if (!ok || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
    }
  }

  // ---------- Komponen ----------

  Widget _reveal(int i, Widget child) {
    final a = _anims[i];
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(a),
        child: child,
      ),
    );
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
            'Your Profile',
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
          Positioned(
            top: -12,
            right: -20,
            child: Text(
              '*',
              style: GoogleFonts.poppins(
                fontSize: 40,
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
    return Container(
      padding: const EdgeInsets.only(bottom: 3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
      ),
      child: Text(
        'Manage your account',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _cardTitle(String title, IconData icon) {
    return Row(
      children: [
        Flexible(child: _underlined(title)),
        const SizedBox(width: 8),
        Icon(icon, color: _green, size: 22),
      ],
    );
  }

  Widget _profileCard() {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 22),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _green,
              shape: BoxShape.circle,
            ),
            child: Text(
              _initial,
              style: GoogleFonts.poppins(
                fontSize: 34,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            _username,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _email,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 13, color: _grey),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    Widget value, {
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _border.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _green),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 11.5, color: _grey),
                ),
                const SizedBox(height: 2),
                value,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _valueText(String text) {
    return Text(
      text,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _ink,
      ),
    );
  }

  Widget _detailsCard() {
    final verified = _emailVerified;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Account Details', Icons.badge_outlined),
          const SizedBox(height: 6),
          _infoRow(Icons.person_outline, 'Username', _valueText(_username)),
          _infoRow(Icons.mail_outline, 'Email', _valueText(_email)),
          _infoRow(
            Icons.verified_outlined,
            'Email status',
            Row(
              children: [
                _valueText(verified ? 'Verified' : 'Not verified'),
                const SizedBox(width: 6),
                Icon(
                  verified ? Icons.check_circle : Icons.error_outline,
                  size: 16,
                  color: verified ? _accent : Colors.orange.shade700,
                ),
              ],
            ),
          ),
          _infoRow(
            Icons.event_outlined,
            'Member since',
            _valueText(_memberSince),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _actionRow(
    IconData icon,
    String text,
    VoidCallback onTap, {
    bool last = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
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
            Icon(icon, size: 20, color: _green),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 22, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _actionsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Quick Actions', Icons.bolt_outlined),
          const SizedBox(height: 6),
          _actionRow(
            Icons.edit_outlined,
            'Manage my stores',
            () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const EditStorePage())),
          ),
          _actionRow(
            Icons.add_circle_outline,
            'Add a new store',
            () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AddStorePage())),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _logout,
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green, width: 1.2),
          ),
          child: _loggingOut
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _green,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, size: 20, color: _green),
                    const SizedBox(width: 8),
                    Text(
                      'Log out',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                ),
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _reveal(
                        0,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).maybePop(),
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 20,
                                color: _green,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _title(),
                                  const SizedBox(height: 12),
                                  _subtitle(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _reveal(1, _profileCard()),
                      _reveal(2, _detailsCard()),
                      _reveal(3, _actionsCard()),
                      _reveal(4, _logoutButton()),
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
