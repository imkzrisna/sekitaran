import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:sekitaran/features/store/offline/offline_store_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Hive.init('./test_hive_persistence_data');
  });

  setUp(() async {
    await OfflineStoreCache.instance.initialize();
    await OfflineStoreCache.instance.clear();
  });

  tearDown(() async {
    await OfflineStoreCache.instance.close();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  test('data toko tetap tersedia setelah cache dibuka kembali', () async {
    await OfflineStoreCache.instance.saveStore({
      'id': 'store-persistence-001',
      'name': 'Warung Offline',
      'category': 'restaurant',
      'latitude': -7.7956,
      'longitude': 110.3695,
      'items': [
        {'id': 'item-001', 'name': 'Mie Ayam', 'price': 12000},
      ],
    });

    await OfflineStoreCache.instance.close();
    await OfflineStoreCache.instance.initialize();

    final store = OfflineStoreCache.instance.getStore(
      'store-persistence-001',
    );

    expect(store, isNotNull);
    expect(store!['name'], 'Warung Offline');
    expect(store['latitude'], -7.7956);
    expect(store['items'], isA<List>());
  });
}
