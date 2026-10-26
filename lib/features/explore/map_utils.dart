import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// True bila [p] ada di dalam area peta yang terlihat (dengan margin tepi).
bool isPointInView(MapCamera cam, LatLng p, {double inset = 0.1}) {
  final b = cam.visibleBounds;
  final dLat = (b.north - b.south) * inset;
  final dLng = (b.east - b.west) * inset;
  return p.latitude > b.south + dLat &&
      p.latitude < b.north - dLat &&
      p.longitude > b.west + dLng &&
      p.longitude < b.east - dLng;
}

/// Menggerakkan kamera peta dengan animasi halus.
class MapMover {
  MapMover(TickerProvider vsync, this.controller) {
    _anim = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 600),
    )..addListener(_tick);
  }

  final MapController controller;
  late final AnimationController _anim;
  bool ready = false;
  bool _disposed = false;
  LatLng _from = const LatLng(0, 0);
  LatLng _to = const LatLng(0, 0);
  double _z0 = 0;
  double _z1 = 0;

  void _tick() {
    if (_disposed || !ready) return;
    final t = Curves.easeInOutCubic.transform(_anim.value);
    try {
      controller.move(
        LatLng(
          _from.latitude + (_to.latitude - _from.latitude) * t,
          _from.longitude + (_to.longitude - _from.longitude) * t,
        ),
        _z0 + (_z1 - _z0) * t,
      );
    } catch (_) {
      _anim.stop();
    }
  }

  bool isVisible(LatLng p) {
    if (!ready || _disposed) return true;
    try {
      return isPointInView(controller.camera, p);
    } catch (_) {
      return true;
    }
  }

  void animateTo(LatLng target, {double? zoom}) {
    if (!ready || _disposed) return;
    final cam = controller.camera;
    _from = cam.center;
    _z0 = cam.zoom;
    _to = target;
    _z1 = zoom ?? cam.zoom;
    _anim.forward(from: 0);
  }

  /// Tarik kamera hanya jika [p] tidak terlihat.
  void reveal(LatLng p) {
    if (!isVisible(p)) animateTo(p);
  }

  void dispose() {
    _disposed = true;
    ready = false;
    _anim.removeListener(_tick);
    _anim.stop();
    _anim.dispose();
  }
}

/// Tombol bulat "lokasi saya" untuk di atas peta.
class MapLocateButton extends StatelessWidget {
  const MapLocateButton({super.key, required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  static const _green = Color(0xFF103D17);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: busy
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
}
