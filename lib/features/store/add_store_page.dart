import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/store/location_picker_map.dart';
import 'package:sekitaran/features/store/store_service.dart';

enum StoreCategory {
  restaurant('Local Restaurant'),
  grocery('Grocery Store'),
  exchange('Money Changer');

  const StoreCategory(this.label);
  final String label;
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
  static const _red = Color(0xFFB00000);
  static const _maxEntries = 20;

  final _formKey = GlobalKey<FormState>();
  final _storeName = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  StoreCategory? _category;
  bool _categoryError = false;
  bool _saving = false;

  // Daftar menu/produk disimpan per kategori supaya tidak hilang saat berpindah
  final Map<StoreCategory, List<_ItemEntry>> _items = {
    StoreCategory.restaurant: [_ItemEntry(), _ItemEntry()],
    StoreCategory.grocery: [_ItemEntry(), _ItemEntry()],
  };
  final List<_RateEntry> _rates = [_RateEntry()];

  @override
  void dispose() {
    _storeName.dispose();
    _latitude.dispose();
    _longitude.dispose();
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

  void _removeEntry() {
    final c = _category;
    if (c == null || _entryCount <= 1) return;
    VoidCallback? disposeRemoved;
    setState(() {
      if (c == StoreCategory.exchange) {
        disposeRemoved = _rates.removeLast().dispose;
      } else {
        disposeRemoved = _items[c]!.removeLast().dispose;
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
        final fee = r.fee.text.trim();
        rates.add({
          'currency_code': code,
          'foreign_amount': r.priceIn.text.trim(),
          'idr_amount': r.priceRupiah.text.trim(),
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
          'price': e.price.text.trim(),
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

  // ---------- Komponen kecil ----------

  InputDecoration _decoration(String hint, {bool dense = false}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(2),
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
      fillColor: _bg,
      isDense: dense,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: dense ? 10 : 14,
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
  }) {
    return TextFormField(
      key: ObjectKey(controller),
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14, color: _ink),
      decoration: _decoration(hint, dense: dense),
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
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
          if (required) ...[
            const SizedBox(width: 3),
            Text(
              '*',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
          ],
        ],
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

  Widget _categoryOption(StoreCategory c) {
    final selected = _category == c;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectCategory(c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _green : Colors.white,
                border: Border.all(
                  color: selected ? _green : _border,
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              c.label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapPreview() {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.85,
        child: LocationPickerMap(
          latController: _latitude,
          lngController: _longitude,
          height: 200,
          onMessage: _snack,
        ),
      ),
    );
  }

  Widget _coordRow(
    String label,
    TextEditingController controller,
    String hint,
    double limit,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Padding(
            padding: const EdgeInsets.only(top: 9),
            child: Row(
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _ink,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '*',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _red,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _field(
            controller: controller,
            hint: hint,
            dense: true,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
            ],
            validator: (v) => _validateCoord(v, label, limit),
          ),
        ),
      ],
    );
  }

  Widget _roundButton(IconData icon, VoidCallback? onTap) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: _green,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  Widget _saveButton(String text) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: _green, width: 2)),
        child: Container(
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _green,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: _saving
              ? const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
              : Text(
                  text,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }

  // ---------- Isi form per kategori ----------

  List<Widget> _itemGroup(StoreCategory c, int i) {
    final noun = c == StoreCategory.restaurant ? 'Menu' : 'Product';
    final lower = noun.toLowerCase();
    final e = _items[c]![i];
    final group = [e.name, e.price];
    return [
      _fieldLabel('$noun -${i + 1}', top: i == 0 ? 14 : 24),
      _field(
        controller: e.name,
        hint: 'Enter $lower name',
        validator: (v) => _requiredIfAny(v, group, 'Enter the $lower name'),
      ),
      _fieldLabel('Price', top: 14),
      _field(
        controller: e.price,
        hint: 'Enter price (IDR)',
        keyboardType: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) => _requiredIfAny(v, group, 'Enter the price'),
      ),
    ];
  }

  List<Widget> _rateGroup(int i) {
    final r = _rates[i];
    final all = [r.currency, r.priceIn, r.priceRupiah, r.fee];
    final code = r.currency.text.trim();
    return [
      _fieldLabel('Foreign Currency -${i + 1}', top: i == 0 ? 14 : 24),
      _field(
        controller: r.currency,
        hint: 'e.g. USD',
        formatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
          LengthLimitingTextInputFormatter(3),
          TextInputFormatter.withFunction(
            (old, next) => next.copyWith(text: next.text.toUpperCase()),
          ),
        ],
        onChanged: (_) => setState(() {}),
        validator: (v) {
          final req = _requiredIfAny(v, all, 'Enter the currency code');
          if (req != null) return req;
          final t = (v ?? '').trim();
          if (t.isNotEmpty && t.length != 3) {
            return 'Use a 3-letter code, e.g. USD';
          }
          return null;
        },
      ),
      _fieldLabel('Price in (${code.isEmpty ? '__' : code})', top: 14),
      _field(
        controller: r.priceIn,
        hint: 'Enter rate',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        validator: (v) => _positiveNumber(v, all, 'Enter the rate'),
      ),
      _fieldLabel('Price convert to rupiah', top: 14),
      _field(
        controller: r.priceRupiah,
        hint: 'Enter amount (IDR)',
        keyboardType: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (v) => _positiveNumber(v, all, 'Enter the amount in rupiah'),
      ),
      _fieldLabel('Service Fee (IDR)', top: 14),
      _field(
        controller: r.fee,
        hint: 'Enter service fee (optional)',
        keyboardType: TextInputType.number,
        formatters: [FilteringTextInputFormatter.digitsOnly],
      ),
    ];
  }

  Widget _dynamicSection() {
    final c = _category;
    if (c == null) return const SizedBox(width: double.infinity);

    final isExchange = c == StoreCategory.exchange;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Business Location', required: true, top: 18),
        _mapPreview(),
        const SizedBox(height: 14),
        _coordRow('Latitude', _latitude, 'e.g. -7.7956', 90),
        const SizedBox(height: 8),
        _coordRow('Longitude', _longitude, 'e.g. 110.3695', 180),
        const SizedBox(height: 18),
        Row(
          children: [
            _roundButton(
              Icons.add,
              _entryCount < _maxEntries ? _addEntry : null,
            ),
            const SizedBox(width: 14),
            _roundButton(Icons.remove, _entryCount > 1 ? _removeEntry : null),
          ],
        ),
        if (isExchange)
          for (var i = 0; i < _rates.length; i++) ..._rateGroup(i)
        else
          for (var i = 0; i < _items[c]!.length; i++) ..._itemGroup(c, i),
        const SizedBox(height: 28),
        _saveButton(_saveLabel(c)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 48),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tombol kembali sementara, sebelum menu melingkar dipasang di halaman ini
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: _green,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _title(),
                    const SizedBox(height: 12),
                    _subtitle(),
                    _fieldLabel('Store Name', required: true, top: 22),
                    _field(
                      controller: _storeName,
                      hint: 'Enter your store name',
                      validator: (v) => _notEmpty(v, 'Store name is required'),
                    ),
                    _fieldLabel('Category', required: true, top: 14),
                    for (final c in StoreCategory.values) _categoryOption(c),
                    if (_categoryError)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 32),
                        child: Text(
                          'Please choose a category',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
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
