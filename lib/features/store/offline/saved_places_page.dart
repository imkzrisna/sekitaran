import 'package:flutter/material.dart';
import 'package:sekitaran/features/home/user_radial_menu.dart';
import 'package:sekitaran/features/store/offline/saved_places_view.dart';

/// Saved Places yang dibuka dari dashboard Regular User, dengan menu melingkar.
class SavedPlacesPage extends StatelessWidget {
  const SavedPlacesPage({super.key});

  static const _bg = Color(0xFFF2F9F8);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: const SavedPlacesView(),
              ),
            ),
          ),
        ),
        const UserRadialMenu(),
      ],
    );
  }
}
