import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sekitaran/features/home/user_radial_menu.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/core/indonesia_geo.dart';
import 'package:sekitaran/core/location_error_view.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/explore/shop_detail_page.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/store/offline/saved_places_page.dart';
import 'package:sekitaran/features/store/offline/offline_store_service.dart';

class _Rate {
  const _Rate(this.code, this.foreign, this.idr, this.fee);
  final String code;
  final double foreign;
  final double idr;
  final double? fee;
  double get perUnit => idr / foreign;
}

class _Changer {
  const _Changer(this.shop, this.rates);
  final Shop shop;
  final List<_Rate> rates;
}

class _Entry {
  const _Entry(this.changer, this.rate, this.meters);
  final _Changer changer;
  final _Rate rate;
  final double meters;
}

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);
  static const _gold = Color(0xFFC99A4A);
  static const _radiusMeters = 10000.0; // radius maksimal 10 km

  final _amount = TextEditingController(text: '1');
  LatLng? _pos;
  List<_Changer> _changers = const [];
  String? _error;
  bool _loading = false;
  String? _code;
  final _mapCtl = MapController();
  bool _mapReady = false;
  bool _locating = false;
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  LatLng _from = const LatLng(0, 0);
  LatLng _to = const LatLng(0, 0);
  double _z0 = 13;
  double _z1 = 13;

  // Offline
  final _offline = OfflineStoreService.instance;
  final Set<String> _saving = {};
  final Set<String> _updatable = {};

  @override
  void initState() {
    super.initState();
    _anim.addListener(_tick);
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    _anim.dispose();
    _mapCtl.dispose();
    super.dispose();
  }

  // ---------- Offline ----------

  Future<void> _checkUpdates() async {
    final ids = [
      for (final c in _changers)
        if (_offline.isStoreAvailableOffline(c.shop.id)) c.shop.id,
    ];
    for (final id in ids) {
      final r = await _offline.checkForUpdate(id);
      if (!mounted) return;
      setState(() {
        if (r == true) {
          _updatable.add(id);
        } else {
          _updatable.remove(id);
        }
      });
    }
  }

  Future<void> _saveOffline(Shop shop) async {
    final wasUpdate = _updatable.contains(shop.id);
    if (_saving.contains(shop.id) ||
        (_offline.isStoreAvailableOffline(shop.id) && !wasUpdate)) {
      return;
    }
    setState(() => _saving.add(shop.id));
    try {
      await _offline.savePublicStoreForOffline(shop.id);
      if (!mounted) return;
      setState(() => _updatable.remove(shop.id));
      _snack(
        wasUpdate
            ? 'Data ${shop.name} berhasil diperbarui.'
            : 'Toko ${shop.name} berhasil disimpan untuk offline.',
      );
    } on OfflineStoreFailure catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) {
        _snack('Gagal menyimpan toko offline. Coba lagi saat online.');
      }
    } finally {
      if (mounted) setState(() => _saving.remove(shop.id));
    }
  }

  Future<void> _openOfflineStores() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SavedPlacesPage()));
    if (mounted) {
      setState(() {});
      _checkUpdates();
    }
  }

  // ---------- Data ----------

  double? _num(Object? v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));

  Future<List<_Changer>> _fetch() async {
    final rows = await Supabase.instance.client
        .from('businesses')
        .select(
          'id, name, latitude, longitude, '
          'exchange_rates(currency_code, foreign_amount, idr_amount, '
          'service_fee_idr)',
        )
        .eq('category', 'money_changer')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .limit(500);
    final out = <_Changer>[];
    for (final r in rows) {
      final lat = _num(r['latitude']);
      final lng = _num(r['longitude']);
      if (lat == null || lng == null) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      if (lat == 0 && lng == 0) continue;
      final rates = <_Rate>[];
      for (final x in (r['exchange_rates'] as List? ?? const [])) {
        final foreign = _num(x['foreign_amount']);
        final idr = _num(x['idr_amount']);
        if (foreign == null || foreign <= 0 || idr == null) continue;
        rates.add(
          _Rate(
            x['currency_code'] as String,
            foreign,
            idr,
            _num(x['service_fee_idr']),
          ),
        );
      }
      out.add(
        _Changer(
          Shop(
            id: r['id'] as String,
            name: r['name'] as String,
            category: ShopCategory.exchange,
            position: LatLng(lat, lng),
          ),
          rates,
        ),
      );
    }
    return out;
  }

  Future<Position> _position() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw 'Location service is off. Turn on GPS and try again.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw 'Location permission was denied.';
    }
    if (perm == LocationPermission.deniedForever) {
      throw 'Location permission is blocked. Enable it in the app settings.';
    }
    final p = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    if (!isInIndonesiaCoord(p.latitude, p.longitude)) {
      throw kIndonesiaOnlyMessage;
    }
    return p;
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await _position();
      final list = await _fetch();
      if (!mounted) return;
      setState(() {
        _pos = LatLng(p.latitude, p.longitude);
        _changers = list;
        final codes = _codes;
        if (_code == null || !codes.contains(_code)) {
          _code = codes.contains('USD')
              ? 'USD'
              : (codes.isEmpty ? null : codes.first);
        }
      });
      _fitSoon();
      _checkUpdates();
    } on TimeoutException {
      if (mounted) setState(() => _error = 'Could not get your location.');
    } on String catch (m) {
      if (mounted) setState(() => _error = m);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load money changers.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------- Peta ----------

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  void _tick() {
    final t = Curves.easeInOutCubic.transform(_anim.value);
    _mapCtl.move(
      LatLng(
        _from.latitude + (_to.latitude - _from.latitude) * t,
        _from.longitude + (_to.longitude - _from.longitude) * t,
      ),
      _z0 + (_z1 - _z0) * t,
    );
  }

  void _animateTo(LatLng target, double zoom) {
    if (!_mapReady) return;
    final cam = _mapCtl.camera;
    _from = cam.center;
    _z0 = cam.zoom;
    _to = target;
    _z1 = zoom;
    _anim.forward(from: 0);
  }

  Future<void> _recenter() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final p = await _position();
      if (!mounted) return;
      final here = LatLng(p.latitude, p.longitude);
      setState(() => _pos = here);
      _fitSoon();
    } on TimeoutException {
      if (mounted) _snack('Could not get your location.');
    } on String catch (m) {
      if (mounted) _snack(m);
    } catch (_) {
      if (mounted) _snack('Could not get your location.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Zoom agar posisi pengguna dan semua toko dalam 10 km terlihat.
  void _fitNearby() {
    final here = _pos;
    if (here == null || !_mapReady || !mounted) return;
    final list = _entries(here);
    if (list.isEmpty) {
      _animateTo(here, 15);
      return;
    }
    final cam = CameraFit.coordinates(
      coordinates: [here, ...list.map((e) => e.changer.shop.position)],
      padding: const EdgeInsets.all(48),
      maxZoom: 17,
    ).fit(_mapCtl.camera);
    _animateTo(cam.center, cam.zoom);
  }

  void _fitSoon() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitNearby());

  // ---------- Logika ----------

  /// Mata uang yang benar-benar dijual oleh minimal satu toko.
  List<String> get _codes => ({
    for (final c in _changers)
      for (final r in c.rates) r.code,
  }.toList()..sort());

  double? get _amountValue {
    final v = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  /// Toko yang punya mata uang terpilih, terdekat ke terjauh.
  List<_Entry> _entries(LatLng here) {
    final code = _code;
    if (code == null) return const [];
    final list = <_Entry>[];
    for (final c in _changers) {
      for (final r in c.rates) {
        if (r.code == code) {
          final m = airMeters(here, c.shop.position);
          if (m <= _radiusMeters) list.add(_Entry(c, r, m));
          break;
        }
      }
    }
    list.sort((a, b) => a.meters.compareTo(b.meters));
    return list;
  }

  _Entry _best(List<_Entry> entries) {
    var best = entries.first;
    for (final e in entries) {
      if (e.rate.perUnit > best.rate.perUnit) best = e;
    }
    return best;
  }

  String _idr(double v) {
    final s = v < 100 ? v.toStringAsFixed(2) : v.round().toString();
    final parts = s.split('.');
    final int = parts[0];
    final b = StringBuffer();
    for (var i = 0; i < int.length; i++) {
      if (i > 0 && (int.length - i) % 3 == 0) b.write('.');
      b.write(int[i]);
    }
    return 'Rp $b${parts.length > 1 ? ',${parts[1]}' : ''}';
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
            'Currency',
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
        'Compare rates from money changers near you',
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
          if (trailing != null)
            _underlined(text)
          else
            Flexible(child: _underlined(text)),
          const SizedBox(width: 6),
          Icon(icon, color: _green, size: 22),
          if (trailing != null) ...[const Spacer(), trailing],
        ],
      ),
    );
  }

  InputDecoration _deco(String label) {
    OutlineInputBorder ob(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(fontSize: 13.5, color: _grey),
      floatingLabelStyle: GoogleFonts.poppins(
        fontSize: 13.5,
        color: _green,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      prefixIcon: const Icon(Icons.payments_outlined, color: _green, size: 20),
      border: ob(_border.withValues(alpha: 0.6)),
      enabledBorder: ob(_border.withValues(alpha: 0.6)),
      focusedBorder: ob(_green, 1.4),
    );
  }

  Widget _codeBadge() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.currency_exchange, size: 18, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            _code ?? '-',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _input() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: _deco('Amount'),
              ),
            ),
            const SizedBox(width: 14),
            _codeBadge(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Pick the currency from the list below',
          style: GoogleFonts.poppins(fontSize: 11.5, color: _grey),
        ),
      ],
    );
  }

  Widget _result(List<_Entry> entries) {
    final amt = _amountValue;
    String big = '-';
    String sub = 'Enter an amount to convert.';
    var star = false;
    if (_code != null && entries.isEmpty) {
      sub = 'No money changer lists $_code yet.';
    } else if (amt != null && entries.isNotEmpty) {
      final best = _best(entries);
      big = _idr(amt * best.rate.perUnit);
      sub = 'Best rate at ${best.changer.shop.name}';
      star = true;
    }
    final amtText = _amount.text.trim().isEmpty ? '-' : _amount.text.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _green.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -14,
            child: Icon(
              Icons.payments_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$amtText ${_code ?? ''} =',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: FittedBox(
                    key: ValueKey(big),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      big,
                      style: GoogleFonts.poppins(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (star) ...[
                      const Icon(Icons.star_rounded, size: 16, color: _gold),
                      const SizedBox(width: 4),
                    ],
                    Flexible(
                      child: Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Peta ----------

  Widget _locateButton() {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _locating ? null : _recenter,
        child: SizedBox(
          width: 42,
          height: 42,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _locating
                ? const Padding(
                    key: ValueKey('busy'),
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _green,
                    ),
                  )
                : const Icon(
                    Icons.my_location,
                    key: ValueKey('idle'),
                    size: 21,
                    color: _green,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _map(LatLng here, List<_Entry> entries) {
    final showStar = entries.length > 1;
    return Container(
      height: 200,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.7)),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapCtl,
            options: MapOptions(
              initialCenter: here,
              initialZoom: 13,
              onMapReady: () {
                _mapReady = true;
                _fitSoon();
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
                  for (final e in entries)
                    if (!(showStar && e == _best(entries)))
                      Marker(
                        point: e.changer.shop.position,
                        width: 30,
                        height: 30,
                        alignment: Alignment.topCenter,
                        child: const Icon(
                          Icons.location_on,
                          color: _green,
                          size: 30,
                        ),
                      ),
                  if (showStar)
                    Marker(
                      point: _best(entries).changer.shop.position,
                      width: 48,
                      height: 48,
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Color(0x55000000), blurRadius: 6),
                          ],
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          color: _gold,
                          size: 34,
                        ),
                      ),
                    ),
                  Marker(
                    point: here,
                    width: 26,
                    height: 26,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Color(0x55000000), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          Positioned(right: 10, bottom: 10, child: _locateButton()),
        ],
      ),
    );
  }

  // ---------- Daftar money changer ----------

  Widget _hint(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(t, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
  );

  Widget _chip(String code) {
    final sel = code == _code;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _code = code);
        _fitSoon();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: sel ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? _green : _border, width: 1.2),
        ),
        child: Text(
          code,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
            color: sel ? Colors.white : _ink,
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Icon(icon, size: 13, color: _grey),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontSize: 11.5, color: _grey),
          ),
        ),
      ],
    ),
  );

  Widget _row(_Entry e, LatLng here, {required bool best, required bool last}) {
    final amt = _amountValue;
    final fee = e.rate.fee;
    final shop = e.changer.shop;
    final isSaved = _offline.isStoreAvailableOffline(shop.id);
    final isSaving = _saving.contains(shop.id);
    final hasUpdate = _updatable.contains(shop.id);
    final dist = fee == null
        ? formatDistance(e.meters)
        : '${formatDistance(e.meters)}  ·  Fee ${_idr(fee)}';

    return TweenAnimationBuilder<double>(
      key: ValueKey('${shop.id}_$_code'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 12),
          child: child,
        ),
      ),
      child: _Press(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ShopDetailPage(origin: here, shop: shop),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: last
                ? null
                : Border(
                    bottom: BorderSide(color: _border.withValues(alpha: 0.45)),
                  ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _green.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.currency_exchange,
                  size: 22,
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            shop.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: _ink,
                            ),
                          ),
                        ),
                        if (best) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: _gold,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'Best rate',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _gold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    _meta(
                      Icons.payments_outlined,
                      '1 $_code = ${_idr(e.rate.perUnit)}',
                    ),
                    _meta(Icons.near_me_outlined, dist),
                    if (hasUpdate)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Update available',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _accent,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 4),
                    child: Text(
                      amt != null
                          ? _idr(amt * e.rate.perUnit)
                          : formatDistance(e.meters),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        tooltip: hasUpdate
                            ? 'Perbarui data offline'
                            : (isSaved
                                  ? 'Tersimpan offline'
                                  : 'Simpan untuk offline'),
                        onPressed: (isSaving || (isSaved && !hasUpdate))
                            ? null
                            : () => _saveOffline(shop),
                        icon: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                hasUpdate
                                    ? Icons.sync_problem_outlined
                                    : (isSaved
                                          ? Icons.offline_pin
                                          : Icons
                                                .download_for_offline_outlined),
                                color: hasUpdate
                                    ? _accent
                                    : (isSaved ? _green : _grey),
                              ),
                      ),
                      const Icon(Icons.chevron_right, size: 22, color: _grey),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stores() {
    final here = _pos;
    if (_loading && here == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }
    if (here == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: LocationErrorView(
            message: _error ?? 'Turn on location to find money changers.',
            onRetry: _load,
          ),
        ),
      );
    }
    final entries = _entries(here);
    final codes = _codes;
    final bestE = entries.length > 1 ? _best(entries) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading('My Location', Icons.my_location),
        const SizedBox(height: 12),
        _map(here, entries),
        _heading(
          'Money Changers',
          Icons.currency_exchange,
          trailing: TextButton.icon(
            onPressed: _openOfflineStores,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: _green,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.offline_pin_outlined, size: 20),
            label: Text(
              'Offline Stores',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${entries.length} within 10 km, nearest first',
          style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
        ),
        const SizedBox(height: 14),
        Text(
          'Currency',
          style: GoogleFonts.poppins(fontSize: 13, color: _grey),
        ),
        const SizedBox(height: 8),
        if (codes.isEmpty)
          _hint('No currency available yet.')
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < codes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  _chip(codes[i]),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          _hint('No money changer within 10 km offers this currency.')
        else
          for (var i = 0; i < entries.length; i++)
            _row(
              entries[i],
              here,
              best: bestE != null && entries[i] == bestE,
              last: i == entries.length - 1,
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final here = _pos;
    final entries = here == null ? const <_Entry>[] : _entries(here);
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
                      const SizedBox(height: 14),
                      _subtitle(),
                      _heading('Convert to Rupiah', Icons.currency_exchange),
                      const SizedBox(height: 12),
                      _input(),
                      _result(entries),
                      _stores(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const UserRadialMenu(current: RadialNavItem.currency),
      ],
    );
  }
}

/// Efek tekan halus: mengecil sedikit saat disentuh.
class _Press extends StatefulWidget {
  const _Press({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
