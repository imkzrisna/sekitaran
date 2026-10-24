import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/wordle/widget/letter_tile.dart'
    show WordleColors;

class InputSection extends StatefulWidget {
  const InputSection({
    super.key,
    required this.onGuess,
    this.enabled = true,
    this.maxLength = 5,
  });

  final void Function(String) onGuess;
  final bool enabled;
  final int maxLength;

  @override
  State<InputSection> createState() => _InputSectionState();
}

class _InputSectionState extends State<InputSection> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitGuess() {
    if (!widget.enabled) return;
    final text = _controller.text.trim().toUpperCase();
    if (text.length != widget.maxLength) {
      setState(() => _error = 'Masukkan ${widget.maxLength} huruf');
      _focusNode.requestFocus();
      return;
    }
    setState(() => _error = null);
    widget.onGuess(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c, width: 1.5),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z]')),
            TextInputFormatter.withFunction(
              (old, next) => next.copyWith(text: next.text.toUpperCase()),
            ),
          ],
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 8,
            color: WordleColors.ink,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            errorText: _error,
            errorStyle: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.red.shade700,
            ),
            enabledBorder: _border(WordleColors.tileBorder),
            focusedBorder: _border(WordleColors.accent),
            disabledBorder: _border(WordleColors.tileBorder),
            errorBorder: _border(Colors.red.shade400),
            focusedErrorBorder: _border(Colors.red.shade400),
            hintText: widget.enabled ? 'MASUKKAN KATA' : 'GAME OVER',
            hintStyle: GoogleFonts.poppins(
              color: Colors.grey.shade400,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: 3,
            ),
          ),
          onSubmitted: (_) => _submitGuess(),
        ),
        const SizedBox(height: 16),
        Opacity(
          opacity: widget.enabled ? 1 : 0.4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.enabled ? _submitGuess : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: WordleColors.correct, width: 2),
              ),
              child: Container(
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: WordleColors.correct,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  'Tebak',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
