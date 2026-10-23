import 'package:flutter/material.dart';

class GreenBox extends StatelessWidget {
  const GreenBox({super.key, required this.char});

  final String char;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Container(
        decoration: const BoxDecoration(
          color: Color.fromRGBO(16, 61, 23, 1),
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: Center(
          child: Text(
            char,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
