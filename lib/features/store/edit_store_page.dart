import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/store/add_store_page.dart'
    show AddStorePage, StoreCategory, ThousandsSeparatorFormatter;

String _idr(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _ItemRow {
  _ItemRow({String nameText = '', String priceText = ''})
    : name = TextEditingController(text: nameText),
      price = TextEditingController(text: priceText);

  final TextEditingController name;
  final TextEditingController price;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _RateRow {
  _RateRow({
    String code = '',
    String rate = '',
    String idr = '',
    String fee = '',
  }) : currency = TextEditingController(text: code),
       priceIn = TextEditingController(text: rate),
       priceRupiah = TextEditingController(text: idr),
       fee = TextEditingController(text: fee);

  final TextEditingController currency;
  final TextEditingController priceIn;
  final TextEditingController priceRupiah;
  final TextEditingController fee;

  void dispose() {
    currency.dispose();
    priceIn.dispose();
    priceRupiah.dispose();
    fee.dispose();
  }
}

class _StoreDraft {
  _StoreDraft({
    required this.id,
    required String nameText,
    required this.category,
    List<_ItemRow>? items,
    List<_RateRow>? rates,
  }) : name = TextEditingController(text: nameText),
       items = items ?? [],
       rates = rates ?? [];

  final String id;
  final StoreCategory category;
  final TextEditingController name;
  final List<_ItemRow> items;
  final List<_RateRow> rates;

  void dispose() {
    name.dispose();
    for (final i in items) {
      i.dispose();
    }
    for (final r in rates) {
      r.dispose();
    }
  }
}

// TODO: ganti dengan data dari backend
List<_StoreDraft> _sampleStores() => [
  _StoreDraft(
    id: 'sample-1',
    nameText: 'FriZel Warung Makan',
    category: StoreCategory.restaurant,
    items: [
      _ItemRow(nameText: 'Nasi Goreng', priceText: _idr(15000)),
      _ItemRow(nameText: 'Ayam Bakar', priceText: _idr(22000)),
      _ItemRow(nameText: 'Es Teh', priceText: _idr(5000)),
    ],
  ),
  _StoreDraft(
    id: 'sample-2',
    nameText: 'FriZel Toko Sembako',
    category: StoreCategory.grocery,
    items: [
      _ItemRow(nameText: 'Beras 5 kg', priceText: _idr(68000)),
      _ItemRow(nameText: 'Minyak Goreng 2 L', priceText: _idr(36000)),
      _ItemRow(nameText: 'Gula Pasir 1 kg', priceText: _idr(17500)),
    ],
  ),
  _StoreDraft(
    id: 'sample-3',
    nameText: 'FriZel Penukaran Uang',
    category: StoreCategory.exchange,
    rates: [
      _RateRow(code: 'USD', rate: '1', idr: _idr(15800), fee: _idr(2000)),
      _RateRow(code: 'SGD', rate: '1', idr: _idr(12300)),
    ],
  ),
];

class EditStorePage extends StatefulWidget {
  const EditStorePage({super.key});

  @override
  State<EditStorePage> createState() => _EditStorePageState();
}

class _EditStorePageState extends State<EditStorePage> {
  static const _green = Color(0xFF103D17);
  static const _accent = Color(0xFF5BAA5F);
  static const _ink = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _border = Color(0xFFC9C9C9);
  static const _grey = Color(0xFF7A7A7A);
  static const _red = Color(0xFFB00000);
  static const _maxEntries = 30;

  final _formKey = GlobalKey<FormState>();
  late final List<_StoreDraft> _stores;
  _StoreDraft? _current;
  double _syncTurns = 0; // tiap +1 = satu putaran penuh
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _stores = _sampleStores();
    _current = _stores.isEmpty ? null : _stores.first;
  }

  @override
  void dispose() {
    for (final s in _stores) {
      s.dispose();
    }
    super.dispose();
  }

  // ---------- Logika ----------

  String _displayName(_StoreDraft s) {
    final t = s.name.text.trim();
    return t.isEmpty ? 'Untitled store' : t;
  }

  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  String? _notEmpty(String? v, String message) =>
      (v == null || v.trim().isEmpty) ? message : null;

  String? _positiveIdr(String? v, String message) {
    if ((v ?? '').trim().isEmpty) return message;
    final n = int.tryParse(_digits(v ?? ''));
    if (n == null || n <= 0) return 'Must be greater than 0';
    return null;
  }

  String? _positiveDecimal(String? v, String message) {
    if ((v ?? '').trim().isEmpty) return message;
    final n = double.tryParse((v ?? '').trim());
    if (n == null) return 'Enter a valid number';
    return n <= 0 ? 'Must be greater than 0' : null;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String action,
  }) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _ink,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(fontSize: 13, color: _grey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
          ),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _pickStore() async {
    if (_stores.length < 2) return;
    FocusScope.of(context).unfocus();
    setState(() => _syncTurns += 1);
    final picked = await showModalBottomSheet<_StoreDraft>(
      context: context,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _underlined('Select Business'),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.storefront_outlined,
                    color: _green,
                    size: 22,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final s in _stores)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                      ),
                      title: Text(
                        _displayName(s),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: _ink,
                        ),
                      ),
                      trailing: s == _current
                          ? const Icon(Icons.check, color: _green)
                          : null,
                      onTap: () => Navigator.pop(ctx, s),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && picked != _current) {
      setState(() => _current = picked);
    }
  }

  void _addEntry(_StoreDraft d) {
    setState(() {
      if (d.category == StoreCategory.exchange) {
        d.rates.add(_RateRow());
      } else {
        d.items.add(_ItemRow());
      }
    });
  }

  Future<void> _deleteEntry(_StoreDraft d, int i) async {
    final isRate = d.category == StoreCategory.exchange;
    final label = isRate
        ? (d.rates[i].currency.text.trim().isEmpty
              ? 'this currency'
              : d.rates[i].currency.text.trim())
        : (d.items[i].name.text.trim().isEmpty
              ? 'this item'
              : '"${d.items[i].name.text.trim()}"');
    final ok = await _confirm(
      title: 'Delete $label?',
      message: 'This entry will be removed from your store.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    VoidCallback? disposeRemoved;
    setState(() {
      if (isRate) {
        disposeRemoved = d.rates.removeAt(i).dispose;
      } else {
        disposeRemoved = d.items.removeAt(i).dispose;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => disposeRemoved?.call());
  }

  Future<void> _deleteStore() async {
    final d = _current;
    if (d == null) return;
    final ok = await _confirm(
      title: 'Delete this store?',
      message:
          '"${_displayName(d)}" and all of its items and prices will be removed. This can\'t be undone.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    // TODO: hapus dari database (tahap backend)
    setState(() {
      final idx = _stores.indexOf(d);
      _stores.removeAt(idx);
      _current = _stores.isEmpty
          ? null
          : _stores[idx < _stores.length ? idx : _stores.length - 1];
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => d.dispose());
    _snack('Store deleted (frontend only)');
  }

  Future<void> _save() async {
    final d = _current;
    if (_saving || d == null) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _snack('Please check the highlighted fields.');
      return;
    }
    if (d.category == StoreCategory.exchange) {
      final seen = <String>{};
      for (final r in d.rates) {
        final code = r.currency.text.trim().toUpperCase();
        if (!seen.add(code)) {
          _snack('Currency $code is listed more than once.');
          return;
        }
      }
    }
    setState(() => _saving = true);
    // TODO: simpan ke database (tahap backend)
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _saving = false);
    _snack('Changes saved (frontend only)');
  }

  // ---------- Komponen dasar ----------

  InputDecoration _decoration(String hint, {Color fill = _bg}) {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
    Color fill = _bg,
  }) {
    return TextFormField(
      key: ObjectKey(controller),
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.poppins(fontSize: 14, color: _ink),
      decoration: _decoration(hint, fill: fill),
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
                fontSize: 14,
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _red,
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  // ---------- Header ----------

  Widget _title() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            'Edit your store',
            maxLines: 1,
            softWrap: false,
            style: GoogleFonts.poppins(
              fontSize: 26,
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
        'Update names, prices, and items',
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: _ink,
        ),
      ),
    );
  }

  Widget _myBusinessRow() {
    final canSwitch = _stores.length > 1;
    final d = _current;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            _underlined('My Business'),
            const SizedBox(width: 6),
            const Icon(Icons.storefront_outlined, color: _green, size: 22),
          ],
        ),
        const SizedBox(width: 12),
        Flexible(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canSwitch ? _pickStore : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: d == null
                      ? Text(
                          '\u201CNo store\u201D',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _green,
                          ),
                        )
                      : ListenableBuilder(
                          listenable: d.name,
                          builder: (_, _) => Text(
                            '\u201C${_displayName(d)}\u201D',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _green,
                            ),
                          ),
                        ),
                ),
                if (canSwitch) ...[
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _syncTurns,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeInOutCubic,
                    child: const Icon(Icons.sync, color: _green, size: 22),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Kartu ----------

  Widget _sectionCard({
    required IconData icon,
    required String title,
    String? caption,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _underlined(title)),
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
                  fontSize: 12,
                  color: _grey,
                  height: 1.4,
                ),
              ),
            ),
          ...children,
        ],
      ),
    );
  }

  Widget _lockedCategory(StoreCategory c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF0EF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border, width: 1.2),
      ),
      child: Row(
        children: [
          Icon(c.icon, size: 20, color: _green),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: _ink,
              ),
            ),
          ),
          const Icon(Icons.lock_outline, size: 18, color: _grey),
        ],
      ),
    );
  }

  Widget _detailsCard(_StoreDraft d) {
    return _sectionCard(
      icon: Icons.storefront_outlined,
      title: 'Store Details',
      children: [
        _fieldLabel('Store Name', required: true, top: 14),
        _field(
          controller: d.name,
          hint: 'Enter your store name',
          validator: (v) => _notEmpty(v, 'Store name is required'),
        ),
        _fieldLabel('Category', top: 16),
        _lockedCategory(d.category),
        Padding(
          padding: const EdgeInsets.only(top: 6, left: 2),
          child: Text(
            'Category can\'t be changed after the store is created.',
            style: GoogleFonts.poppins(fontSize: 11, color: _grey),
          ),
        ),
      ],
    );
  }

  Widget _entryCard({
    required Object entryKey,
    required int number,
    required Listenable titleSource,
    required String Function() title,
    required VoidCallback onDelete,
    required List<Widget> children,
  }) {
    return Container(
      key: ObjectKey(entryKey),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ListenableBuilder(
                    listenable: titleSource,
                    builder: (_, _) => Text(
                      title(),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      Icons.delete_outline,
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
    );
  }

  Widget _itemCard(_StoreDraft d, int i) {
    final noun = d.category == StoreCategory.restaurant ? 'Menu' : 'Product';
    final lower = noun.toLowerCase();
    final e = d.items[i];
    return _entryCard(
      entryKey: e,
      number: i + 1,
      titleSource: e.name,
      title: () {
        final t = e.name.text.trim();
        return t.isEmpty ? '$noun ${i + 1}' : t;
      },
      onDelete: () => _deleteEntry(d, i),
      children: [
        _fieldLabel('$noun name', top: 4),
        _field(
          controller: e.name,
          hint: 'Enter $lower name',
          fill: Colors.white,
          validator: (v) => _notEmpty(v, 'Enter the $lower name'),
        ),
        _fieldLabel('Price (IDR)', top: 12),
        _field(
          controller: e.price,
          hint: 'Enter price',
          fill: Colors.white,
          keyboardType: TextInputType.number,
          formatters: [ThousandsSeparatorFormatter()],
          validator: (v) => _positiveIdr(v, 'Enter the price'),
        ),
      ],
    );
  }

  Widget _rateCard(_StoreDraft d, int i) {
    final r = d.rates[i];
    final code = r.currency.text.trim();
    return _entryCard(
      entryKey: r,
      number: i + 1,
      titleSource: r.currency,
      title: () {
        final t = r.currency.text.trim();
        return t.isEmpty ? 'Currency ${i + 1}' : 'Currency ${i + 1} \u00B7 $t';
      },
      onDelete: () => _deleteEntry(d, i),
      children: [
        _fieldLabel('Foreign currency', top: 4),
        _field(
          controller: r.currency,
          hint: 'e.g. USD',
          fill: Colors.white,
          formatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
            LengthLimitingTextInputFormatter(3),
            TextInputFormatter.withFunction(
              (old, next) => next.copyWith(text: next.text.toUpperCase()),
            ),
          ],
          onChanged: (_) => setState(() {}),
          validator: (v) {
            final t = (v ?? '').trim();
            if (t.isEmpty) return 'Enter the currency code';
            if (t.length != 3) return 'Use a 3-letter code, e.g. USD';
            return null;
          },
        ),
        _fieldLabel('Price in (${code.isEmpty ? '__' : code})', top: 12),
        _field(
          controller: r.priceIn,
          hint: 'Enter rate',
          fill: Colors.white,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          validator: (v) => _positiveDecimal(v, 'Enter the rate'),
        ),
        _fieldLabel('Price convert to rupiah', top: 12),
        _field(
          controller: r.priceRupiah,
          hint: 'Enter amount (IDR)',
          fill: Colors.white,
          keyboardType: TextInputType.number,
          formatters: [ThousandsSeparatorFormatter()],
          validator: (v) => _positiveIdr(v, 'Enter the amount in rupiah'),
        ),
        _fieldLabel('Service Fee (IDR)', top: 12),
        _field(
          controller: r.fee,
          hint: 'Enter service fee (optional)',
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
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green, width: 1.2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline, size: 20, color: _green),
              const SizedBox(width: 8),
              Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
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

  Widget _itemsCard(_StoreDraft d) {
    final isExchange = d.category == StoreCategory.exchange;
    final (String title, IconData icon, String addLabel) = switch (d.category) {
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
    final count = isExchange ? d.rates.length : d.items.length;
    return _sectionCard(
      icon: icon,
      title: title,
      caption:
          'Edit a name or price directly, or remove what you no longer offer.',
      children: [
        if (count == 0)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              isExchange ? 'No currencies yet.' : 'No items yet.',
              style: GoogleFonts.poppins(fontSize: 13, color: _grey),
            ),
          ),
        if (isExchange)
          for (var i = 0; i < d.rates.length; i++) _rateCard(d, i)
        else
          for (var i = 0; i < d.items.length; i++) _itemCard(d, i),
        _addButton(addLabel, count < _maxEntries ? () => _addEntry(d) : null),
      ],
    );
  }

  Widget _saveButton() {
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
                  'Save Changes',
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

  Widget _deleteStoreButton() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _deleteStore,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade400, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 20, color: Colors.red.shade600),
            const SizedBox(width: 8),
            Text(
              'Delete this store',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.red.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.storefront_outlined, size: 36, color: _green),
          const SizedBox(height: 10),
          Text(
            'You have no stores yet.',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add a store to start managing its items and prices.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12.5, color: _grey),
          ),
          _addButton(
            'Add a store',
            () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const AddStorePage())),
          ),
        ],
      ),
    );
  }

  Widget _content() {
    final d = _current;
    if (d == null) return _emptyState();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(d.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailsCard(d),
            _itemsCard(d),
            const SizedBox(height: 24),
            _saveButton(),
            const SizedBox(height: 14),
            _deleteStoreButton(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildScaffold(context),
        RadialNavMenu(
          // Dashboard adalah route pertama (dibuka lewat pushAndRemoveUntil).
          onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onAddStore: () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AddStorePage())),
          onEdit: () {}, // sudah berada di halaman ini
          // TODO: onProfile setelah halamannya ada.
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
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _title(),
                          const SizedBox(height: 12),
                          _subtitle(),
                          const SizedBox(height: 22),
                          _myBusinessRow(),
                        ],
                      ),
                    ),
                    _content(),
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
