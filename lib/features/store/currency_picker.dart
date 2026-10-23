import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/store/currency_repository.dart';

const _green = Color(0xFF103D17);
const _ink = Color(0xFF252525);
const _bg = Color(0xFFF2F9F8);
const _border = Color(0xFFC9C9C9);
const _grey = Color(0xFF7A7A7A);

/// Pengganti kolom teks "Foreign currency". Menulis kode (mis. "MYR") ke
/// [controller], jadi logika simpan yang sudah ada tidak berubah.
class CurrencyPickerField extends StatelessWidget {
  const CurrencyPickerField({
    super.key,
    required this.controller,
    this.onChanged,
    this.validator,
    this.fill = _bg,
    this.radius = 10,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// Bila null: wajib memilih.
  final String? Function(String?)? validator;
  final Color fill;
  final double radius;

  Future<void> _open(BuildContext context, FormFieldState<String> state) async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<Currency>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CurrencySheet(selected: state.value),
    );
    if (picked == null) return;
    controller.text = picked.code;
    state.didChange(picked.code);
    onChanged?.call(picked.code);
  }

  @override
  Widget build(BuildContext context) {
    final initial = controller.text.trim().toUpperCase();
    return FormField<String>(
      initialValue: initial.isEmpty ? null : initial,
      validator:
          validator ??
          (v) => (v == null || v.isEmpty) ? 'Select a currency' : null,
      builder: (state) {
        final code = state.value;
        final c = code == null
            ? null
            : CurrencyRepository.instance.lookup(code);
        final text = code == null
            ? 'Select currency'
            : (c == null ? code : '${c.label} (${c.code})');
        final borderColor = state.hasError ? Colors.red.shade400 : _border;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: () => _open(context, state),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(color: borderColor, width: 1.2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: code == null
                              ? FontWeight.w300
                              : FontWeight.w500,
                          color: code == null ? const Color(0xFF9A9A9A) : _ink,
                        ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down, color: _grey),
                  ],
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 12),
                child: Text(
                  state.errorText!,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({this.selected});
  final String? selected;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  late final Future<List<Currency>> _future = CurrencyRepository.instance
      .load();
  String _query = '';

  bool _match(Currency c) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.code.toLowerCase().contains(q) ||
        c.name.toLowerCase().contains(q) ||
        (c.nameId?.toLowerCase().contains(q) ?? false) ||
        c.country.toLowerCase().contains(q) ||
        (c.symbol?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: SizedBox(
        height: mq.size.height * 0.72,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
                child: Text(
                  'Select currency',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: GoogleFonts.poppins(fontSize: 14, color: _ink),
                  decoration: InputDecoration(
                    hintText: 'Search code, name, country, or symbol',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xFF9A9A9A),
                    ),
                    prefixIcon: const Icon(Icons.search, color: _grey),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _green),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Currency>>(
                  future: _future,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _green,
                          ),
                        ),
                      );
                    }
                    final list = snap.data!.where(_match).toList();
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          'No currency found.',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _grey,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final c = list[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 24,
                          ),
                          title: Text(
                            '${c.label} (${c.code})',
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w500,
                              color: _ink,
                            ),
                          ),
                          subtitle: Text(
                            c.symbol == null
                                ? c.country
                                : '${c.country} \u00B7 ${c.symbol}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _grey,
                            ),
                          ),
                          trailing: c.code == widget.selected
                              ? const Icon(Icons.check, color: _green)
                              : null,
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
