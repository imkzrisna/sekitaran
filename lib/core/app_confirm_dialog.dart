import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _green = Color(0xFF103D17);
const _ink = Color(0xFF252525);
const _muted = Color(0xFF5F5F5F);
const _danger = Color(0xFFD32F2F);

/// Dialog konfirmasi seragam. Mengembalikan true bila user menekan tombol aksi.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
    ),
  );
  return result == true;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
    this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  Widget _button({
    required String text,
    required VoidCallback onTap,
    required bool filled,
    required Color color,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.2),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = destructive ? _danger : _green;
    final tint = destructive
        ? const Color(0xFFFCEBEB)
        : const Color(0xFFE6F0E7);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 26, color: accent),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: _muted,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _button(
                      text: cancelLabel,
                      onTap: () => Navigator.of(context).pop(false),
                      filled: false,
                      color: _green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _button(
                      text: confirmLabel,
                      onTap: () => Navigator.of(context).pop(true),
                      filled: true,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
