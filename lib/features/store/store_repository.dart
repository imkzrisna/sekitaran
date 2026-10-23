import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/features/store/store_service.dart' show StoreFailure;

class StoreItemRecord {
  const StoreItemRecord({
    required this.id,
    required this.name,
    required this.price,
    required this.kind,
  });
  final String id;
  final String name;
  final num? price;
  final String kind;
}

class StoreRateRecord {
  const StoreRateRecord({
    required this.currencyCode,
    required this.foreignAmount,
    required this.idrAmount,
    required this.serviceFeeIdr,
  });
  final String currencyCode;
  final num foreignAmount;
  final num idrAmount;
  final num? serviceFeeIdr;
}

class StoreRecord {
  const StoreRecord({
    required this.id,
    required this.name,
    required this.category,
    required this.items,
    required this.rates,
  });
  final String id;
  final String name;
  final String? category; // restaurant | grocery | money_changer
  final List<StoreItemRecord> items;
  final List<StoreRateRecord> rates;
}

class StoreRepository {
  StoreRepository._();
  static final instance = StoreRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  static const _select =
      'id, name, category, '
      'items(id, name, price, kind, is_active, created_at), '
      'exchange_rates(id, currency_code, foreign_amount, idr_amount, '
      'service_fee_idr, created_at)';

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on StoreFailure {
      rethrow;
    } on AuthException {
      throw const StoreFailure('Sesi berakhir. Silakan masuk kembali.');
    } on PostgrestException catch (e) {
      switch (e.code) {
        case 'P0002':
          throw const StoreFailure(
            'Toko tidak ditemukan atau bukan milik Anda.',
          );
        case '23503':
          throw StoreFailure(
            e.message.contains('exchange_rates_currency_fkey')
                ? 'Mata uang tidak didukung. Pilih dari daftar.'
                : 'Data terkait tidak ditemukan.',
          );
        case '23505':
          throw const StoreFailure(
            'Mata uang yang sama diisi lebih dari sekali.',
          );
        case '23514':
        case '22P02':
          throw const StoreFailure('Data tidak valid. Periksa kembali isian.');
        case '42501':
          throw const StoreFailure(
            'Anda tidak memiliki izin untuk tindakan ini.',
          );
        case 'PGRST202':
          throw const StoreFailure(
            'Fungsi save_store belum ada di database. Jalankan SQL-nya dulu.',
          );
      }
      throw StoreFailure('Gagal memproses data: ${e.message}');
    } catch (_) {
      throw const StoreFailure(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  num? _num(Object? v) =>
      v == null ? null : (v is num ? v : num.tryParse(v.toString()));

  int _byCreated(Map<String, dynamic> a, Map<String, dynamic> b) {
    final c = (a['created_at'] as String).compareTo(b['created_at'] as String);
    return c != 0 ? c : (a['id'] as String).compareTo(b['id'] as String);
  }

  StoreRecord _parse(Map<String, dynamic> r) {
    List<Map<String, dynamic>> list(String key) =>
        ((r[key] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
          ..sort(_byCreated);

    return StoreRecord(
      id: r['id'] as String,
      name: r['name'] as String,
      category: r['category'] as String?,
      items: [
        for (final i in list('items'))
          if (i['is_active'] != false)
            StoreItemRecord(
              id: i['id'] as String,
              name: i['name'] as String,
              price: _num(i['price']),
              kind: i['kind'] as String,
            ),
      ],
      rates: [
        for (final x in list('exchange_rates'))
          StoreRateRecord(
            currencyCode: x['currency_code'] as String,
            foreignAmount: _num(x['foreign_amount']) ?? 1,
            idrAmount: _num(x['idr_amount']) ?? 0,
            serviceFeeIdr: _num(x['service_fee_idr']),
          ),
      ],
    );
  }

  String _uid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const StoreFailure('Sesi berakhir. Silakan masuk kembali.');
    }
    return uid;
  }

  Future<List<StoreRecord>> fetchMyStores() => _guard(() async {
    final rows = await _client
        .from('businesses')
        .select(_select)
        .eq('owner_id', _uid())
        .order('created_at');
    return rows.map(_parse).toList();
  });

  Future<StoreRecord?> fetchStore(String id) => _guard(() async {
    final row = await _client
        .from('businesses')
        .select(_select)
        .eq('id', id)
        .eq('owner_id', _uid())
        .maybeSingle();
    return row == null ? null : _parse(row);
  });

  /// items: [{'id': String?, 'name': ..., 'price': '15000'}]
  /// rates: [{'currency_code': 'USD', 'foreign_amount': '1',
  ///          'idr_amount': '15800', 'service_fee_idr': '2000' | null}]
  Future<void> saveStore({
    required String storeId,
    required String name,
    List<Map<String, dynamic>> items = const [],
    List<Map<String, dynamic>> rates = const [],
  }) => _guard<void>(() async {
    await _client.rpc(
      'save_store',
      params: {
        'p_business_id': storeId,
        'p_name': name,
        'p_items': items,
        'p_rates': rates,
      },
    );
  });

  Future<void> deleteStore(String storeId) => _guard<void>(() async {
    final rows = await _client
        .from('businesses')
        .delete()
        .eq('id', storeId)
        .select('id');
    if (rows.isEmpty) {
      throw const StoreFailure('Toko tidak ditemukan atau sudah dihapus.');
    }
  });
}
