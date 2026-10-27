import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:sekitaran/core/app_confirm_dialog.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/store/offline/offline_store_service.dart';

/// Isi halaman Saved Places. Dipakai oleh dua halaman pembungkus:
/// OfflineStoresPage (tanpa menu) dan SavedPlacesPage (dengan menu).
class SavedPlacesView extends StatefulWidget {
  const SavedPlacesView({
    super.key,
    this.topPadding = 56,
    this.bottomPadding = 140,
  });

  /// Jarak isi dari tepi atas/bawah; diatur oleh halaman pembungkus.
  final double topPadding;
  final double bottomPadding;

  @override
  State<SavedPlacesView> createState() => _SavedPlacesViewState();
}

class _Entry {
  const _Entry(this.store, this.point, this.meters);

  final Map<String, dynamic> store;
  final LatLng? point;
  final double? meters;
}

class _SavedPlacesViewState extends State<SavedPlacesView> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  static const _categories = <(String, String)>[
    ('all', 'All'),
    ('restaurant', 'Local Restaurant'),
    ('grocery', 'Grocery Store'),
    ('money_changer', 'Money Changer'),
  ];

  final _service = OfflineStoreService.instance;

  List<Map<String, dynamic>> _stores = [];
  LatLng? _position;
  bool _locating = false;
  String? _locationMessage;
  String _category = 'all';
  final Set<String> _expanded = <String>{};
  double _syncTurns = 0;

  @override
  void initState() {
    super.initState();
    _stores = List.of(_service.getOfflineStores());
    _locate();
  }

  // ---------- Data ----------

  void _loadStores() {
    setState(() => _stores = List.of(_service.getOfflineStores()));
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _refresh() async {
    _loadStores();
    await _locate();
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationMessage = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('Turn on GPS to see your location and distances.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _fail('Location permission is needed to show your location.');
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _fail('Location permission is blocked. Enable it in the app settings.');
        return;
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      setState(() => _position = LatLng(p.latitude, p.longitude));
    } on TimeoutException {
      _fail('Could not get your location. Try again outdoors.');
    } catch (_) {
      _fail('Location unavailable. Your saved shops can still be opened.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() => _locationMessage = m);
  }

  double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('$v');

  LatLng? _storePoint(Map<String, dynamic> s) {
    final lat = _num(s['latitude']);
    final lng = _num(s['longitude']);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    if (lat == 0 && lng == 0) return null;
    return LatLng(lat, lng);
  }

  _Entry _entry(Map<String, dynamic> s) {
    final p = _storePoint(s);
    final here = _position;
    final m = (p != null && here != null) ? airMeters(here, p) : null;
    return _Entry(s, p, m);
  }

  List<_Entry> get _entries {
    final list = <_Entry>[
      for (final s in _stores)
        if (_category == 'all' || s['category']?.toString() == _category)
          _entry(s),
    ];
    list.sort((a, b) {
      final x = a.meters;
      final y = b.meters;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return list;
  }

  // ---------- Format ----------

  String _idr(Object? v) {
    if (v == null) return 'Price unavailable';
    final n = v is num ? v : num.tryParse('$v');
    if (n == null) return '$v';
    final s = n.round().toString();
    final neg = s.startsWith('-');
    final digits = neg ? s.substring(1) : s;
    final b = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
      b.write(digits[i]);
    }
    return 'Rp ${neg ? '-' : ''}$b';
  }

  String _plain(Object? v) {
    if (v == null) return '-';
    final n = v is num ? v : num.tryParse('$v');
    if (n == null) return '$v';
    return n == n.roundToDouble() ? n.round().toString() : n.toString();
  }

  String? _savedLabel(Object? v) {
    if (v == null) return null;
    DateTime? d;
    if (v is num) {
      d = DateTime.fromMillisecondsSinceEpoch(v.toInt());
    } else {
      d = DateTime.tryParse('$v')?.toLocal();
    }
    if (d == null) return 'Saved $v';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'Saved ${d.day} ${months[d.month - 1]} ${d.year}, $hh:$mm';
  }

  String _itemsTitle(String? category) => switch (category) {
    'restaurant' => 'Menu & Prices',
    'grocery' => 'Products & Prices',
    _ => 'Items & Prices',
  };

  String _categoryLabel(String? category) => switch (category) {
    'restaurant' => 'Local Restaurant',
    'grocery' => 'Grocery Store',
    'money_changer' => 'Money Changer',
    _ => 'Store',
  };

  IconData _categoryIcon(String? category) => switch (category) {
    'restaurant' => Icons.restaurant_outlined,
    'grocery' => Icons.shopping_basket_outlined,
    'money_changer' => Icons.currency_exchange,
    _ => Icons.storefront_outlined,
  };

  // ---------- Aksi ----------

  void _copy(LatLng p) {
    final text =
        '${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)}';
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.selectionClick();
    _snack('Coordinates copied');
  }

  Future<void> _removeStore(String id, String name) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove this shop?',
      message: 'The saved copy of "$name" will be removed from this device.',
      confirmLabel: 'Remove',
      destructive: true,
      icon: Icons.delete_outline,
    );
    if (!ok || !mounted) return;
    try {
      await _service.removeOfflineStore(id);
      if (!mounted) return;
      _expanded.remove(id);
      _loadStores();
      _snack('Shop removed from this device.');
    } catch (_) {
      if (!mounted) return;
      _snack('Could not remove the shop. Please try again.');
    }
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
            'Saved Places',
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
        'Shops and prices saved on this device',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
      ),
    );
  }

  Widget _heading(String text, IconData icon, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Row(
        children: [
          Flexible(child: _underlined(text)),
          const SizedBox(width: 6),
          Icon(icon, color: _green, size: 22),
          if (trailing != null) ...[const Spacer(), trailing],
        ],
      ),
    );
  }

  Widget _refreshButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _syncTurns += 1);
        _locate();
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AnimatedRotation(
          turns: _syncTurns,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          child: const Icon(Icons.sync, color: _green, size: 22),
        ),
      ),
    );
  }

  Widget _miniTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _green,
      ),
    );
  }

  // ---------- Koordinat ----------

  Widget _coordCell(String label, double value, {required bool large}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(6),
            style: GoogleFonts.poppins(
              fontSize: large ? 18 : 14.5,
              fontWeight: FontWeight.w500,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordBlock(LatLng p, {bool large = false}) {
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
                  _coordCell('Latitude', p.latitude, large: large),
                  Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: _green,
                  ),
                  _coordCell('Longitude', p.longitude, large: large),
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

  Widget _locationSection() {
    final p = _position;
    if (p != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _coordBlock(p, large: true),
          if (_locationMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _locationMessage!,
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
              ),
            ),
        ],
      );
    }
    if (_locating) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
          ),
          const SizedBox(width: 12),
          Text(
            'Finding your location...',
            style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _locationMessage ?? 'Location unavailable.',
          style: GoogleFonts.poppins(fontSize: 12.5, color: _grey, height: 1.4),
        ),
        TextButton(
          onPressed: _locate,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 36),
            alignment: Alignment.centerLeft,
          ),
          child: Text(
            'Try again',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Daftar toko ----------

  Widget _chip(String label, String value) {
    final sel = _category == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _category = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _green : _border, width: 1.2),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }

  Widget _priceRow(String left, String right, {String? sub}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  left,
                  style: GoogleFonts.poppins(fontSize: 13, color: _ink),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                right,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ],
          ),
          if (sub != null)
            Text(sub, style: GoogleFonts.poppins(fontSize: 11.5, color: _grey)),
        ],
      ),
    );
  }

  Widget _removeButton(String id, String name) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _removeStore(id, name),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade400, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, size: 18, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(
              'Remove from this device',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(_Entry e) {
    final s = e.store;
    final category = s['category']?.toString();
    final rawItems = s['items'];
    final rawRates = s['exchange_rates'];
    final items = (rawItems is List ? rawItems : const [])
        .whereType<Map>()
        .toList();
    final rates = (rawRates is List ? rawRates : const [])
        .whereType<Map>()
        .toList();
    final showItems = items.isNotEmpty || rates.isEmpty;
    final saved = _savedLabel(s['cached_at']);
    final name = s['name']?.toString() ?? 'Unnamed shop';
    final id = s['id']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 0, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _miniTitle('Shop Location'),
          const SizedBox(height: 8),
          if (e.point != null) ...[
            _coordBlock(e.point!),
            if (e.meters != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${formatDistance(e.meters!)} straight-line from you',
                  style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                ),
              ),
          ] else
            Text(
              'Location not available',
              style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
            ),
          if (showItems) ...[
            const SizedBox(height: 18),
            _miniTitle(_itemsTitle(category)),
            const SizedBox(height: 4),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Nothing saved yet.',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
                ),
              )
            else
              for (final item in items)
                _priceRow(
                  item['name']?.toString() ?? 'Item',
                  _idr(item['price']),
                ),
          ],
          if (rates.isNotEmpty) ...[
            const SizedBox(height: 18),
            _miniTitle('Exchange Rates'),
            const SizedBox(height: 4),
            for (final rate in rates)
              _priceRow(
                '${_plain(rate['foreign_amount'])} ${rate['currency_code'] ?? '-'}',
                _idr(rate['idr_amount']),
                sub: rate['service_fee_idr'] == null
                    ? null
                    : 'Service fee: ${_idr(rate['service_fee_idr'])}',
              ),
          ],
          if (saved != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                saved,
                style: GoogleFonts.poppins(fontSize: 11.5, color: _grey),
              ),
            ),
          const SizedBox(height: 16),
          _removeButton(id, name),
        ],
      ),
    );
  }

  Widget _storeRow(_Entry e, {required bool last}) {
    final s = e.store;
    final id = s['id']?.toString() ?? '';
    final name = s['name']?.toString() ?? 'Unnamed shop';
    final category = s['category']?.toString();
    final expanded = _expanded.contains(id);

    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: _border.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (expanded) {
                _expanded.remove(id);
              } else {
                _expanded.add(id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Icon(_categoryIcon(category), size: 22, color: _green),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            color: _ink,
                          ),
                        ),
                        Text(
                          _categoryLabel(category),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (e.meters != null) ...[
                    const SizedBox(width: 12),
                    Text(
                      formatDistance(e.meters!),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: _grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? _details(e)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final none = _stores.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40, color: _grey),
            const SizedBox(height: 12),
            Text(
              none ? 'No saved shops yet' : 'No saved shops in this category',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              none
                  ? "Save shops while you're online and they will show up here."
                  : 'Try another category.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: _grey,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shopList(List<_Entry> entries) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey(_category),
        child: entries.isEmpty
            ? _emptyState()
            : Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _storeRow(entries[i], last: i == entries.length - 1),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final count = _stores.length;
    final caption = count == 0
        ? 'Nothing saved yet'
        : '$count ${count == 1 ? 'shop' : 'shops'} saved on this device'
              '${_position != null ? ' \u00B7 nearest first' : ''}';

    return RefreshIndicator(
      color: _green,
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          28,
          widget.topPadding,
          28,
          widget.bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _title(),
            const SizedBox(height: 12),
            _subtitle(),
            _heading(
              'My Location',
              Icons.my_location,
              trailing: _refreshButton(),
            ),
            const SizedBox(height: 14),
            _locationSection(),
            _heading('Saved Shops', Icons.storefront_outlined),
            const SizedBox(height: 8),
            Text(
              caption,
              style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
            ),
            const SizedBox(height: 16),
            Text(
              'Category',
              style: GoogleFonts.poppins(fontSize: 13, color: _grey),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in _categories) _chip(c.$2, c.$1)],
            ),
            const SizedBox(height: 8),
            _shopList(entries),
          ],
        ),
      ),
    );
  }
}
