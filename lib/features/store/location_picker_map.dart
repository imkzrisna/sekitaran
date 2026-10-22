import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    required this.latController,
    required this.lngController,
    this.height = 220,
    this.onMessage,
  });

  final TextEditingController latController;
  final TextEditingController lngController;
  final double height;
  final void Function(String message)? onMessage;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _defaultCenter = LatLng(-7.7956, 110.3695); // Yogyakarta

  final _map = MapController();
  LatLng? _point;
  bool _ready = false;
  bool _syncing = false;
  bool _locating = false;

  // ---- Animasi kamera ----
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeInOutCubic,
  );
  LatLng _from = _defaultCenter;
  LatLng _to = _defaultCenter;
  double _z0 = 13;
  double _z1 = 13;
  double _dip = 0;

  Timer? _debounce;
  Duration _pinDelay = Duration.zero;

  @override
  void initState() {
    super.initState();
    _anim.addListener(_tick);
    widget.latController.addListener(_fromFields);
    widget.lngController.addListener(_fromFields);
    _fromFields();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.latController.removeListener(_fromFields);
    widget.lngController.removeListener(_fromFields);
    _anim.dispose();
    _map.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  LatLng? _readFields() {
    final lat = _parse(widget.latController.text);
    final lng = _parse(widget.lngController.text);
    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  // ---------- Kamera ----------

  void _tick() {
    if (!_ready) return;
    final t = _curve.value;
    final center = LatLng(
      _from.latitude + (_to.latitude - _from.latitude) * t,
      _from.longitude + (_to.longitude - _from.longitude) * t,
    );
    // Zoom turun sebentar di tengah perjalanan (efek "terbang") untuk jarak jauh
    final zoom = _z0 + (_z1 - _z0) * t - _dip * math.sin(math.pi * _anim.value);
    _map.move(center, math.min(19.0, math.max(3.0, zoom)));
  }

  /// Menggeser kamera ke [target] dengan animasi.
  /// Mengembalikan durasinya (Duration.zero bila tidak beranimasi).
  Duration _flyTo(LatLng target, {double? zoom}) {
    if (!_ready) return Duration.zero;
    final cam = _map.camera;
    final from = cam.center;
    final z0 = cam.zoom;
    final z1 = math.min(19.0, math.max(3.0, zoom ?? math.max(z0, 16.0)));

    final dLat = target.latitude - from.latitude;
    final dLng = target.longitude - from.longitude;
    final km = math.sqrt(dLat * dLat + dLng * dLng) * 111.0;
    if (km < 0.003 && (z1 - z0).abs() < 0.05) return Duration.zero;

    final spread = math.log(km + 1) / math.ln2;
    final ms = math.min(1200.0, math.max(450.0, 450 + 140 * spread));

    _from = from;
    _to = target;
    _z0 = z0;
    _z1 = z1;
    _dip = km < 0.3 ? 0.0 : math.min(2.5, spread * 0.5);

    final d = Duration(milliseconds: ms.round());
    _anim.duration = d;
    _anim.forward(from: 0);
    return d;
  }

  // ---------- Sinkron field <-> peta ----------

  void _fromFields() {
    if (_syncing) return;
    final p = _readFields();
    if (p == null) return;

    // Sebelum peta siap (mis. saat pertama dibuka): langsung tampilkan.
    if (!_ready) {
      if (_point != p) setState(() => _point = p);
      return;
    }

    // Tunggu sebentar agar ketikan / pengisian dua kolom digabung jadi satu gerakan.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final q = _readFields();
      if (q == null || q == _point) return;
      final d = _flyTo(q);
      setState(() {
        _pinDelay = d * 0.7; // pin jatuh saat kamera hampir tiba
        _point = q;
      });
    });
  }

  void _setPoint(LatLng p, {Duration pinDelay = Duration.zero}) {
    _syncing = true;
    widget.latController.text = p.latitude.toStringAsFixed(6);
    widget.lngController.text = p.longitude.toStringAsFixed(6);
    _syncing = false;
    setState(() {
      _pinDelay = pinDelay;
      _point = p;
    });
  }

  void _msg(String m) => widget.onMessage?.call(m);

  Future<void> _locate() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _msg('Layanan lokasi nonaktif. Aktifkan GPS lalu coba lagi.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        _msg('Izin lokasi ditolak.');
        return;
      }
      if (perm == LocationPermission.deniedForever) {
        _msg('Izin lokasi ditolak permanen. Aktifkan di pengaturan aplikasi.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
      final p = LatLng(pos.latitude, pos.longitude);
      final d = _flyTo(p, zoom: 17);
      _setPoint(p, pinDelay: d * 0.7);
    } on TimeoutException {
      _msg('Lokasi tidak ditemukan. Coba lagi di tempat terbuka.');
    } catch (_) {
      _msg('Gagal mengambil lokasi.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _zoom(double delta) {
    if (!_ready) return;
    final cam = _map.camera;
    // Bila animasi masih berjalan, acuannya zoom tujuan agar ketukan beruntun terakumulasi
    final base = _anim.isAnimating ? _z1 : cam.zoom;
    _flyTo(cam.center, zoom: base + delta);
  }

  Widget _btn(IconData icon, VoidCallback? onTap, {bool busy = false}) {
    return Material(
      color: Colors.white,
      elevation: 1,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(9),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                )
              : Icon(icon, size: 20, color: _green),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: _point ?? _defaultCenter,
                initialZoom: _point == null ? 13 : 17,
                onMapReady: () => _ready = true,
                // Sentuhan pengguna menghentikan animasi agar tidak berebut kendali
                onPositionChanged: (_, hasGesture) {
                  if (hasGesture && _anim.isAnimating) _anim.stop();
                },
                onTap: (_, p) => _setPoint(p),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.sekitaran',
                ),
                if (_point != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _point!,
                        width: 40,
                        height: 40,
                        alignment: Alignment.topCenter,
                        child: _PinDrop(
                          key: ValueKey(_point),
                          delay: _pinDelay,
                        ),
                      ),
                    ],
                  ),
                const RichAttributionWidget(
                  alignment: AttributionAlignment.bottomLeft,
                  attributions: [
                    TextSourceAttribution('\u00A9 OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                children: [
                  _btn(Icons.my_location, _locate, busy: _locating),
                  const SizedBox(height: 6),
                  _btn(Icons.add, () => _zoom(1)),
                  const SizedBox(height: 6),
                  _btn(Icons.remove, () => _zoom(-1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pin yang jatuh dan memantul pelan saat muncul di titik baru.
class _PinDrop extends StatefulWidget {
  const _PinDrop({super.key, required this.delay});

  final Duration delay;

  @override
  State<_PinDrop> createState() => _PinDropState();
}

class _PinDropState extends State<_PinDrop>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _v = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOutBack,
  );
  Timer? _t;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      _t = Timer(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _v,
      builder: (context, child) {
        final v = _v.value;
        return Opacity(
          opacity: math.min(1.0, math.max(0.0, v)),
          child: Transform.translate(
            offset: Offset(0, -(1 - v) * 28),
            child: Transform.scale(
              scale: 0.7 + 0.3 * v,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
      child: const Icon(Icons.location_on, color: _green, size: 40),
    );
  }
}
