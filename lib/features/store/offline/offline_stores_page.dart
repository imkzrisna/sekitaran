import 'package:flutter/material.dart';
import 'package:sekitaran/features/store/offline/saved_places_view.dart';

/// Saved Places yang dibuka dari halaman login. Tanpa menu melingkar dan
/// tanpa tombol kembali; pengguna kembali lewat gestur/tombol back sistem.
class OfflineStoresPage extends StatelessWidget {
  const OfflineStoresPage({super.key});

  static const _bg = Color(0xFFF2F9F8);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: const SavedPlacesView(topPadding: 56, bottomPadding: 48),
          ),
        ),
      ),
    );
  }
}
