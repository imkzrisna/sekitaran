import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/explore/route_map_page.dart';
import 'package:sekitaran/features/explore/shop_detail_service.dart';
import 'package:sekitaran/features/home/business_service.dart' show timeAgo;
import 'package:sekitaran/features/home/user_radial_menu.dart';

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

  Widget _spinner() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
        ),
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

  InputDecoration _inputDecoration(String hint) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: 1.2),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        color: const Color(0xFF9A9A9A),
        fontSize: 14,
        fontWeight: FontWeight.w300,
      ),
      counterText: '',
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: border(_border),
      disabledBorder: border(_border),
      focusedBorder: border(_green),
    );
  }

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

  Widget _commentInput() {
    return ListenableBuilder(
      listenable: _input,
      builder: (context, _) {
        final can =
            _input.text.trim().length >= ShopDetailService.minCommentLength &&
            !_posting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _input,
              enabled: !_posting,
              minLines: 3,
              maxLines: 6,
              maxLength: ShopDetailService.maxCommentLength,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.poppins(fontSize: 14, color: _ink),
              decoration: _inputDecoration(
                'Write a comment about this shop...',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${_input.text.length}/${ShopDetailService.maxCommentLength}',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: _grey),
                ),
                const Spacer(),
                _postButton(can),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _commentCard(ShopDetailComment c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
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
                    c.author,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _ink,
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
              color: _ink,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _commentsSection(ShopDetail d) {
    final n = d.comments.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('Comments', Icons.chat_bubble_outline),
        const SizedBox(height: 8),
        Text(
          n == 0
              ? 'Share your experience with this shop.'
              : '$n ${n == 1 ? 'comment' : 'comments'}',
          style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
        ),
        const SizedBox(height: 14),
        _commentInput(),
        const SizedBox(height: 6),
        if (d.comments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No comments yet. Be the first!',
              style: GoogleFonts.poppins(fontSize: 13, color: _grey),
            ),
          )
        else
          for (final c in d.comments)
            _FadeIn(key: ValueKey(c.id), child: _commentCard(c)),
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
