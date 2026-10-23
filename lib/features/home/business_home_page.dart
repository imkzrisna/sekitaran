import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sekitaran/features/profile/profile_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/core/reveal.dart';
import 'package:sekitaran/features/home/all_comments_page.dart';
import 'package:sekitaran/features/home/business_service.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/store/add_store_page.dart';
import 'package:sekitaran/features/store/edit_store_page.dart';

class BusinessHomePage extends StatefulWidget {
  const BusinessHomePage({super.key});

  @override
  State<BusinessHomePage> createState() => _BusinessHomePageState();
}

class _BusinessHomePageState extends State<BusinessHomePage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);

  final _service = BusinessService.instance;

  // Data dari backend
  bool _loading = true; // memuat daftar bisnis
  String? _error; // error saat memuat daftar bisnis
  List<Business> _businesses = const [];
  Business? _selected;

  bool _detailLoading = false; // memuat ringkasan + komentar
  String? _detailError;
  StoreOverview? _overview;
  List<StoreComment> _comments = const [];
  bool _markingRead = false;
  bool _dismissing = false; // animasi komentar keluar

  int _requestId = 0; // mencegah respons lama menimpa pilihan terbaru

  double _syncTurns = 0; // tiap +1 = satu putaran penuh

  @override
  void initState() {
    super.initState();
    _loadBusinesses();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------- Data ----------

  Future<void> _loadBusinesses() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchMyBusinesses();
      if (!mounted) return;
      Business? keep;
      for (final b in list) {
        if (b.id == _selected?.id) keep = b;
      }
      setState(() {
        _businesses = list;
        _selected = keep ?? (list.isNotEmpty ? list.first : null);
        _loading = false;
      });
      if (_selected != null) {
        await _loadDetail(_selected!);
      }
    } on ServiceFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _loadDetail(Business b) async {
    final req = ++_requestId;
    setState(() {
      _detailLoading = true;
      _detailError = null;
    });
    try {
      final results = await Future.wait([
        _service.fetchOverview(b.id),
        _service.fetchRecentComments(b.id),
      ]);
      if (!mounted || req != _requestId) return;
      setState(() {
        _overview = results[0] as StoreOverview;
        _comments = results[1] as List<StoreComment>;
        _detailLoading = false;
      });
    } on ServiceFailure catch (e) {
      if (!mounted || req != _requestId) return;
      setState(() {
        _detailError = e.message;
        _detailLoading = false;
      });
    }
  }

  void _selectBusiness(Business b) {
    if (b.id == _selected?.id) return;
    setState(() {
      _selected = b;
      _overview = null;
      _comments = const [];
      _dismissing = false;
    });
    _loadDetail(b);
  }

  Future<void> _markAllRead() async {
    final b = _selected;
    if (b == null || _markingRead || _dismissing) return;
    final unread = _comments.where((c) => !c.isRead).length;
    if (unread == 0) return;
    setState(() => _markingRead = true);
    try {
      // Simpan ke database dulu; data komentar tidak dihapus.
      await _service.markAllCommentsRead(b.id);
      if (!mounted || _selected?.id != b.id) return;
      setState(() => _dismissing = true);
      await Future.delayed(
        _kStagger * (unread - 1) +
            _kFadeDuration +
            const Duration(milliseconds: 60),
      );
      if (!mounted || _selected?.id != b.id) return;
      final o = _overview;
      setState(() {
        _comments = const [];
        _dismissing = false;
        if (o != null) {
          _overview = StoreOverview(
            listedItems: o.listedItems,
            commentCount: o.commentCount,
            unreadCount: 0,
          );
        }
      });
    } on ServiceFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _markingRead = false);
    }
  }

  Future<void> _pickBusiness() async {
    if (_businesses.length < 2) return;
    final picked = await showModalBottomSheet<Business>(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _underlined('Select Business'),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.storefront_outlined,
                    color: _green,
                    size: 22,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final b in _businesses)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        b.name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _label,
                        ),
                      ),
                      trailing: b.id == _selected?.id
                          ? const Icon(Icons.check, color: _green)
                          : null,
                      onTap: () => Navigator.pop(ctx, b),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) _selectBusiness(picked);
  }

  // ---------- Bagian konten ----------

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
          color: _label,
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
              color: _green,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _subtitle() {
    final style = GoogleFonts.poppins(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: _label,
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
          child: word('Store Owner!'),
        ),
        word('Ready'),
        word('to'),
        word('manage'),
        word('your'),
        word('business?'),
      ],
    );
  }

  String get _storeLabel {
    if (_loading) return 'Memuat...';
    if (_error != null) return 'Gagal memuat';
    return _selected?.name ?? 'Belum ada bisnis';
  }

  Widget _myBusinessRow() {
    final canSwitch = _businesses.length > 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _underlined('My Business'),
            const SizedBox(width: 6),
            const Icon(Icons.storefront_outlined, color: _green, size: 22),
          ],
        ),
        const SizedBox(width: 12),
        Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canSwitch
                ? () {
                    setState(() => _syncTurns += 1);
                    _pickBusiness();
                  }
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '\u201C$_storeLabel\u201D',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
                if (canSwitch) ...[
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _syncTurns,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                    child: const Icon(Icons.sync, color: _green, size: 22),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stat({
    required IconData icon,
    required String title,
    required String value,
    required String caption,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: _green, size: 24),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _label,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.w500,
              color: _green,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(caption, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
      ],
    );
  }

  String _statValue(int? v) {
    if (_selected == null) return '0';
    if (_detailLoading && _overview == null) return '...';
    if (v == null) return '-';
    return '$v';
  }

  Widget _storeOverview() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _stat(
              icon: Icons.view_in_ar_outlined,
              title: 'Listed Items',
              value: _statValue(_overview?.listedItems),
              caption: 'Products and services',
            ),
          ),
          Container(
            width: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            color: _green,
          ),
          Expanded(
            child: _stat(
              icon: Icons.chat_bubble_outline,
              title: 'Customer Comments',
              value: _statValue(_overview?.commentCount),
              caption: 'For selected store',
            ),
          ),
        ],
      ),
    );
  }

  int? get _readCount {
    final o = _overview;
    return o == null ? null : math.max(0, o.commentCount - o.unreadCount);
  }

  void _openAllComments() {
    final b = _selected;
    if (b == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AllCommentsPage(business: b, totalCount: _readCount),
      ),
    );
  }

  Widget _recentCommentsRow() {
    final hasUnread = (_overview?.unreadCount ?? 0) > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openAllComments,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _underlined('Recent Comments'),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.mark_chat_unread_outlined,
                    color: _green,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasUnread ? _markAllRead : null,
          child: Opacity(
            opacity: hasUnread ? 1 : 0.4,
            child: Row(
              children: [
                Text(
                  'Mark as read',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _label,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.mark_chat_read_outlined,
                  color: _green,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _message(String text, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: _grey),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Coba lagi',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _spinner() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
        ),
      ),
    );
  }

  Widget _commentCard(StoreComment c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 1),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                  child: Text(
                    c.authorMasked,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _label,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                timeAgo(c.createdAt),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            c.body,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _label,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _applyRead(String id, bool read) {
    setState(() {
      _comments = [
        for (final x in _comments)
          x.id == id
              ? StoreComment(
                  id: x.id,
                  authorMasked: x.authorMasked,
                  body: x.body,
                  createdAt: x.createdAt,
                  isRead: read,
                )
              : x,
      ];
      final o = _overview;
      if (o != null) {
        _overview = StoreOverview(
          listedItems: o.listedItems,
          commentCount: o.commentCount,
          unreadCount: math.max(0, o.unreadCount + (read ? -1 : 1)),
        );
      }
    });
  }

  Future<void> _markOneRead(StoreComment c) async {
    final b = _selected;
    if (b == null) return;
    _applyRead(c.id, true); // langsung hilang dari daftar
    try {
      await _service.markCommentRead(c.id);
    } on ServiceFailure catch (e) {
      if (!mounted) return;
      if (_selected?.id == b.id) _applyRead(c.id, false); // kembalikan
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _swipeToRead(StoreComment c) {
    return Dismissible(
      key: ValueKey('swipe-${c.id}'),
      direction: _dismissing
          ? DismissDirection.none
          : DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: 0.35},
      onDismissed: (_) => _markOneRead(c),
      background: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Read',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.done_all, color: Colors.white, size: 22),
            ],
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _commentCard(c),
      ),
    );
  }

  Widget _commentsSection() {
    if (_loading || _selected == null) return const SizedBox.shrink();
    if (_detailLoading && _comments.isEmpty) return _spinner();
    if (_detailError != null) {
      return _message(_detailError!, onRetry: () => _loadDetail(_selected!));
    }
    final unread = _comments.where((c) => !c.isRead).toList();
    if (unread.isEmpty) {
      final total = _overview?.commentCount ?? 0;
      return Padding(
        padding: const EdgeInsets.only(top: 2, bottom: 12),
        child: Center(
          child: Text(
            total == 0
                ? 'Belum ada komentar untuk toko ini.'
                : 'Semua komentar sudah dibaca.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 13, color: _grey),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < unread.length; i++)
          _FadeOutTile(
            key: ValueKey(unread[i].id),
            dismissed: _dismissing,
            delay: _kStagger * i,
            child: _swipeToRead(unread[i]),
          ),
      ],
    );
  }

  Widget _content() {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 56, 28, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Reveal(index: 0, child: _title()),
                const SizedBox(height: 16),
                Reveal(index: 1, child: _subtitle()),
                const SizedBox(height: 22),
                Reveal(index: 2, child: _myBusinessRow()),
                const SizedBox(height: 22),
                Reveal(index: 3, child: _underlined('Store Overview')),
                const SizedBox(height: 14),
                if (_loading)
                  _spinner()
                else if (_error != null)
                  _message(_error!, onRetry: _loadBusinesses)
                else if (_selected == null)
                  _message(
                    'Anda belum memiliki bisnis. Tambahkan bisnis untuk mulai mengelola.',
                  )
                else ...[
                  Reveal(index: 0, child: _storeOverview()),
                  const SizedBox(height: 24),
                  Reveal(index: 1, child: _recentCommentsRow()),
                  const SizedBox(height: 14),
                  _commentsSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- Menu melingkar ----------

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(backgroundColor: _bg, body: _content()),
        RadialNavMenu(
          current: RadialNavItem.home,
          onProfile: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          onAddStore: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const AddStorePage()))
                  .then((_) {
                    if (mounted) _loadBusinesses();
                  }),
          onEdit: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const EditStorePage()))
              .then((_) {
                if (mounted) _loadBusinesses();
              }),
        ),
      ],
    );
  }
}

const _kStagger = Duration(milliseconds: 90);
const _kFadeDuration = Duration(milliseconds: 380);

/// Membungkus satu kartu: saat [dismissed] menjadi true, kartu bergeser ke
/// kanan, memudar, lalu menciut sampai hilang dari layout.
class _FadeOutTile extends StatefulWidget {
  const _FadeOutTile({
    super.key,
    required this.child,
    required this.dismissed,
    required this.delay,
  });

  final Widget child;
  final bool dismissed;
  final Duration delay;

  @override
  State<_FadeOutTile> createState() => _FadeOutTileState();
}

class _FadeOutTileState extends State<_FadeOutTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _kFadeDuration,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant _FadeOutTile old) {
    super.didUpdateWidget(old);
    if (!old.dismissed && widget.dismissed) {
      Future.delayed(widget.delay, () {
        if (mounted && widget.dismissed) _c.forward();
      });
    } else if (old.dismissed && !widget.dismissed) {
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inverse = ReverseAnimation(_t);
    return SizeTransition(
      sizeFactor: inverse,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: inverse,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset.zero,
            end: const Offset(0.35, 0),
          ).animate(_t),
          child: widget.child,
        ),
      ),
    );
  }
}
