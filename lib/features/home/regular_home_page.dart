import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/explore/map_utils.dart';
import 'package:sekitaran/features/explore/currency_page.dart';
import 'package:sekitaran/features/explore/route_map_page.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/profile/profile_page.dart';

class RegularHomePage extends StatefulWidget {
  const RegularHomePage({super.key});

  @override
  State<RegularHomePage> createState() => _RegularHomePageState();
}

class _RegularHomePageState extends State<RegularHomePage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  final _mapCtl = MapController();
  late final _mover = MapMover(this, _mapCtl);
  bool _mapReady = false;
  LatLng? _pos;
  bool _locating = false;
  String? _locError;
  List<Shop> _shops = const [];
  ShopCategory? _filter; // null = semua kategori
  static const _radiusMeters = 5000.0; // radius maksimal 5 km
  String? _shopsError;

  @override
  void initState() {
    super.initState();
    _loadShops();
    _locate();
  }

  @override
  void dispose() {
    _mover.dispose();
    _mapCtl.dispose();
    super.dispose();
  }

  // ---------- Data ----------

  String get _username {
    final v =
        Supabase.instance.client.auth.currentUser?.userMetadata?['username'];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : 'there';
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _loadShops() async {
    try {
      final shops = await fetchShops();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _shopsError = null;
      });
    } on ShopsFailure catch (e) {
      if (mounted) setState(() => _shopsError = e.message);
    }
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _fail('Location service is off. Turn on GPS and try again.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _fail('Location permission was denied.');
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
      final here = LatLng(p.latitude, p.longitude);
      setState(() {
        _pos = here;
      });
      if (_mapReady) _mover.reveal(here);
    } on TimeoutException {
      _fail('Could not get your location. Try again outdoors.');
    } catch (_) {
      _fail('Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _fail(String m) {
    if (!mounted) return;
    if (_pos == null) {
      setState(() => _locError = m);
    } else {
      _snack(m);
    }
  }

  List<Shop> get _visibleShops {
    final here = _pos;
    return [
      for (final s in _shops)
        if (s.category != ShopCategory.exchange &&
            (_filter == null || s.category == _filter) &&
            (here == null || airMeters(here, s.position) <= _radiusMeters))
          s,
    ];
  }

  List<ShopDistance> _nearest(LatLng here) {
    final list = [
      for (final s in _visibleShops)
        ShopDistance(s, airMeters(here, s.position)),
    ]..sort((a, b) => a.meters.compareTo(b.meters));
    return list; // ascending: terdekat sampai terjauh (maks 5 km)
  }

  // ---------- Komponen dasar ----------

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

  // ---------- Peta lokasi ----------

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

  Widget _liveMap(LatLng here) {
    return FlutterMap(
      mapController: _mapCtl,
      options: MapOptions(
        initialCenter: here,
        initialZoom: 17,
        onMapReady: () {
          _mapReady = true;
          _mover.ready = true;
        },
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.drag | InteractiveFlag.pinchZoom,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.sekitaran',
        ),
        MarkerLayer(
          markers: [
            for (final s in _visibleShops)
              Marker(
                point: s.position,
                width: 30,
                height: 30,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on, color: _green, size: 30),
              ),
            Marker(point: here, width: 26, height: 26, child: _meDot()),
          ],
        ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('\u00A9 OpenStreetMap contributors'),
          ],
        ),
      ],
    );
  }

  Widget _mapPlaceholder() {
    final failed = _locError != null;
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: failed
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off_outlined, color: _grey, size: 30),
                const SizedBox(height: 8),
                Text(
                  _locError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: _grey,
                    height: 1.4,
                  ),
                ),
                TextButton(
                  onPressed: _locate,
                  child: Text(
                    'Try again',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Finding your location...',
                  style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
                ),
              ],
            ),
    );
  }

  Widget _mapBox() {
    final here = _pos;
    return Container(
      height: 200,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.7)),
      ),
      child: here == null
          ? _mapPlaceholder()
          : Stack(
              fit: StackFit.expand,
              children: [
                _liveMap(here),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: MapLocateButton(busy: _locating, onTap: _locate),
                ),
              ],
            ),
    );
  }

  // ---------- Toko terdekat ----------

  Widget _chip(String label, ShopCategory? value) {
    final sel = _filter == value;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _filter = value),
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

  Widget _hint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
    );
  }

  Widget _shopRow(ShopDistance d, LatLng here, {required bool last}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RouteMapPage(origin: here, shop: d.shop),
        ),
      ),
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
            Icon(d.shop.category.icon, size: 22, color: _green),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.shop.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                  ),
                  Text(
                    d.shop.category.label,
                    style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatDistance(d.meters),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 22, color: _grey),
          ],
        ),
      ),
    );
  }

  Widget _shopList() {
    final here = _pos;
    if (here == null) {
      return _hint('Nearby shops appear once your location is found.');
    }
    if (_shopsError != null) return _hint(_shopsError!);
    final items = _nearest(here);
    if (items.isEmpty) return _hint('No shops within 5 km for this category yet.');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Column(
        key: ValueKey(_filter),
        children: [
          for (var i = 0; i < items.length; i++)
            _shopRow(items[i], here, last: i == items.length - 1),
        ],
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
                      _heading('Local Time', Icons.schedule),
                      const SizedBox(height: 14),
                      const _ZoneClocks(),
                      _heading(
                        'My Location',
                        Icons.my_location,
                      ),
                      const SizedBox(height: 12),
                      _mapBox(),
                      _heading('Nearest Shop', Icons.storefront_outlined),
                      const SizedBox(height: 14),
                      Text(
                        'Category',
                        style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _chip('All', null),
                          for (final c in ShopCategory.values)
                            if (c != ShopCategory.exchange) _chip(c.label, c),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _shopList(),
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
          onExplore: () => _snack('Coming soon'),
          onCurrency: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CurrencyPage()),
          ),
        ),
      ],
    );
  }
}

/// Jam WIB / WITA / WIT. Hanya jam dan menit, diperbarui tiap pergantian menit.
class _ZoneClocks extends StatefulWidget {
  const _ZoneClocks();

  @override
  State<_ZoneClocks> createState() => _ZoneClocksState();
}

class _ZoneClocksState extends State<_ZoneClocks> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _grey = Color(0xFF7A7A7A);
  static const _zones = [('WIB', 7), ('WITA', 8), ('WIT', 9)];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(next.difference(now) + const Duration(milliseconds: 50), () {
      if (!mounted) return;
      setState(() {});
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _time(int offsetHours) {
    final t = DateTime.now().toUtc().add(Duration(hours: offsetHours));
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _zone(String label, int offset, bool mine) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 2),
          decoration: mine
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _accent, width: 1.5),
                  ),
                )
              : null,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: mine ? _ink : _grey,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _time(offset),
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: _green,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = DateTime.now().timeZoneOffset.inHours;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _zones.length; i++) ...[
            if (i > 0)
              Container(
                width: 1.5,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: _green,
              ),
            Expanded(
              child: _zone(_zones[i].$1, _zones[i].$2, local == _zones[i].$2),
            ),
          ],
        ],
      ),
    );
  }
}
