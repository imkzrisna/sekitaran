import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:sekitaran/features/assistant/business_assistant_page.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/explore/route_map_page.dart';
import 'package:sekitaran/features/explore/shop_detail_service.dart';
import 'package:sekitaran/features/home/business_service.dart' show timeAgo;
import 'package:sekitaran/features/home/user_radial_menu.dart';

enum _CommentSort { newest, top }

class ShopDetailPage extends StatefulWidget {
  const ShopDetailPage({super.key, required this.origin, required this.shop});

  final LatLng origin;
  final Shop shop;

  @override
  State<ShopDetailPage> createState() => _ShopDetailPageState();
}

class _ShopDetailPageState extends State<ShopDetailPage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _gold = Color(0xFFC99A4A);
  static const _routeColor = Color(0xFF2F6FED);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  final _service = ShopDetailService.instance;
  final _input = TextEditingController();

  ShopDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _posting = false;
  int _req = 0;
  _CommentSort _sort = _CommentSort.newest;
  final _busyLikes = <String>{};
  bool _showAll = false;
  static const _previewCount = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  // ---------- Logika ----------

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _load() async {
    final req = ++_req;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await _service.fetchDetail(widget.shop);
      if (!mounted || req != _req) return;
      setState(() {
        _detail = d;
        _loading = false;
      });
    } on ShopDetailFailure catch (e) {
      if (!mounted || req != _req) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _post() async {
    if (_posting) return;
    final text = _input.text.trim();
    if (text.length < ShopDetailService.minCommentLength) {
      _snack('Write at least 3 characters.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _posting = true);
    try {
      final c = await _service.postComment(widget.shop, text);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      _input.clear();
      setState(() => _detail?.comments.insert(0, c));
      _snack('Comment posted');
    } on ShopDetailFailure catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _toggleLike(ShopDetailComment c, {bool onlyLike = false}) async {
    final list = _detail?.comments;
    if (list == null || _busyLikes.contains(c.id)) return;
    if (onlyLike && c.liked) return;
    final i = list.indexWhere((x) => x.id == c.id);
    if (i < 0) return;
    final prev = list[i];
    _busyLikes.add(c.id);
    HapticFeedback.selectionClick();
    setState(() {
      list[i] = prev.copyWith(
        liked: !prev.liked,
        likeCount: (prev.likeCount + (prev.liked ? -1 : 1)).clamp(0, 1 << 30),
      );
    });
    try {
      final r = await _service.toggleLike(c.id);
      if (!mounted) return;
      final j = list.indexWhere((x) => x.id == c.id);
      if (j >= 0) {
        setState(
          () => list[j] = list[j].copyWith(liked: r.liked, likeCount: r.count),
        );
      }
    } on ShopDetailFailure catch (e) {
      if (!mounted) return;
      final j = list.indexWhere((x) => x.id == c.id);
      if (j >= 0) setState(() => list[j] = prev);
      _snack(e.message);
    } finally {
      _busyLikes.remove(c.id);
    }
  }

  List<ShopDetailComment> _sorted(List<ShopDetailComment> src) {
    final r = [...src];
    if (_sort == _CommentSort.top) {
      r.sort((a, b) {
        final c = b.likeCount.compareTo(a.likeCount);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
    } else {
      r.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return r;
  }

  void _copy(LatLng p) {
    final text =
        '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    _snack('Coordinates copied');
  }

  void _openRoute() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RouteMapPage(origin: widget.origin, shop: widget.shop),
      ),
    );
  }

  String _plain(num n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toString();

  // ---------- Komponen dasar (sama dengan halaman lain) ----------

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

  Widget _heading(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          Flexible(child: _underlined(text)),
          const SizedBox(width: 6),
          Icon(icon, color: _green, size: 22),
        ],
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
            widget.shop.name,
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
    return Container(
      padding: const EdgeInsets.only(bottom: 3),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
      ),
      child: Text(
        widget.shop.category.label,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
      ),
    );
  }

  Widget _distanceLine() {
    final m = airMeters(widget.origin, widget.shop.position);
    return Row(
      children: [
        const Icon(Icons.straighten, size: 18, color: _green),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '${formatDistance(m)} from you (straight line)',
            style: GoogleFonts.poppins(fontSize: 13, color: _grey),
          ),
        ),
      ],
    );
  }

  Widget _sampleNote() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: _gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sample data. Items and comments are not connected to the database yet.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: _ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double w, double h) => Container(
    width: w,
    height: h,
    decoration: BoxDecoration(
      color: _border.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(6),
    ),
  );

  Widget _spinner() {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(150, 18),
          const SizedBox(height: 10),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [_bar(130, 14), _bar(60, 14)],
              ),
            ),
          const SizedBox(height: 24),
          _bar(120, 18),
          const SizedBox(height: 14),
          for (var i = 0; i < 2; i++)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _bar(34, 34),
                      const SizedBox(width: 10),
                      _bar(100, 12),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _bar(double.infinity, 12),
                  const SizedBox(height: 8),
                  _bar(180, 12),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _message(String text, {VoidCallback? onRetry}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
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
                'Try again',
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

  // ---------- Lokasi ----------

  Widget _meDot() {
    return Container(
      decoration: BoxDecoration(
        color: _accent,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 6)],
      ),
    );
  }

  Widget _mapPreview() {
    return GestureDetector(
      onTap: _openRoute,
      child: Container(
        height: 190,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border.withValues(alpha: 0.7)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Peta hanya pratinjau: gestur diabaikan supaya halaman tetap
            // bisa di-scroll, dan ketukan membuka halaman rute.
            IgnorePointer(
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints([
                      widget.origin,
                      widget.shop.position,
                    ]),
                    padding: const EdgeInsets.all(48),
                    maxZoom: 17,
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.sekitaran',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [widget.origin, widget.shop.position],
                        strokeWidth: 3,
                        color: _routeColor,
                        borderStrokeWidth: 1.5,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: widget.origin,
                        width: 24,
                        height: 24,
                        child: _meDot(),
                      ),
                      Marker(
                        point: widget.shop.position,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          color: _green,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 8,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xB3FFFFFF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '\u00A9 OpenStreetMap contributors',
                  style: GoogleFonts.poppins(fontSize: 9.5, color: _grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _coordCell(String label, double value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(6),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coords() {
    final p = widget.shop.position;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _copy(p),
      child: Row(
        children: [
          Expanded(
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _coordCell('Latitude', p.latitude),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: _green,
                  ),
                  _coordCell('Longitude', p.longitude),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Icon(Icons.copy_outlined, size: 18, color: _grey),
        ],
      ),
    );
  }

  Widget _routeButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openRoute,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _green, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alt_route, size: 20, color: _green),
            const SizedBox(width: 8),
            Text(
              'See route on map',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Barang dan harga ----------

  Widget _priceRow(
    String left,
    String right, {
    String? sub,
    required bool last,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _border.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  left,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                right,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ],
          ),
          if (sub != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                sub,
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
              ),
            ),
        ],
      ),
    );
  }

  Widget _itemsSection(ShopDetail d) {
    final isExchange = widget.shop.category == ShopCategory.exchange;
    final isRestaurant = widget.shop.category == ShopCategory.restaurant;
    final title = isExchange
        ? 'Exchange Rates'
        : (isRestaurant ? 'Menu & Prices' : 'Products & Prices');
    final icon = isExchange
        ? Icons.currency_exchange
        : (isRestaurant ? Icons.restaurant_menu : Icons.inventory_2_outlined);
    final empty = isExchange ? d.rates.isEmpty : d.items.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(title, icon),
        const SizedBox(height: 6),
        if (empty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              "The owner hasn't listed anything yet.",
              style: GoogleFonts.poppins(fontSize: 13, color: _grey),
            ),
          )
        else if (isExchange)
          for (var i = 0; i < d.rates.length; i++)
            _priceRow(
              '${_plain(d.rates[i].foreignAmount)} ${d.rates[i].currencyCode}',
              formatRupiah(d.rates[i].idrAmount),
              sub: d.rates[i].serviceFee == null
                  ? null
                  : 'Service fee ${formatRupiah(d.rates[i].serviceFee!)}',
              last: i == d.rates.length - 1,
            )
        else
          for (var i = 0; i < d.items.length; i++)
            _priceRow(
              d.items[i].name,
              d.items[i].price == null
                  ? 'Price not set'
                  : formatRupiah(d.items[i].price!),
              last: i == d.items.length - 1,
            ),
      ],
    );
  }

  // ---------- Komentar ----------

  Widget _postButton(bool enabled) {
    return Opacity(
      opacity: (enabled || _posting) ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? _post : null,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _posting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Post',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  static const _loveColor = Color(0xFFE5484D);
  static const _avatarColors = [
    Color(0xFF5BAA5F),
    Color(0xFF2F6FED),
    Color(0xFFC99A4A),
    Color(0xFFE5484D),
    Color(0xFF8E5BD9),
    Color(0xFF1F9E8F),
  ];

  Color _colorFor(String name) =>
      _avatarColors[name.hashCode.abs() % _avatarColors.length];

  Widget _commentInput() {
    return ListenableBuilder(
      listenable: _input,
      builder: (context, _) {
        final len = _input.text.length;
        final can =
            _input.text.trim().length >= ShopDetailService.minCommentLength &&
            !_posting;
        final near = len >= 270;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: len > 0
                  ? _green.withValues(alpha: 0.5)
                  : _border.withValues(alpha: 0.6),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _input,
                enabled: !_posting,
                minLines: 2,
                maxLines: 6,
                maxLength: ShopDetailService.maxCommentLength,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: _ink,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Share your experience...',
                  hintStyle: GoogleFonts.poppins(
                    color: const Color(0xFF9A9A9A),
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
              Row(
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: len > 0 ? 1 : 0,
                    child: Text(
                      '$len/${ShopDetailService.maxCommentLength}',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: near ? FontWeight.w600 : FontWeight.w400,
                        color: near ? _loveColor : _grey,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _postButton(can),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pill(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loveButton(ShopDetailComment c) {
    final on = c.liked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        _toggleLike(c);
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 12, top: 2, bottom: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (w, a) => ScaleTransition(
                scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                child: w,
              ),
              child: Icon(
                on ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(on),
                size: 17,
                color: on ? _loveColor : _grey,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${c.likeCount}',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: on ? _loveColor : _grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(ShopDetailComment c, {double size = 36}) {
    final col = c.mine ? _green : _colorFor(c.author);
    final ch = c.author.isEmpty ? '?' : c.author[0].toUpperCase();
    final url = (c.avatarUrl ?? '').trim();
    final valid = url.startsWith('http://') || url.startsWith('https://');
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      color: col.withValues(alpha: 0.14),
      child: Text(
        ch,
        style: GoogleFonts.poppins(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
          color: col,
        ),
      ),
    );
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: valid
            ? Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : fallback,
              )
            : fallback,
      ),
    );
  }

  Widget _commentCard(ShopDetailComment c, {bool top = false}) {
    return _DoubleTapLove(
      onLove: () => _toggleLike(c, onlyLike: true),
      child: Container(
        width: double.infinity,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avatar(c),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                c.author,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: _ink,
                                ),
                              ),
                            ),
                            if (top) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.star_rounded,
                                size: 15,
                                color: _gold,
                              ),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              timeAgo(c.createdAt),
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: _grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _loveButton(c),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.body,
                    style: GoogleFonts.poppins(
                      fontSize: 13.5,
                      color: _ink,
                      height: 1.55,
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

  Widget _seg(String label, _CommentSort v) {
    final on = _sort == v;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_sort == v) return;
        HapticFeedback.selectionClick();
        setState(() => _sort = v);
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: on ? FontWeight.w600 : FontWeight.w400,
                color: on ? _ink : _grey,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2,
              width: on ? 22 : 0,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortToggle() {
    return Row(
      children: [
        _seg('Newest', _CommentSort.newest),
        _seg('Most loved', _CommentSort.top),
      ],
    );
  }

  Widget _emptyComments() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 26,
              color: _grey.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              'No comments yet. Be the first to share.',
              style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moreButton(int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _showAll = !_showAll),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _showAll ? 'Show less' : 'Show all $total comments',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showAll ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: _green,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _commentsSection(ShopDetail d) {
    final n = d.comments.length;
    final loves = d.comments.fold<int>(0, (a, c) => a + c.likeCount);
    final all = _sorted(d.comments);
    final list = _showAll ? all : all.take(_previewCount).toList();
    final divider = Divider(
      height: 1,
      thickness: 1,
      color: _border.withValues(alpha: 0.35),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Comments', Icons.chat_bubble_outline),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BusinessAssistantPage(
                  businessId: widget.shop.id,
                  businessName: widget.shop.name,
                ),
              ),
            );
          },
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Ask AI about all comments'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _pill(Icons.chat_bubble_outline, '$n', _green),
            const SizedBox(width: 8),
            _pill(Icons.favorite, '$loves', _loveColor),
          ],
        ),
        const SizedBox(height: 16),
        _commentInput(),
        if (n > 1) ...[const SizedBox(height: 18), _sortToggle()],
        const SizedBox(height: 6),
        if (d.commentsFailed)
          _message('Could not load comments.', onRetry: _load)
        else if (list.isEmpty)
          _emptyComments()
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: Column(
              key: ValueKey('${_sort.name}_$_showAll'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) divider,
                  _FadeIn(
                    key: ValueKey(list[i].id),
                    child: _commentCard(
                      list[i],
                      top:
                          _sort == _CommentSort.top &&
                          i == 0 &&
                          list[i].likeCount > 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (!d.commentsFailed && all.length > _previewCount)
          _moreButton(all.length),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
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
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(28, 56, 28, 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(),
                      const SizedBox(height: 12),
                      _subtitle(),
                      const SizedBox(height: 14),
                      _distanceLine(),
                      if (ShopDetailService.isSample) _sampleNote(),
                      _heading('Location', Icons.place_outlined),
                      const SizedBox(height: 12),
                      _mapPreview(),
                      const SizedBox(height: 14),
                      _coords(),
                      const SizedBox(height: 14),
                      _routeButton(),
                      if (_loading)
                        _spinner()
                      else if (_error != null)
                        _message(_error!, onRetry: _load)
                      else if (d != null) ...[
                        _itemsSection(d),
                        _commentsSection(d),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const UserRadialMenu(),
      ],
    );
  }
}

/// Memunculkan anak dengan fade dan geser tipis saat pertama kali tampil.
class _FadeIn extends StatelessWidget {
  const _FadeIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 10),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Double-tap memunculkan hati besar di atas anak, lalu memanggil [onLove].
class _DoubleTapLove extends StatefulWidget {
  const _DoubleTapLove({required this.onLove, required this.child});

  final VoidCallback onLove;
  final Widget child;

  @override
  State<_DoubleTapLove> createState() => _DoubleTapLoveState();
}

class _DoubleTapLoveState extends State<_DoubleTapLove>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTap: () {
        _c.forward(from: 0);
        widget.onLove();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) {
                  if (_c.isDismissed) return const SizedBox.shrink();
                  final t = _c.value;
                  final scale = t < 0.3
                      ? Curves.easeOutBack.transform(t / 0.3)
                      : 1.0;
                  final opacity = t < 0.6
                      ? 1.0
                      : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
                  return Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: const Icon(
                          Icons.favorite,
                          size: 64,
                          color: Color(0xFFE5484D),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
