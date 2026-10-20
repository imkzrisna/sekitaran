import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegularHomePage extends StatelessWidget {
  const RegularHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F9F8),
      body: SafeArea(
        child: Center(
          child: Text(
            'Regular User Home',
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF103D17),
            ),
          ),
        ),
      ),
    );
  }
}
