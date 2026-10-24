import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tampilan error lokasi yang sama di semua halaman.
class LocationErrorView extends StatelessWidget {
  const LocationErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  static const _green = Color(0xFF103D17);
  static const _grey = Color(0xFF7A7A7A);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.location_off_outlined, color: _grey, size: 30),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12.5, color: _grey, height: 1.4),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text(
            'Try again',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: _green,
            ),
          ),
        ),
      ],
    );
  }
}
