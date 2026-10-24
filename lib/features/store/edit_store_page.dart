import 'package:flutter/material.dart';
import 'package:sekitaran/features/profile/profile_page.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/core/reveal.dart';
import 'package:sekitaran/core/app_confirm_dialog.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/store/currency_picker.dart';
import 'package:sekitaran/features/store/add_store_page.dart'
    show AddStorePage, StoreCategory, ThousandsSeparatorFormatter;
import 'package:sekitaran/features/store/store_repository.dart';
import 'package:sekitaran/features/store/store_service.dart' show StoreFailure;

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
  _ItemRow({this.id, String nameText = '', String priceText = ''})
    : name = TextEditingController(text: nameText),
      price = TextEditingController(text: priceText);

  /// null = baris baru yang belum ada di database.
  final String? id;
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

StoreCategory? _categoryFrom(String? c) => switch (c) {
  'restaurant' => StoreCategory.restaurant,
  'grocery' => StoreCategory.grocery,
  'money_changer' => StoreCategory.exchange,
  _ => null,
};

String _plainNumber(num n) =>
    n == n.truncate() ? n.truncate().toString() : n.toString();

_StoreDraft _draftFrom(StoreRecord r) {
  return _StoreDraft(
    id: r.id,
    nameText: r.name,
    category: _categoryFrom(r.category)!,
    items: [
      for (final i in r.items)
        _ItemRow(
          id: i.id,
          nameText: i.name,
          priceText: i.price == null ? '' : _idr(i.price!.round()),
        ),
    ],
    rates: [
      for (final x in r.rates)
        _RateRow(
          code: x.currencyCode,
          rate: _plainNumber(x.foreignAmount),
          idr: _idr(x.idrAmount.round()),
          fee: x.serviceFeeIdr == null ? '' : _idr(x.serviceFeeIdr!.round()),
        ),
    ],
  );
}

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
  final List<_StoreDraft> _stores = [];
  bool _loading = true;
  String? _loadError;
  _StoreDraft? _current;
  double _syncTurns = 0; // tiap +1 = satu putaran penuh
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final records = await StoreRepository.instance.fetchMyStores();
      if (!mounted) return;
      final drafts = [
        for (final r in records)
          if (_categoryFrom(r.category) != null) _draftFrom(r),
      ];
      final old = List<_StoreDraft>.of(_stores);
      final keep = _current?.id;
      setState(() {
        _stores
          ..clear()
          ..addAll(drafts);
        _current = drafts.isEmpty
            ? null
            : drafts.firstWhere(
                (d) => d.id == keep,
                orElse: () => drafts.first,
              );
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final d in old) {
          d.dispose();
        }
      });
    } on StoreFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_stores.isEmpty) _loadError = e.message;
      });
      if (_stores.isNotEmpty) _snack(e.message);
    }
  }

  /// Memuat ulang satu toko dari database (id item baru terisi, urutan rapi).
  Future<bool> _refreshCurrent(_StoreDraft d) async {
    try {
      final rec = await StoreRepository.instance.fetchStore(d.id);
      if (!mounted || rec == null || _categoryFrom(rec.category) == null) {
        return false;
      }
      final idx = _stores.indexOf(d);
      if (idx < 0) return false;
      final fresh = _draftFrom(rec);
      setState(() {
        _stores[idx] = fresh;
        if (_current == d) _current = fresh;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => d.dispose());
      return true;
    } on StoreFailure {
      return false;
    }
  }

  Future<void> _openAddStore() async {
    final saved = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const AddStorePage()));
    if (saved == true && mounted) _load();
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
    return showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: action,
      destructive: true,
      icon: Icons.delete_outline,
    );
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
      message: 'It will be removed from your store when you save your changes.',
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
    if (_saving || d == null) return;
    final ok = await _confirm(
      title: 'Delete this store?',
      message:
          '"${_displayName(d)}" and all of its items, prices, and customer comments will be removed. This can\'t be undone.',
      action: 'Delete',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await StoreRepository.instance.deleteStore(d.id);
      if (!mounted) return;
      setState(() {
        final idx = _stores.indexOf(d);
        _stores.removeAt(idx);
        _current = _stores.isEmpty
            ? null
            : _stores[idx < _stores.length ? idx : _stores.length - 1];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => d.dispose());
      _snack('Store deleted');
    } on StoreFailure catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final d = _current;
    if (_saving || d == null) return;
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _snack('Please check the highlighted fields.');
      return;
    }

    final items = <Map<String, dynamic>>[];
    final rates = <Map<String, dynamic>>[];
    if (d.category == StoreCategory.exchange) {
      final seen = <String>{};
      for (final r in d.rates) {
        final code = r.currency.text.trim().toUpperCase();
        if (!seen.add(code)) {
          _snack('Currency $code is listed more than once.');
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
    } else {
      for (final e in d.items) {
        items.add({
          'id': e.id,
          'name': e.name.text.trim(),
          'price': _digits(e.price.text),
        });
      }
    }

    setState(() => _saving = true);
    try {
      await StoreRepository.instance.saveStore(
        storeId: d.id,
        name: d.name.text.trim(),
        items: items,
        rates: rates,
      );
      final refreshed = await _refreshCurrent(d);
      if (!mounted) return;
      _snack(
        refreshed
            ? 'Changes saved'
            : 'Changes saved. Reopen this page to see the latest data.',
      );
    } on StoreFailure catch (e) {
      if (!mounted) return;
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------- Komponen dasar ----------

  InputDecoration _decoration(String hint, {Color fill = Colors.white}) {
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
                          _loading
                              ? '\u201CLoading...\u201D'
                              : '\u201CNo store\u201D',
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
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: _border.withValues(alpha: 0.6)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _underlined(title, size: 17)),
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

  Widget _lockedCategory(StoreCategory c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
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
    return TweenAnimationBuilder<double>(
      key: ObjectKey(entryKey),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 14), child: child),
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
                    child: ListenableBuilder(
                      listenable: titleSource,
                      builder: (_, _) => Text(
                        title(),
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _green,
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
                    validator: (v) => _notEmpty(v, 'Enter the $lower name'),
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
                    keyboardType: TextInputType.number,
                    formatters: [ThousandsSeparatorFormatter()],
                    validator: (v) => _positiveIdr(v, 'Enter the price'),
                  ),
                ],
              ),
            ),
          ],
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
        CurrencyPickerField(
          key: ObjectKey(r.currency),
          controller: r.currency,
          fill: Colors.white,
          onChanged: (_) => setState(() {}),
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
          hint: 'Enter service fee',
          validator: (v) =>
              (v ?? '').trim().isEmpty ? 'Enter the service fee' : null,
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
            color: _accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
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
                'Save Changes',
                style: GoogleFonts.poppins(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
          color: Colors.red.shade400.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
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
      margin: const EdgeInsets.only(top: 28),
      padding: const EdgeInsets.fromLTRB(0, 24, 0, 0),
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
          _addButton('Add a store', _openAddStore),
        ],
      ),
    );
  }

  Widget _content() {
    if (_loading && _stores.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _green),
          ),
        ),
      );
    }
    if (_loadError != null && _stores.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Column(
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 13, color: _grey),
            ),
            TextButton(
              onPressed: _load,
              child: Text(
                'Try again',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _green,
                ),
              ),
            ),
          ],
        ),
      );
    }
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
          current: RadialNavItem.edit,
          onProfile: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const ProfilePage())),
          // Dashboard adalah route pertama (dibuka lewat pushAndRemoveUntil).
          onHome: () => Navigator.of(context).popUntil((r) => r.isFirst),
          onAddStore: _openAddStore,
          onEdit: () {}, // sudah berada di halaman ini
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
                          const SizedBox(height: 22),
                          Reveal(index: 2, child: _myBusinessRow()),
                        ],
                      ),
                    ),
                    Reveal(index: 3, child: _content()),
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
