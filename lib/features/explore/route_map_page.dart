import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/explore/map_utils.dart';
import 'package:sekitaran/features/chat/global_chat_page.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/profile/profile_page.dart';

enum RouteMode { air, road }

class RouteMapPage extends StatefulWidget {
  const RouteMapPage({super.key, required this.origin, required this.shop});

  final LatLng origin;
  final Shop shop;

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

class _RouteMapPageState extends State<RouteMapPage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _routeColor = Color(0xFF2F6FED); // garis rute (kedua mode)
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);

  final _mapCtl = MapController();
  late final _mover = MapMover(this, _mapCtl);
  bool _ready = false;
  RouteMode _mode = RouteMode.air;
  RoadRoute? _road;
  bool _loadingRoad = false;
  String? _roadError;

  @override
  void dispose() {
    _mover.dispose();
    _mapCtl.dispose();
    super.dispose();
  }

  // ---------- Logika ----------

  List<LatLng> get _fitPoints => (_mode == RouteMode.road && _road != null)
      ? _road!.points
      : [widget.origin, widget.shop.position];

  void _fit() {
    if (!_ready) return;
    _mapCtl.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_fitPoints),
        padding: const EdgeInsets.all(56),
        maxZoom: 18,
      ),
    );
  }

  void _setMode(RouteMode m) {
    if (m == _mode) return;
    setState(() => _mode = m);
    if (m == RouteMode.road && _road == null && !_loadingRoad) {
      _loadRoad();
    } else {
      _fit();
    }
  }

  Future<void> _loadRoad() async {
    setState(() {
      _loadingRoad = true;
      _roadError = null;
    });
    try {
      final r = await fetchRoadRoute(widget.origin, widget.shop.position);
      if (!mounted) return;
      setState(() {
        _road = r;
        _loadingRoad = false;
      });
      if (_mode == RouteMode.road) _fit();
    } on RouteFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _roadError = e.message;
        _loadingRoad = false;
      });
    }
  }

  void _soon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Coming soon')));
  }

  // ---------- Komponen ----------

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

  Widget _mapButton(IconData icon, VoidCallback onTap) {
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
          child: Icon(icon, size: 20, color: _green),
        ),
      ),
    );
  }

  Widget _mapView() {
    final showRoad = _mode == RouteMode.road && _road != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            mapController: _mapCtl,
            options: MapOptions(
              initialCameraFit: CameraFit.bounds(
                bounds: LatLngBounds.fromPoints([
                  widget.origin,
                  widget.shop.position,
                ]),
                padding: const EdgeInsets.all(56),
                maxZoom: 18,
              ),
              onMapReady: () {
                _ready = true;
                _mover.ready = true;
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.sekitaran',
              ),
              PolylineLayer(
                polylines: [
                  if (showRoad)
                    Polyline(
                      points: _road!.points,
                      strokeWidth: 5,
                      color: _routeColor,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    )
                  else
                    Polyline(
                      points: [widget.origin, widget.shop.position],
                      strokeWidth: 5,
                      color: _routeColor,
                      borderStrokeWidth: 2,
                      borderColor: Colors.white,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.origin,
                    width: 28,
                    height: 28,
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
                  Marker(
                    point: widget.shop.position,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: const Icon(
                      Icons.location_on,
                      color: _green,
                      size: 44,
                    ),
                  ),
                ],
              ),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                attributions: [
                  TextSourceAttribution('\u00A9 OpenStreetMap contributors'),
                  TextSourceAttribution('Routing: OSRM'),
                ],
              ),
            ],
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _mapButton(Icons.center_focus_strong_outlined, _fit),
          ),
          Positioned(
            top: 52,
            right: 8,
            child: _mapButton(Icons.my_location, () {
              if (_mover.isVisible(widget.origin)) {
                _fit();
              } else {
                _mover.animateTo(widget.origin);
              }
            }),
          ),
          if (_loadingRoad && _mode == RouteMode.road)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color(0x22000000),
                  child: Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _green,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _segment(RouteMode m, IconData icon, String label) {
    final sel = _mode == m;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setMode(m),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: sel ? Colors.white : _green),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                  color: sel ? Colors.white : _ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Row(
        children: [
          _segment(RouteMode.air, Icons.straighten, 'Straight line'),
          _segment(RouteMode.road, Icons.alt_route, 'By road'),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 12, color: _grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: _green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats() {
    final road = _mode == RouteMode.road;
    String distance;
    String time;
    if (!road) {
      distance = formatDistance(airMeters(widget.origin, widget.shop.position));
      time = '\u2014';
    } else if (_loadingRoad) {
      distance = '...';
      time = '...';
    } else if (_road != null) {
      distance = formatDistance(_road!.meters);
      time = formatDuration(_road!.seconds);
    } else {
      distance = '\u2014';
      time = '\u2014';
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stat('Distance', distance),
          Container(
            width: 1.5,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: _green,
          ),
          _stat(road ? 'Est. time (motorcycle, approx.)' : 'Est. time', time),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(),
                      const SizedBox(height: 12),
                      _subtitle(),
                      const SizedBox(height: 18),
                      Expanded(child: _mapView()),
                      const SizedBox(height: 16),
                      _modeToggle(),
                      const SizedBox(height: 16),
                      _stats(),
                      if (_roadError != null && _mode == RouteMode.road)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _loadingRoad ? null : _loadRoad,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '$_roadError Tap to retry.',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 110),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        RadialNavMenu.regular(
          onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onProfile: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ProfilePage(isRegularUser: true),
            ),
          ),
          onChat: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const GlobalChatPage())),
          onCurrency: _soon,
        ),
      ],
    );
  }
}
