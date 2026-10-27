import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/features/store/offline/offline_store_cache.dart';

class OfflineStoreFailure implements Exception {
  const OfflineStoreFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class OfflineStoreService {
  OfflineStoreService._();

  static final OfflineStoreService instance = OfflineStoreService._();

  final OfflineStoreCache _cache = OfflineStoreCache.instance;

  SupabaseClient get _client => Supabase.instance.client;

  /// Mengambil detail toko publik dari Supabase dan menyimpannya secara lokal.
  ///
  /// Pemanggilan ini memerlukan koneksi internet.
  /// Hak akses tetap mengikuti kebijakan RLS Supabase.
  Future<void> savePublicStoreForOffline(String storeId) async {
    if (storeId.trim().isEmpty) {
      throw const OfflineStoreFailure('ID toko tidak boleh kosong.');
    }

    try {
      final row = await _client
          .from('businesses')
          .select(
            'id, name, category, latitude, longitude, '
            'items(id, name, price, kind, is_active, created_at), '
            'exchange_rates(id, currency_code, foreign_amount, idr_amount, '
            'service_fee_idr, created_at)',
          )
          .eq('id', storeId)
          .maybeSingle();

      if (row == null) {
        throw const OfflineStoreFailure(
          'Toko tidak ditemukan atau tidak dapat diakses.',
        );
      }

      final items = ((row['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['is_active'] != false)
          .map(
            (item) => <String, dynamic>{
              'id': item['id'],
              'name': item['name'],
              'price': item['price'],
              'kind': item['kind'],
            },
          )
          .toList();

      final rates = ((row['exchange_rates'] as List?) ?? const [])
          .whereType<Map>()
          .map((rate) => Map<String, dynamic>.from(rate))
          .map(
            (rate) => <String, dynamic>{
              'id': rate['id'],
              'currency_code': rate['currency_code'],
              'foreign_amount': rate['foreign_amount'],
              'idr_amount': rate['idr_amount'],
              'service_fee_idr': rate['service_fee_idr'],
            },
          )
          .toList();

      await _cache.saveStore({
        'id': row['id'],
        'name': row['name'],
        'category': row['category'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'items': items,
        'exchange_rates': rates,
        'cached_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on OfflineStoreFailure {
      rethrow;
    } on PostgrestException catch (e) {
      throw OfflineStoreFailure(
        'Gagal mengambil detail toko dari server: ${e.message}',
      );
    } catch (_) {
      throw const OfflineStoreFailure(
        'Gagal menyimpan toko offline. Periksa koneksi dan penyimpanan lokal.',
      );
    }
  }

  /// Membaca toko yang tersimpan tanpa menghubungi Supabase.
  Map<String, dynamic>? getOfflineStore(String storeId) {
    return _cache.getStore(storeId);
  }

  /// Mengambil semua toko yang tersimpan secara lokal.
  List<Map<String, dynamic>> getOfflineStores() {
    return _cache.getAllStores();
  }

  /// Memeriksa apakah toko tersedia secara offline.
  bool isStoreAvailableOffline(String storeId) {
    return _cache.containsStore(storeId);
  }

  /// Menghapus satu toko dari daftar offline.
  Future<void> removeOfflineStore(String storeId) {
    return _cache.removeStore(storeId);
  }
}
