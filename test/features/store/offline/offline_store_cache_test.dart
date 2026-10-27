import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:sekitaran/features/store/offline/offline_store_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('./test_hive_data');
  });

  setUp(() async {
    await OfflineStoreCache.instance.initialize();
    await OfflineStoreCache.instance.clear();
  });

  tearDown(() async {
    await OfflineStoreCache.instance.clear();
  });

  tearDownAll(() async {
    await OfflineStoreCache.instance.close();
    await Hive.deleteFromDisk();
  });

  test('menyimpan dan membaca toko', () async {
    final store = <String, dynamic>{
      'id': 'store-001',
      'name': 'Warung Makan Bu Sari',
      'category': 'restaurant',
      'latitude': -7.7956,
      'longitude': 110.3695,
      'items': [
        {'id': 'item-001', 'name': 'Mie Ayam', 'price': 12000},
      ],
    };

    await OfflineStoreCache.instance.saveStore(store);

    final result = OfflineStoreCache.instance.getStore('store-001');

    expect(result, isNotNull);
    expect(result!['name'], 'Warung Makan Bu Sari');
    expect(result['latitude'], -7.7956);
    expect(result['items'], isA<List>());
  });

  test('memperbarui toko dengan ID yang sama', () async {
    await OfflineStoreCache.instance.saveStore({
      'id': 'store-001',
      'name': 'Warung Lama',
    });

    await OfflineStoreCache.instance.saveStore({
      'id': 'store-001',
      'name': 'Warung Baru',
    });

    expect(
      OfflineStoreCache.instance.getStore('store-001')!['name'],
      'Warung Baru',
    );
    expect(OfflineStoreCache.instance.getAllStores(), hasLength(1));
  });

  test('menghapus toko dari cache', () async {
    await OfflineStoreCache.instance.saveStore({
      'id': 'store-001',
      'name': 'Warung Makan Bu Sari',
    });

    await OfflineStoreCache.instance.removeStore('store-001');

    expect(OfflineStoreCache.instance.containsStore('store-001'), isFalse);
    expect(OfflineStoreCache.instance.getAllStores(), isEmpty);
  });

  test('menolak toko tanpa ID', () async {
    expect(
      () => OfflineStoreCache.instance.saveStore({'name': 'Warung tanpa ID'}),
      throwsArgumentError,
    );
  });
}
