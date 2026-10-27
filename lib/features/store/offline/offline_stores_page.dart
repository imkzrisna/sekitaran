import 'package:flutter/material.dart';
import 'package:sekitaran/features/store/offline/saved_places_view.dart';

/// Saved Places yang dibuka dari halaman login. Tanpa menu melingkar, jadi
/// halaman ini punya tombol kembali sendiri.
class OfflineStoresPage extends StatelessWidget {
  const OfflineStoresPage({super.key});

  static const _green = Color(0xFF103D17);
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 20,
                        color: _green,
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: SavedPlacesView(topPadding: 24, bottomPadding: 48),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
