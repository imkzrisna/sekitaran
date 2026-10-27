import 'package:hive_ce_flutter/hive_flutter.dart';

/// Menyimpan salinan data toko agar bisa dibaca tanpa internet.
///
/// Data disimpan sebagai Map agar tidak memerlukan TypeAdapter
/// khusus untuk setiap model toko.
class OfflineStoreCache {
  OfflineStoreCache._();

  static final OfflineStoreCache instance = OfflineStoreCache._();

  static const String _boxName = 'offline_stores';

  Box<Map<dynamic, dynamic>>? _box;

  bool get isInitialized => _box?.isOpen ?? false;

  /// Panggil satu kali saat aplikasi mulai dijalankan.
  Future<void> initialize() async {
    if (isInitialized) return;

    _box = await Hive.openBox<Map<dynamic, dynamic>>(_boxName);
  }

  Box<Map<dynamic, dynamic>> get _storage {
    final box = _box;

    if (box == null || !box.isOpen) {
      throw StateError(
        'OfflineStoreCache belum diinisialisasi. '
        'Panggil initialize() terlebih dahulu.',
      );
    }

    return box;
  }

  /// Simpan atau perbarui salinan satu toko.
  Future<void> saveStore(Map<String, dynamic> store) async {
    final id = store['id'];

    if (id is! String || id.trim().isEmpty) {
      throw ArgumentError('ID toko wajib berupa String yang tidak kosong.');
    }

    await _storage.put(id, Map<String, dynamic>.from(store));
  }

  /// Ambil salinan toko berdasarkan ID.
  Map<String, dynamic>? getStore(String id) {
    final value = _storage.get(id);

    if (value == null) return null;

    return Map<String, dynamic>.from(value);
  }

  /// Ambil semua toko yang tersimpan.
  List<Map<String, dynamic>> getAllStores() {
    return _storage.values
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
  }

  /// Periksa apakah toko sudah tersimpan untuk penggunaan offline.
  bool containsStore(String id) {
    return _storage.containsKey(id);
  }

  /// Hapus salinan satu toko.
  Future<void> removeStore(String id) async {
    await _storage.delete(id);
  }

  /// Hapus seluruh toko offline.
  Future<void> clear() async {
    await _storage.clear();
  }

  /// Tutup box ketika memang diperlukan.
  Future<void> close() async {
    final box = _box;

    if (box != null && box.isOpen) {
      await box.close();
    }

    _box = null;
  }
}
