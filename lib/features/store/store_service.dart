import 'package:supabase_flutter/supabase_flutter.dart';

class StoreFailure implements Exception {
  const StoreFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class StoreService {
  StoreService._();
  static final instance = StoreService._();

  /// category: 'restaurant' | 'grocery' | 'money_changer'
  Future<String> createStore({
    required String name,
    required String category,
    required double latitude,
    required double longitude,
    List<Map<String, dynamic>> items = const [],
    List<Map<String, dynamic>> rates = const [],
  }) async {
    try {
      final res = await Supabase.instance.client.rpc(
        'create_store',
        params: {
          'p_name': name,
          'p_category': category,
          'p_latitude': latitude,
          'p_longitude': longitude,
          'p_items': items,
          'p_rates': rates,
        },
      );
      return res as String;
    } on AuthException {
      throw const StoreFailure('Sesi berakhir. Silakan masuk kembali.');
    } on PostgrestException catch (e) {
      if (e.code == '23514') {
        throw const StoreFailure('Data tidak valid. Periksa kembali isian.');
      }
      if (e.code == '23505') {
        throw const StoreFailure(
          'Mata uang yang sama diisi lebih dari sekali.',
        );
      }
      throw const StoreFailure('Gagal menyimpan toko. Silakan coba lagi.');
    } catch (_) {
      throw const StoreFailure(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }
}
