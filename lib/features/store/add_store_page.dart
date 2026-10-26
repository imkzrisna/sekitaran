import 'package:flutter/material.dart';
import 'package:sekitaran/features/profile/profile_page.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/core/reveal.dart';
import 'package:sekitaran/core/indonesia_geo.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/store/currency_picker.dart';
import 'package:sekitaran/features/store/location_picker_map.dart';
import 'package:sekitaran/features/store/edit_store_page.dart';
import 'package:sekitaran/features/store/maps_link_parser.dart';
import 'package:sekitaran/features/store/plus_code.dart';
import 'package:sekitaran/features/store/store_service.dart';

enum StoreCategory {
  restaurant('Local Restaurant', Icons.restaurant_outlined),
  grocery('Grocery Store', Icons.shopping_basket_outlined),
  exchange('Money Changer', Icons.currency_exchange);

  const StoreCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _ItemEntry {
  final name = TextEditingController();
  final price = TextEditingController();

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _RateEntry {
  final currency = TextEditingController();
  final priceIn = TextEditingController();
  final priceRupiah = TextEditingController();
  final fee = TextEditingController();

  void dispose() {
    currency.dispose();
    priceIn.dispose();
    priceRupiah.dispose();
    fee.dispose();
  }
}

/// Memformat angka dengan titik ribuan saat mengetik: 10000 -> 10.000
class ThousandsSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final buf = StringBuffer();
    for (var i = 0; i < trimmed.length; i++) {
      if (i > 0 && (trimmed.length - i) % 3 == 0) buf.write('.');
      buf.write(trimmed[i]);
    }
    final text = buf.toString();

    // Pertahankan posisi kursor berdasarkan jumlah digit di sebelah kirinya
    final cursor = newValue.selection.baseOffset.clamp(0, newValue.text.length);
    final before = newValue.text
        .substring(0, cursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;
    final target = before > trimmed.length ? trimmed.length : before;
    var offset = 0;
    var seen = 0;
    while (offset < text.length && seen < target) {
      if (text[offset] != '.') seen++;
      offset++;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}

class AddStorePage extends StatefulWidget {
  const AddStorePage({super.key});

  @override
  State<AddStorePage> createState() => _AddStorePageState();
}

class _AddStorePageState extends State<AddStorePage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);
  static const _red = Color(0xFFB00000);
  static const _maxEntries = 20;

  final _formKey = GlobalKey<FormState>();
  final _storeName = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  StoreCategory? _category;
  bool _categoryError = false;
  bool _saving = false;
  final _mapsLink = TextEditingController();
  bool _resolvingLink = false;
  String? _linkMessage;
  bool _linkMessageIsError = false;

  // Daftar menu/produk disimpan per kategori supaya tidak hilang saat berpindah
  final Map<StoreCategory, List<_ItemEntry>> _items = {
    StoreCategory.restaurant: [_ItemEntry()],
    StoreCategory.grocery: [_ItemEntry()],
  };
  final List<_RateEntry> _rates = [_RateEntry()];

  @override
  void dispose() {
    _storeName.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _mapsLink.dispose();
    for (final list in _items.values) {
      for (final e in list) {
        e.dispose();
      }
    }
    for (final r in _rates) {
      r.dispose();
    }
    super.dispose();
  }

  // ---------- Logika ----------

  int get _entryCount {
    final c = _category;
    if (c == null) return 0;
    return c == StoreCategory.exchange ? _rates.length : _items[c]!.length;
  }

  void _selectCategory(StoreCategory c) {
    if (_category == c) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _category = c;
      _categoryError = false;
    });
  }

  void _addEntry() {
    final c = _category;
    if (c == null || _entryCount >= _maxEntries) return;
    setState(() {
      if (c == StoreCategory.exchange) {
        _rates.add(_RateEntry());
      } else {
        _items[c]!.add(_ItemEntry());
      }
    });
  }

  void _removeAt(int index) {
    final c = _category;
    if (c == null || _entryCount <= 1) return;
    FocusScope.of(context).unfocus();
    VoidCallback? disposeRemoved;
    setState(() {
      if (c == StoreCategory.exchange) {
        disposeRemoved = _rates.removeAt(index).dispose;
      } else {
        disposeRemoved = _items[c]!.removeAt(index).dispose;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => disposeRemoved?.call());
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  String _dbCategory(StoreCategory c) => switch (c) {
    StoreCategory.restaurant => 'restaurant',
    StoreCategory.grocery => 'grocery',
    StoreCategory.exchange => 'money_changer',
  };

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final ok = _formKey.currentState!.validate();
    final c = _category;
    setState(() => _categoryError = c == null);
    if (!ok || c == null) return;
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    if (lat == null || lng == null || !isInIndonesiaCoord(lat, lng)) {
      _snack(kIndonesiaOnlyMessageId);
      return;
    }

    final items = <Map<String, dynamic>>[];
    final rates = <Map<String, dynamic>>[];

    if (c == StoreCategory.exchange) {
      final seen = <String>{};
      for (final r in _rates) {
        final code = r.currency.text.trim().toUpperCase();
        if (code.isEmpty) continue;
        if (!seen.add(code)) {
          _snack('Mata uang $code diisi lebih dari sekali.');
          return;
        }
        final fee = _digits(r.fee.text);
        rates.add({
          'currency_code': code,
          'foreign_amount': r.priceIn.text.trim(),
          'idr_amount': _digits(r.priceRupiah.text),
          'service_fee_idr': fee.isEmpty ? null : fee,
        });
      }
      if (rates.isEmpty) {
        _snack('Isi minimal satu mata uang.');
        return;
      }
    } else {
      for (final e in _items[c]!) {
        final name = e.name.text.trim();
        if (name.isEmpty) continue;
        items.add({
          'name': name,
          'kind': 'product',
          'price': _digits(e.price.text),
        });
      }
      if (items.isEmpty) {
        _snack(
          c == StoreCategory.restaurant
              ? 'Isi minimal satu menu.'
              : 'Isi minimal satu produk.',
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await StoreService.instance.createStore(
        name: _storeName.text.trim(),
        category: _dbCategory(c),
        latitude: double.parse(_latitude.text.trim()),
        longitude: double.parse(_longitude.text.trim()),
        items: items,
        rates: rates,
      );
      if (!mounted) return;
      _snack('Toko berhasil disimpan.');
      Navigator.of(context).pop(true);
    } on StoreFailure catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Wajib diisi bila ada field lain di grup yang terisi, dan harus > 0.
  String? _positiveNumber(
    String? v,
    List<TextEditingController> group,
    String message,
  ) {
    final req = _requiredIfAny(v, group, message);
    if (req != null) return req;
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final n = double.tryParse(t);
    if (n == null) return 'Enter a valid number';
    return n <= 0 ? 'Must be greater than 0' : null;
  }

  void _showLinkHelp() {
    FocusScope.of(context).unfocus();

    const plusSteps = <(IconData, String, String)>[
      (
        Icons.search,
        'Buka detail tempat',
        'Di Google Maps, cari tokomu atau tekan lama di peta, lalu buka '
            'detail tempatnya.',
      ),
      (
        Icons.apps,
        'Cari baris Plus Code',
        'Scroll ke baris dengan ikon titik-titik. Isinya kode seperti '
            '887R+6Q Triharjo.',
      ),
      (
        Icons.copy,
        'Salin dan tempel',
        'Ketuk ikon salin, tempel di kolom Google Maps link, lalu ketuk '
            'tombol pin hijau.',
      ),
    ];
    const linkSteps = <(IconData, String, String)>[
      (
        Icons.touch_app_outlined,
        'Pilih tempatnya',
        'Ketuk nama tempat atau pin di bagian bawah layar.',
      ),
      (
        Icons.share_outlined,
        'Bagikan',
        'Ketuk Bagikan (Share), lalu pilih Salin link (Copy link).',
      ),
      (
        Icons.content_paste,
        'Tempel di sini',
        'Tempel di kolom Google Maps link, lalu ketuk tombol pin hijau.',
      ),
    ];

    Widget segment(String text, bool sel, VoidCallback onTap) => Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
              color: sel ? Colors.white : _ink,
            ),
          ),
        ),
      ),
    );

    Widget timeline(List<(IconData, String, String)> steps) => Column(
      children: [
        for (var k = 0; k < steps.length; k++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 28,
                  child: Column(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${k + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (k < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: _accent,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: k < steps.length - 1 ? 18 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          steps[k].$2,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          steps[k].$3,
                          style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            color: _grey,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(steps[k].$1, color: _green, size: 22),
              ],
            ),
          ),
      ],
    );

    Widget example() => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.apps, color: _green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contoh yang disalin',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: _grey),
                ),
                Text(
                  '887R+6Q Triharjo, Sleman',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.copy, color: _grey, size: 18),
        ],
      ),
    );

    Widget tip(IconData icon, String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: _grey,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );

    var tab = 0;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 2),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: _accent, width: 1.5),
                            ),
                          ),
                          child: Text(
                            'Cara ambil lokasi',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.pin_drop_outlined,
                        color: _green,
                        size: 22,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih salah satu cara, lalu ikuti langkahnya.',
                    style: GoogleFonts.poppins(fontSize: 13, color: _grey),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border, width: 1.2),
                    ),
                    child: Row(
                      children: [
                        segment(
                          'Plus Code',
                          tab == 0,
                          () => setSheet(() => tab = 0),
                        ),
                        segment(
                          'Link tempat',
                          tab == 1,
                          () => setSheet(() => tab = 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Column(
                        key: ValueKey(tab),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          timeline(tab == 0 ? plusSteps : linkSteps),
                          const SizedBox(height: 18),
                          if (tab == 0) ...[
                            example(),
                            const SizedBox(height: 12),
                            tip(
                              Icons.my_location,
                              'Kode pendek dihitung dekat koordinat yang '
                              'sudah terisi. Jika kosong, dianggap area '
                              'Yogyakarta. Untuk kota lain, ketuk peta di '
                              'sekitar lokasi dulu, atau pakai link.',
                            ),
                          ] else
                            tip(
                              Icons.lightbulb_outline,
                              'Pakai link dari pin tempat yang tepat. Link '
                              'dari tampilan peta biasa hanya mengambil titik '
                              'tengah layar.',
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  tip(
                    Icons.flag_outlined,
                    'Lokasi toko harus berada di Indonesia.',
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Mengerti',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _applyMapsLink() async {
    if (_resolvingLink) return;
    final raw = _mapsLink.text.trim();
    if (raw.isEmpty) {
      setState(() {
        _linkMessageIsError = true;
        _linkMessage = 'Tempel link Google Maps terlebih dahulu.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _resolvingLink = true;
      _linkMessage = null;
    });
    try {
      final curLat = double.tryParse(_latitude.text.trim());
      final curLng = double.tryParse(_longitude.text.trim());
      final hasRef = curLat != null && curLng != null;
      final usedDefaultRef = !hasRef && looksLikePlusCode(raw);
      final r = await resolveMapsLink(
        raw,
        refLat: hasRef ? curLat : -7.7956,
        refLng: hasRef ? curLng : 110.3695,
      );
      if (!mounted) return;
      if (!isInIndonesiaCoord(r.lat, r.lng)) {
        setState(() {
          _linkMessageIsError = true;
          _linkMessage = kIndonesiaOnlyMessageId;
        });
        return;
      }
      _latitude.text = r.lat.toStringAsFixed(6);
      _longitude.text = r.lng.toStringAsFixed(6);
      setState(() {
        _linkMessageIsError = false;
        _linkMessage = r.approx
            ? 'Koordinat diambil dari pusat tampilan peta. Geser pin jika kurang tepat.'
            : (usedDefaultRef
                  ? 'Plus Code dihitung relatif ke area Yogyakarta. Pastikan pin berada di lokasi yang benar.'
                  : 'Koordinat berhasil diambil.');
      });
    } on MapsLinkException catch (e) {
      if (!mounted) return;
      setState(() {
        _linkMessageIsError = true;
        _linkMessage = e.message;
      });
    } finally {
      if (mounted) setState(() => _resolvingLink = false);
    }
  }

  /// Ambil angkanya saja: "10.000" -> "10000"
  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  /// Seperti [_positiveNumber], tetapi untuk rupiah berformat titik ribuan.
  String? _positiveIdr(
    String? v,
    List<TextEditingController> group,
    String message,
  ) {
    final req = _requiredIfAny(v, group, message);
    if (req != null) return req;
    if ((v ?? '').trim().isEmpty) return null;
    final n = int.tryParse(_digits(v ?? ''));
    if (n == null) return 'Enter a valid number';
    return n <= 0 ? 'Must be greater than 0' : null;
  }

  String? _notEmpty(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  /// Wajib diisi hanya jika salah satu field di grup sudah diisi.
  String? _requiredIfAny(
    String? v,
    List<TextEditingController> group,
    String message,
  ) {
    if ((v ?? '').trim().isNotEmpty) return null;
    final any = group.any((c) => c.text.trim().isNotEmpty);
    return any ? message : null;
  }

  String? _validateCoord(String? v, String name, double limit) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return '$name is required';
    final n = double.tryParse(t);
    if (n == null) return 'Enter a valid number';
    if (n < -limit || n > limit) {
      return 'Must be between -${limit.toInt()} and ${limit.toInt()}';
    }
    return null;
  }

  String _saveLabel(StoreCategory c) => switch (c) {
    StoreCategory.restaurant => 'Save Menu & Prices',
    StoreCategory.grocery => 'Save Products & Prices',
    StoreCategory.exchange => 'Save Exchange Rates',
  };

  // ---------- Komponen dasar ----------

  InputDecoration _decoration(
    String hint, {
    bool dense = false,
    Color fill = Colors.white,
  }) {
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
      errorStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.red.shade700),
      errorMaxLines: 2,
      filled: true,
      fillColor: fill,
      isDense: dense,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: dense ? 12 : 14,
      ),
      enabledBorder: border(_border),
      focusedBorder: border(_green),
      errorBorder: border(Colors.red.shade400),
      focusedErrorBorder: border(Colors.red.shade400),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    bool dense = false,
    Color fill = Colors.white,
  }) {
    return TextFormField(
      key: ObjectKey(controller),
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14, color: _ink),
      decoration: _decoration(hint, dense: dense, fill: fill),
    );
  }

  Widget _fieldLabel(String text, {bool required = false, double top = 14}) {
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _grey,
              ),
            ),
          ),
          if (required) ...[
            const SizedBox(width: 3),
            Text(
              '*',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------- Header halaman ----------

  Widget _title() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            'Add new store to Sekitaran',
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
          Positioned(
            top: -12,
            right: -20,
            child: Text(
              '*',
              style: GoogleFonts.poppins(
                fontSize: 40,
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
        'Fill in your store information',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
      ),
    );
  }

  // ---------- Kartu ----------

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? step,
    bool required = false,
    String? caption,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _border.withValues(alpha: 0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                step,
                style: GoogleFonts.poppins(fontSize: 12, color: _grey),
              ),
            ),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 2),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: _accent, width: 1.5),
                    ),
                  ),
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ),
              ),
              if (required) ...[
                const SizedBox(width: 4),
                Text(
                  '*',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _red,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Icon(icon, color: _green, size: 22),
            ],
          ),
          if (caption != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                caption,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  color: _grey,
                  height: 1.45,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _categoryTile(StoreCategory c) {
    final selected = _category == c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectCategory(c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _green : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? _green
                : (_categoryError ? Colors.red.shade400 : _border),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(c.icon, size: 22, color: selected ? Colors.white : _green),
            const SizedBox(height: 8),
            Text(
              c.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? Colors.white : _ink,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _storeInfoCard() {
    final cats = StoreCategory.values;
    return _sectionCard(
      icon: Icons.storefront_outlined,
      title: 'Store Information',
      step: 'Step 1 of 3',
      children: [
        _fieldLabel('Store Name', required: true, top: 14),
        _field(
          controller: _storeName,
          hint: 'Enter your store name',
          validator: (v) => _notEmpty(v, 'Store name is required'),
        ),
        _fieldLabel('Category', required: true, top: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cats.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _categoryTile(cats[i])),
              ],
            ],
          ),
        ),
        if (_categoryError)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'Please choose a category',
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.red.shade700,
              ),
            ),
          ),
      ],
    );
  }

  // ---------- Lokasi ----------

  Widget _mapsLinkField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Google Maps link',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _grey,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showLinkHelp,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.help_outline, size: 18, color: _green),
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                controller: _mapsLink,
                hint: 'Maps link, coordinates, or Plus Code (optional)',
                keyboardType: TextInputType.url,
                dense: true,
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _resolvingLink ? null : _applyMapsLink,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                ),
                child: _resolvingLink
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.pin_drop_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
        if (_linkMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _linkMessage!,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: _linkMessageIsError ? Colors.red.shade700 : _green,
              ),
            ),
          ),
      ],
    );
  }

  Widget _coordField(
    String label,
    TextEditingController controller,
    String hint,
    double limit,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, required: true, top: 14),
        _field(
          controller: controller,
          hint: hint,
          dense: true,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
          validator: (v) => _validateCoord(v, label, limit),
        ),
      ],
    );
  }

  Widget _locationCard() {
    return _sectionCard(
      icon: Icons.place_outlined,
      title: 'Business Location',
      step: 'Step 2 of 3',
      required: true,
      caption: 'Tap the map to drop a pin, or paste a Google Maps link.',
      children: [
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LocationPickerMap(
            latController: _latitude,
            lngController: _longitude,
            height: 210,
            onMessage: _snack,
          ),
        ),
        _mapsLinkField(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _coordField('Latitude', _latitude, 'e.g. -7.7956', 90),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _coordField('Longitude', _longitude, 'e.g. 110.3695', 180),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- Menu / produk / kurs ----------

  Widget _entryCard({
    Key? key,
    required int number,
    required String title,
    required bool canRemove,
    required VoidCallback onRemove,
    required List<Widget> children,
  }) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * 14),
          child: child,
        ),
      ),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.only(top: 12),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: _border.withValues(alpha: 0.7)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _green,
                      ),
                    ),
                  ),
                  if (canRemove)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onRemove,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close,
                          size: 20,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _itemCard(StoreCategory c, int i) {
    final noun = c == StoreCategory.restaurant ? 'Menu' : 'Product';
    final lower = noun.toLowerCase();
    final e = _items[c]![i];
    final group = [e.name, e.price];
    return _entryCard(
      key: ObjectKey(e),
      number: i + 1,
      title: '$noun ${i + 1}',
      canRemove: _entryCount > 1,
      onRemove: () => _removeAt(i),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('$noun name', top: 2),
                  _field(
                    controller: e.name,
                    hint: 'e.g. $lower name',
                    dense: true,
                    validator: (v) =>
                        _requiredIfAny(v, group, 'Enter the $lower name'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel('Price (IDR)', top: 2),
                  _field(
                    controller: e.price,
                    hint: '0',
                    dense: true,
                    keyboardType: TextInputType.number,
                    formatters: [ThousandsSeparatorFormatter()],
                    validator: (v) =>
                        _requiredIfAny(v, group, 'Enter the price'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _rateCard(int i) {
    final r = _rates[i];
    final all = [r.currency, r.priceIn, r.priceRupiah, r.fee];
    final code = r.currency.text.trim();
    return _entryCard(
      key: ObjectKey(r),
      number: i + 1,
      title: code.isEmpty
          ? 'Currency ${i + 1}'
          : 'Currency ${i + 1} \u00B7 $code',
      canRemove: _entryCount > 1,
      onRemove: () => _removeAt(i),
      children: [
        _fieldLabel('Foreign currency', top: 4),
        CurrencyPickerField(
          key: ObjectKey(r.currency),
          controller: r.currency,
          radius: 2,
          onChanged: (_) => setState(() {}),
          validator: (v) => _requiredIfAny(v, all, 'Select a currency'),
        ),
        _fieldLabel('Price in (${code.isEmpty ? '__' : code})', top: 12),
        _field(
          controller: r.priceIn,
          hint: 'Enter rate',
          fill: Colors.white,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          validator: (v) => _positiveNumber(v, all, 'Enter the rate'),
        ),
        _fieldLabel('Price convert to rupiah', top: 12),
        _field(
          controller: r.priceRupiah,
          hint: 'Enter amount (IDR)',
          fill: Colors.white,
          keyboardType: TextInputType.number,
          formatters: [ThousandsSeparatorFormatter()],
          validator: (v) => _positiveIdr(v, all, 'Enter the amount in rupiah'),
        ),
        _fieldLabel('Service Fee (IDR)', top: 12),
        _field(
          controller: r.fee,
          hint: 'Enter service fee',
          validator: (v) => _requiredIfAny(v, all, 'Enter the service fee'),
          fill: Colors.white,
          keyboardType: TextInputType.number,
          formatters: [ThousandsSeparatorFormatter()],
        ),
      ],
    );
  }

  Widget _addButton(String text, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 18),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 20, color: _green),
              const SizedBox(width: 6),
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _itemsCard(StoreCategory c) {
    final isExchange = c == StoreCategory.exchange;
    final (String title, IconData icon, String addLabel) = switch (c) {
      StoreCategory.restaurant => (
        'Menu & Prices',
        Icons.restaurant_menu,
        'Add another menu',
      ),
      StoreCategory.grocery => (
        'Products & Prices',
        Icons.inventory_2_outlined,
        'Add another product',
      ),
      StoreCategory.exchange => (
        'Exchange Rates',
        Icons.currency_exchange,
        'Add another currency',
      ),
    };
    return _sectionCard(
      icon: icon,
      title: title,
      step: 'Step 3 of 3',
      caption: isExchange
          ? 'Add the currencies you exchange. Empty entries are ignored.'
          : 'Add what you sell. Empty entries are ignored.',
      children: [
        if (isExchange)
          for (var i = 0; i < _rates.length; i++) _rateCard(i)
        else
          for (var i = 0; i < _items[c]!.length; i++) _itemCard(c, i),
        _addButton(addLabel, _entryCount < _maxEntries ? _addEntry : null),
      ],
    );
  }

  Widget _saveButton(String text) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _saving ? null : _save,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _saving ? _green.withValues(alpha: 0.7) : _green,
          borderRadius: BorderRadius.circular(14),
        ),
        child: _saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _dynamicSection() {
    final c = _category;
    if (c == null) return const SizedBox(width: double.infinity);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _locationCard(),
        _itemsCard(c),
        const SizedBox(height: 24),
        _saveButton(_saveLabel(c)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildScaffold(context),
        RadialNavMenu(
          current: RadialNavItem.add,
          onProfile: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          // Dashboard adalah route pertama (dibuka lewat pushAndRemoveUntil).
          onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onAddStore: () {}, // sudah berada di halaman ini
          onEdit: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const EditStorePage())),
        ),
      ],
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 140),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 56),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Reveal(index: 0, child: _title()),
                          const SizedBox(height: 12),
                          Reveal(index: 1, child: _subtitle()),
                        ],
                      ),
                    ),
                    Reveal(index: 2, child: _storeInfoCard()),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: _dynamicSection(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
