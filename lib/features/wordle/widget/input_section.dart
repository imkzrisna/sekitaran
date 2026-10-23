import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submitGuess() {
    final text = _controller.text.trim().toUpperCase();
    if (text.length == widget.maxLength && widget.enabled) {
      widget.onGuess(text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC9C9C9), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF5BAA5F), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFC9C9C9), width: 2),
            ),
            hintText: widget.enabled ? 'MASUKKAN KATA' : 'GAME OVER',
            hintStyle: TextStyle(
              color: widget.enabled
                  ? Colors.grey.shade400
                  : Colors.grey.shade600,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: 4,
            ),
          ),
          onSubmitted: (_) => _submitGuess(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: widget.enabled ? _submitGuess : null,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF103D17),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: const Text(
              'TEBAK',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

