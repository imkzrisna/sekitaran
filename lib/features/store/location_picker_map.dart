import 'dart:async';

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

class _LocationPickerMapState extends State<LocationPickerMap> {
  static const _green = Color(0xFF103D17);
  static const _defaultCenter = LatLng(-7.7956, 110.3695); // Yogyakarta

  final _map = MapController();
  LatLng? _point;
  bool _ready = false;
  bool _syncing = false;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    widget.latController.addListener(_fromFields);
    widget.lngController.addListener(_fromFields);
    _fromFields();
  }

  @override
  void dispose() {
    widget.latController.removeListener(_fromFields);
    widget.lngController.removeListener(_fromFields);
    _map.dispose();
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', '.'));

  void _fromFields() {
    if (_syncing) return;
    final lat = _parse(widget.latController.text);
    final lng = _parse(widget.lngController.text);
    if (lat == null || lng == null) return;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return;
    final p = LatLng(lat, lng);
    if (_point == p) return;
    setState(() => _point = p);
    if (_ready) _map.move(p, _map.camera.zoom);
  }

  void _setPoint(LatLng p) {
    _syncing = true;
    widget.latController.text = p.latitude.toStringAsFixed(6);
    widget.lngController.text = p.longitude.toStringAsFixed(6);
    _syncing = false;
    setState(() => _point = p);
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
      _setPoint(p);
      if (_ready) _map.move(p, 17);
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
    _map.move(cam.center, (cam.zoom + delta).clamp(3.0, 19.0));
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
                        child: const Icon(
                          Icons.location_on,
                          color: _green,
                          size: 40,
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
