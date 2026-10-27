import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:sekitaran/features/explore/explore_service.dart';
import 'package:sekitaran/features/store/offline/offline_store_service.dart';

class OfflineStoresPage extends StatefulWidget {
  const OfflineStoresPage({super.key});

  @override
  State<OfflineStoresPage> createState() => _OfflineStoresPageState();
}

class _OfflineStoresPageState extends State<OfflineStoresPage> {
  static const _green = Color(0xFF103D17);
  static const _background = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);

  final _service = OfflineStoreService.instance;

  List<Map<String, dynamic>> _stores = [];
  LatLng? _position;
  bool _loadingLocation = false;
  String? _locationMessage;
  String _selectedCategory = 'all';
  final Set<String> _expandedStoreIds = <String>{};
  static const String _osmUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  Widget _buildHybridMap() {
    final validStores = _stores.where((store) {
      final lat = _toDouble(store['latitude']);
      final lon = _toDouble(store['longitude']);

      return lat != null &&
          lon != null &&
          lat >= -90 &&
          lat <= 90 &&
          lon >= -180 &&
          lon <= 180 &&
          !(lat == 0 && lon == 0);
    }).toList();

    final center =
        _position ??
        (validStores.isNotEmpty
            ? LatLng(
                _toDouble(validStores.first['latitude'])!,
                _toDouble(validStores.first['longitude'])!,
              )
            : const LatLng(-7.7956, 110.3695));

    Widget coordinateCard({
      required String title,
      required double latitude,
      required double longitude,
      required IconData icon,
      required Color color,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFDCE5DF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SelectableText(
                    'Latitude: ${latitude.toStringAsFixed(6)}\n'
                    'Longitude: ${longitude.toStringAsFixed(6)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: const Color(0xFF252525),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 250,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCE5DF)),
          ),
          child: FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 13,
              minZoom: 3,
              maxZoom: 19,
            ),
            children: [
              TileLayer(
                urlTemplate: _osmUrl,
                userAgentPackageName: 'com.example.sekitaran',
              ),
              MarkerLayer(
                markers: [
                  for (final store in validStores)
                    Marker(
                      point: LatLng(
                        _toDouble(store['latitude'])!,
                        _toDouble(store['longitude'])!,
                      ),
                      width: 42,
                      height: 48,
                      child: Tooltip(
                        message: store['name']?.toString() ?? 'Toko',
                        child: const Icon(
                          Icons.location_on,
                          color: Color(0xFF103D17),
                          size: 38,
                        ),
                      ),
                    ),
                  if (_position != null)
                    Marker(
                      point: _position!,
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Koordinat Lokasi',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _green,
          ),
        ),
        if (_position case final position?)
          coordinateCard(
            title: 'Lokasi GPS saya',
            latitude: position.latitude,
            longitude: position.longitude,
            icon: Icons.my_location,
            color: Colors.blue,
          )
        else
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDCE5DF)),
            ),
            child: Text(
              'Lokasi GPS belum tersedia. Aktifkan layanan lokasi dan tekan tombol perbarui lokasi.',
              style: GoogleFonts.poppins(fontSize: 11, color: _grey),
            ),
          ),
        if (validStores.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Belum ada toko dengan koordinat yang valid untuk ditampilkan pada peta.',
              style: GoogleFonts.poppins(fontSize: 11, color: _grey),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStores();
    _loadLocation();
  }

  void _loadStores() {
    setState(() {
      _stores = _service.getOfflineStores();
    });
  }

  Future<void> _loadLocation() async {
    if (_loadingLocation) return;

    setState(() {
      _loadingLocation = true;
      _locationMessage = null;
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _locationMessage = 'Aktifkan GPS untuk melihat jarak toko.';
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _locationMessage = 'Izin lokasi diperlukan untuk menghitung jarak.';
        return;
      }

      final location = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (!mounted) return;

      setState(() {
        _position = LatLng(location.latitude, location.longitude);
      });
    } catch (_) {
      _locationMessage = 'Lokasi tidak tersedia. Data toko tetap dapat dibuka.';
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  double? _distance(Map<String, dynamic> store) {
    final position = _position;
    final latitude = _toDouble(store['latitude']);
    final longitude = _toDouble(store['longitude']);

    if (position == null || latitude == null || longitude == null) {
      return null;
    }

    if (latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        (latitude == 0 && longitude == 0)) {
      return null;
    }

    return airMeters(position, LatLng(latitude, longitude));
  }

  double? _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  String _categoryLabel(Object? value) {
    return switch (value) {
      'restaurant' => 'Local Restaurant',
      'grocery' => 'Grocery Store',
      'money_changer' => 'Money Changer',
      _ => 'Store',
    };
  }

  String _price(Object? value) {
    if (value == null) return 'Harga tidak tersedia';

    final amount = value is num ? value : num.tryParse('$value');
    if (amount == null) return '$value';

    return 'Rp ${amount.toStringAsFixed(0)}';
  }

  Future<void> _removeStore(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus toko offline?'),
        content: Text(
          'Data "$name" akan dihapus dari penyimpanan lokal perangkat ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _service.removeOfflineStore(id);

    if (!mounted) return;

    _loadStores();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Toko dihapus dari penyimpanan offline.')),
    );
  }

  List<Map<String, dynamic>> get _filteredStores {
    if (_selectedCategory == 'all') return _stores;

    return _stores.where((store) {
      return store['category']?.toString() == _selectedCategory;
    }).toList();
  }

  Widget _sectionHeading(String text, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF5BAA5F), width: 2),
            ),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Icon(icon, color: _green, size: 25),
      ],
    );
  }

  Widget _categoryChip(String label, String value) {
    final selected = _selectedCategory == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _selectedCategory = value);
      },
      selectedColor: _green,
      backgroundColor: _background,
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        color: selected ? Colors.white : const Color(0xFF252525),
        fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? _green : const Color(0xFFC9C9C9),
        width: 1.2,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
    );
  }

  Widget _storeRow(Map<String, dynamic> store) {
    final id = store['id']?.toString() ?? '';
    final name = store['name']?.toString() ?? 'Unnamed Store';
    final items = (store['items'] as List?) ?? const [];
    final rates = (store['exchange_rates'] as List?) ?? const [];
    final distance = _distance(store);
    final expanded = _expandedStoreIds.contains(id);

    final category = store['category']?.toString();
    final icon = category == 'restaurant'
        ? Icons.restaurant
        : category == 'money_changer'
        ? Icons.currency_exchange
        : Icons.storefront_outlined;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedStoreIds.remove(id);
              } else {
                _expandedStoreIds.add(id);
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              children: [
                Icon(icon, color: _green, size: 27),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF252525),
                        ),
                      ),
                      Text(
                        _categoryLabel(category),
                        style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                      ),
                      if (distance != null)
                        Text(
                          'Jarak lurus: ${formatDistance(distance)}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: _green,
                          ),
                        ),
                      Text(
                        '${items.length} barang tersimpan'
                        '${rates.isNotEmpty ? ' · ${rates.length} kurs' : ''}',
                        style: GoogleFonts.poppins(fontSize: 11, color: _grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Hapus dari penyimpanan offline',
                  onPressed: () => _removeStore(id, name),
                  icon: const Icon(Icons.download_done, color: _green),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.chevron_right,
                  color: _grey,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0E8E3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Barang dan harga',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
                const SizedBox(height: 8),
                if (items.isEmpty)
                  Text(
                    'Belum ada barang tersimpan.',
                    style: GoogleFonts.poppins(fontSize: 12, color: _grey),
                  )
                else
                  ...items.whereType<Map>().map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['name']?.toString() ?? 'Barang',
                              style: GoogleFonts.poppins(fontSize: 12),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _price(item['price']),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                if (rates.isNotEmpty) ...[
                  const Divider(height: 24),
                  Text(
                    'Kurs penukaran uang',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...rates.whereType<Map>().map((rate) {
                    final currency = rate['currency_code']?.toString() ?? '-';
                    final amount = rate['foreign_amount']?.toString() ?? '-';
                    final fee = rate['service_fee_idr'];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$amount $currency',
                                  style: GoogleFonts.poppins(fontSize: 12),
                                ),
                              ),
                              Text(
                                _price(rate['idr_amount']),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _green,
                                ),
                              ),
                            ],
                          ),
                          if (fee != null)
                            Text(
                              'Biaya layanan: ${_price(fee)}',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: _grey,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
                if (store['cached_at'] != null) ...[
                  const Divider(height: 24),
                  Text(
                    'Terakhir disimpan: ${store['cached_at']}',
                    style: GoogleFonts.poppins(fontSize: 10, color: _grey),
                  ),
                ],
              ],
            ),
          ),
        const Divider(height: 1, color: Color(0xFFDCE5DF)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final stores = _filteredStores;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _green,
        elevation: 0,
        title: Text(
          'Offline Stores',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui lokasi',
            onPressed: _loadingLocation ? null : _loadLocation,
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: RefreshIndicator(
              onRefresh: () async {
                _loadStores();
                await _loadLocation();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
                children: [
                  Text(
                    'Your Saved Places',
                    style: GoogleFonts.poppins(
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
                      color: _green,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Toko dan informasi harga yang tersimpan di perangkat ini.',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF252525),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F1E8),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.offline_pin_outlined,
                          color: _green,
                          size: 21,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            '${_stores.length} toko tersimpan secara lokal',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildHybridMap(),
                  if (_locationMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _locationMessage!,
                      style: GoogleFonts.poppins(fontSize: 11, color: _grey),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _sectionHeading('Saved Shops', Icons.storefront_outlined),
                  const SizedBox(height: 16),
                  Text(
                    'Category',
                    style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    runSpacing: 5,
                    children: [
                      _categoryChip('All', 'all'),
                      _categoryChip('Local Restaurant', 'restaurant'),
                      _categoryChip('Grocery Store', 'grocery'),
                      _categoryChip('Money Changer', 'money_changer'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (stores.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 44),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.cloud_off_outlined,
                            size: 54,
                            color: _grey,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _stores.isEmpty
                                ? 'Belum ada toko tersimpan'
                                : 'Tidak ada toko pada kategori ini',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _stores.isEmpty
                                ? 'Simpan toko dari halaman utama saat terhubung ke internet.'
                                : 'Coba pilih kategori lain.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...stores.map(_storeRow),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
