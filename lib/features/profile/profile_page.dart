import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/core/app_confirm_dialog.dart';
import 'package:sekitaran/features/auth/biometric_service.dart';
import 'package:sekitaran/features/auth/fingerprint_flow.dart';
import 'package:sekitaran/features/auth/login_page.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/home/user_radial_nav_menu.dart';
import 'package:sekitaran/features/profile/profile_service.dart';
import 'package:sekitaran/features/store/add_store_page.dart';
import 'package:sekitaran/features/store/edit_store_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.isRegularUser = false});

  /// true untuk Regular User: memakai menu melingkar versi user.
  final bool isRegularUser;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  bool _loggingOut = false;
  bool _fingerprintOn = false;
  bool _fingerprintBusy = false;
  String? _avatarUrl;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadFingerprint();
    _loadAvatar();
  }

  Future<void> _loadFingerprint() async {
    final uid = _user?.id;
    final on = uid != null && await BiometricService.instance.hasAccount(uid);
    if (mounted) setState(() => _fingerprintOn = on);
  }

  // ---------- Data ----------

  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _username {
    final v = _user?.userMetadata?['username'];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : 'Sekitaran user';
  }

  String get _email => _user?.email ?? '-';

  String get _initial =>
      String.fromCharCode(_username.runes.first).toUpperCase();

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

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------- Aksi ----------

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
      _snack('Could not log out. Please try again.');
    }
  }

  Future<void> _toggleFingerprint(bool on) async {
    if (_fingerprintBusy) return;
    setState(() => _fingerprintBusy = true);
    try {
      final changed = on
          ? await enableFingerprintFlow(context)
          : await disableFingerprintFlow(context);
      if (!mounted) return;
      if (changed) setState(() => _fingerprintOn = on);
    } finally {
      if (mounted) setState(() => _fingerprintBusy = false);
    }
  }

  Future<void> _loadAvatar() async {
    try {
      final url = await ProfileService.instance.fetchAvatarUrl();
      if (mounted) setState(() => _avatarUrl = url);
    } on ProfileFailure {
      // Foto gagal dimuat: cukup tampilkan inisial.
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_photoBusy) return;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
    } catch (_) {
      if (mounted) {
        _snack(
          source == ImageSource.camera
              ? 'Could not open the camera.'
              : 'Could not open the gallery.',
        );
      }
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      final bytes = await file.readAsBytes();
      final url = await ProfileService.instance.uploadAvatar(bytes, file.name);
      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _snack('Profile photo updated');
    } on ProfileFailure catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    if (_photoBusy || _avatarUrl == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Remove profile photo?',
      message:
          'Your photo will be deleted and your initial will be shown instead.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok || !mounted) return;
    setState(() => _photoBusy = true);
    try {
      await ProfileService.instance.removeAvatar();
      if (!mounted) return;
      setState(() => _avatarUrl = null);
      _snack('Profile photo removed');
    } on ProfileFailure catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  void _showPhotoSheet() {
    if (_photoBusy) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _underlined('Profile photo'),
              const SizedBox(height: 8),
              _sheetRow(
                ctx,
                Icons.photo_camera_outlined,
                'Take a photo',
                () => _pickPhoto(ImageSource.camera),
              ),
              _sheetRow(
                ctx,
                Icons.photo_library_outlined,
                'Choose from gallery',
                () => _pickPhoto(ImageSource.gallery),
              ),
              if (_avatarUrl != null)
                _sheetRow(
                  ctx,
                  Icons.delete_outline,
                  'Remove photo',
                  _removePhoto,
                  danger: true,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetRow(
    BuildContext ctx,
    IconData icon,
    String text,
    VoidCallback onTap, {
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade600 : _ink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: danger ? color : _green),
            const SizedBox(width: 14),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarImage() {
    final initial = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
      child: Text(
        _initial,
        style: GoogleFonts.poppins(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
    final url = _avatarUrl;
    final base = url == null
        ? initial
        : ClipOval(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initial,
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : initial,
            ),
          );
    if (!_photoBusy) return base;
    return Stack(
      fit: StackFit.expand,
      children: [
        base,
        const DecoratedBox(
          decoration: BoxDecoration(
            color: Color(0x66000000),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Komponen dasar (sama dengan dashboard) ----------

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
        word("Here's"),
        word('your'),
        word('account.'),
      ],
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const SizedBox(height: 28),
        _title(),
        const SizedBox(height: 14),
        _subtitle(),
      ],
    );
  }

  /// Judul bagian: teks bergaris hijau + ikon, seperti "My Business".
  Widget _heading(String text, IconData icon, {String? caption}) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _underlined(text)),
              const SizedBox(width: 6),
              Icon(icon, color: _green, size: 22),
            ],
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                caption,
                style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line({required Widget child, bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _border.withValues(alpha: 0.6))),
      ),
      child: child,
    );
  }

  // ---------- Bagian ----------

  Widget _avatar() {
    return SizedBox(
      width: 80,
      height: 80,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 80,
            height: 80,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _accent, width: 1.6),
            ),
            child: _avatarImage(),
          ),
          Positioned(
            right: -2,
            bottom: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _bg,
                shape: BoxShape.circle,
                border: Border.all(color: _green, width: 1.3),
              ),
              child: const Icon(
                Icons.photo_camera_outlined,
                size: 13,
                color: _green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _identity() {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _showPhotoSheet,
        child: Row(
          children: [
            _avatar(),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to change photo',
                    style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detail(
    String label,
    String value, {
    Widget? trailing,
    bool last = false,
  }) {
    return _line(
      last: last,
      child: Row(
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 6), trailing],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _details() {
    final verified = _emailVerified;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        children: [
          _detail('Username', _username),
          _detail('Email', _email),
          _detail(
            'Email status',
            verified ? 'Verified' : 'Not verified',
            trailing: Icon(
              verified ? Icons.check_circle : Icons.error_outline,
              size: 16,
              color: verified ? _accent : Colors.orange.shade700,
            ),
          ),
          _detail('Member since', _memberSince, last: true),
        ],
      ),
    );
  }

  Widget _fingerprintRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fingerprintOn ? 'Enabled on this device' : 'Not set up',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Log in faster without typing your password.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _grey,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _fingerprintOn,
            onChanged: _fingerprintBusy ? null : _toggleFingerprint,
            thumbColor: const WidgetStatePropertyAll(Colors.white),
            trackColor: WidgetStateProperty.resolveWith(
              (s) => s.contains(WidgetState.selected) ? _green : _border,
            ),
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _quote(String label, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
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
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Reveal(index: 0, child: _header()),
                      _Reveal(index: 1, child: _identity()),
                      _Reveal(
                        index: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _heading('Account Details', Icons.badge_outlined),
                            _details(),
                          ],
                        ),
                      ),
                      _Reveal(
                        index: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _heading('Fingerprint Login', Icons.fingerprint),
                            _fingerprintRow(),
                          ],
                        ),
                      ),

                      _Reveal(
                        index: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _heading(
                              'Saran & Kesan',
                              Icons.rate_review_outlined,
                              caption: 'Pemrograman Aplikasi Mobile',
                            ),
                            _quote('Saran', 'Lebih baik jangan gegabah'),
                            _quote(
                              'Kesan',
                              'Saya kurang tau dan partner saya kurang tau sooo all good hehe',
                            ),
                          ],
                        ),
                      ),
                      _Reveal(index: 5, child: _logoutButton()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.isRegularUser
            ? UserRadialNavMenu(
                current: UserNavItem.profile,
                onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
                onExplore: () => _snack('Coming soon'),
                onCurrency: () => _snack('Coming soon'),
                onProfile: () {}, // sudah berada di halaman ini
              )
            : RadialNavMenu(
                current: RadialNavItem.profile,
                onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
                onAddStore: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AddStorePage())),
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditStorePage()),
                ),
                onProfile: () {}, // sudah berada di halaman ini
              ),
      ],
    );
  }
}

/// Memunculkan anak dengan fade dan geser sedikit, bergantian per [index].
class _Reveal extends StatefulWidget {
  const _Reveal({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _show = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) setState(() => _show = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 350),
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
