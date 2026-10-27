import 'dart:convert';

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

  /// Mengambil data terbaru toko dari Supabase (tanpa menyimpannya).
  Future<Map<String, dynamic>> _fetchSnapshot(String storeId) async {
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
        .map((i) => Map<String, dynamic>.from(i))
        .where((i) => i['is_active'] != false)
        .map(
          (i) => <String, dynamic>{
            'id': i['id'],
            'name': i['name'],
            'price': i['price'],
            'kind': i['kind'],
          },
        )
        .toList();

    final rates = ((row['exchange_rates'] as List?) ?? const [])
        .whereType<Map>()
        .map((r) => Map<String, dynamic>.from(r))
        .map(
          (r) => <String, dynamic>{
            'id': r['id'],
            'currency_code': r['currency_code'],
            'foreign_amount': r['foreign_amount'],
            'idr_amount': r['idr_amount'],
            'service_fee_idr': r['service_fee_idr'],
          },
        )
        .toList();

    return {
      'id': row['id'],
      'name': row['name'],
      'category': row['category'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
      'items': items,
      'exchange_rates': rates,
    };
  }

  /// true = pemilik sudah mengubah data, false = masih sama,
  /// null = tidak bisa dicek (offline, toko dihapus, dll).
  Future<bool?> checkForUpdate(String storeId) async {
    final local = _cache.getStore(storeId);
    if (local == null) return null;
    try {
      final remote = await _fetchSnapshot(storeId);
      return _signature(local) != _signature(remote);
    } catch (_) {
      return null;
    }
  }

  String _signature(Map<String, dynamic> s) {
    Object? norm(Object? v) {
      if (v is num) return v.toDouble();
      if (v is Map) {
        final e = v.entries.toList()
          ..sort((a, b) => '${a.key}'.compareTo('${b.key}'));
        return {for (final x in e) '${x.key}': norm(x.value)};
      }
      if (v is List) return v.map(norm).toList();
      return v;
    }

    List<Object?> sorted(Object? raw) {
      final list = (raw is List ? raw : const []).whereType<Map>().toList()
        ..sort((a, b) => '${a['id']}'.compareTo('${b['id']}'));
      return list.map(norm).toList();
    }

    return jsonEncode({
      'name': s['name'],
      'category': s['category'],
      'latitude': norm(s['latitude']),
      'longitude': norm(s['longitude']),
      'items': sorted(s['items']),
      'exchange_rates': sorted(s['exchange_rates']),
    });
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
