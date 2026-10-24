import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sekitaran/features/home/user_radial_menu.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/core/indonesia_geo.dart';
import 'package:sekitaran/core/location_error_view.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/explore/map_utils.dart';
import 'package:sekitaran/features/explore/route_map_page.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';

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

  final _amount = TextEditingController(text: '1');
  LatLng? _pos;
  List<_Changer> _changers = const [];
  String? _error;
  bool _loading = false;
  String? _code;
  bool _open = false;
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
      if (!isPointInView(_mapCtl.camera, here)) {
        _animateTo(here, _mapCtl.camera.zoom);
      }
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

  /// Toko yang punya mata uang terpilih, terdekat ke terjauh (tanpa batas).
  List<_Entry> _entries(LatLng here) {
    final code = _code;
    if (code == null) return const [];
    final list = <_Entry>[];
    for (final c in _changers) {
      for (final r in c.rates) {
        if (r.code == code) {
          list.add(_Entry(c, r, airMeters(here, c.shop.position)));
          break;
        }
      }
    }
    list.sort((a, b) => a.meters.compareTo(b.meters));
    return list;
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

  // ---------- UI ----------

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

  Widget _heading(String text, IconData icon) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 12),
    child: Row(
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.only(bottom: 2),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _accent, width: 1.5)),
            ),
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Icon(icon, color: _green, size: 22),
      ],
    ),
  );

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
  );

  Widget _currencyField(List<String> codes) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: codes.isEmpty ? null : () => setState(() => _open = !_open),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _open ? _green : _border,
            width: _open ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _code ?? '-',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _ink,
                ),
              ),
            ),
            AnimatedRotation(
              turns: _open ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.keyboard_arrow_down, color: _grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _codePanel(List<String> codes) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !_open
          ? const SizedBox(width: double.infinity)
          : Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border.withValues(alpha: 0.7)),
              ),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in codes)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() {
                          _code = c;
                          _open = false;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: c == _code ? _green : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: c == _code ? _green : _border,
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            c,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: c == _code
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: c == _code ? Colors.white : _ink,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _input() {
    final codes = _codes;
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
            const SizedBox(width: 12),
            Expanded(child: _currencyField(codes)),
          ],
        ),
        _codePanel(codes),
      ],
    );
  }

  Widget _result(List<_Entry> entries) {
    final amt = _amountValue;
    String big = '-';
    String sub = 'Enter an amount to convert.';
    if (_code != null && entries.isEmpty) {
      sub = 'No money changer lists $_code yet.';
    } else if (amt != null && entries.isNotEmpty) {
      final best = _best(entries);
      big = _idr(amt * best.rate.perUnit);
      sub = 'Best rate at ${best.changer.shop.name}';
    }
    final amtText = _amount.text.trim().isEmpty ? '-' : _amount.text.trim();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 22),
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _border.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$amtText ${_code ?? ''} =',
            style: GoogleFonts.poppins(fontSize: 13, color: _grey),
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
                  color: _green,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(sub, style: GoogleFonts.poppins(fontSize: 12.5, color: _grey)),
        ],
      ),
    );
  }

  _Entry _best(List<_Entry> entries) {
    var best = entries.first;
    for (final e in entries) {
      if (e.rate.perUnit > best.rate.perUnit) best = e;
    }
    return best;
  }

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
    return Container(
      height: 240,
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
              onMapReady: () => _mapReady = true,
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

  Widget _hint(String t) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 20),
    child: Text(t, style: GoogleFonts.poppins(fontSize: 13, color: _grey)),
  );

  Widget _line(String label, String value, {bool bold = false}) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(fontSize: 12, color: _grey),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: bold ? _green : _ink,
          ),
        ),
      ],
    ),
  );

  Widget _card(_Entry e, LatLng here, {required bool best}) {
    final amt = _amountValue;
    final fee = e.rate.fee;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${e.changer.shop.id}_$_code'),
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
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RouteMapPage(origin: here, shop: e.changer.shop),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: _border.withValues(alpha: 0.6)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.changer.shop.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  if (best) ...[
                    const SizedBox(width: 8),
                    Text(
                      'Best rate',
                      style: GoogleFonts.poppins(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 22, color: _grey),
                ],
              ),
              const SizedBox(height: 4),
              _line('Distance', formatDistance(e.meters)),
              _line('Rate', '1 $_code = ${_idr(e.rate.perUnit)}'),
              if (fee != null) _line('Service fee', _idr(fee)),
              if (amt != null)
                _line('You get', _idr(amt * e.rate.perUnit), bold: true),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _map(here, entries),
        _heading('Stores offering ${_code ?? ''}', Icons.storefront_outlined),
        if (entries.isEmpty)
          _hint('No money changer offers this currency yet.')
        else
          for (final e in entries)
            _card(e, here, best: entries.length > 1 && e == _best(entries)),
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
                      _input(),
                      const SizedBox(height: 14),
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
