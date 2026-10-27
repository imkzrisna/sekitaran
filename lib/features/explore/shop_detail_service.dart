import 'package:sekitaran/features/explore/explore_service.dart';

class ShopDetailFailure implements Exception {
  const ShopDetailFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShopDetailItem {
  const ShopDetailItem({required this.name, required this.price});
  final String name;
  final num price;
}

class ShopDetailRate {
  const ShopDetailRate({
    required this.currencyCode,
    required this.foreignAmount,
    required this.idrAmount,
    this.serviceFee,
  });
  final String currencyCode;
  final num foreignAmount;
  final num idrAmount;
  final num? serviceFee;
}

class ShopDetailComment {
  const ShopDetailComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.mine = false,
  });
  final String id;
  final String author;
  final String body;
  final DateTime createdAt;
  final bool mine;
}

class ShopDetail {
  const ShopDetail({
    required this.items,
    required this.rates,
    required this.comments,
  });
  final List<ShopDetailItem> items;
  final List<ShopDetailRate> rates;
  final List<ShopDetailComment> comments;
}

/// Rupiah dengan titik ribuan: 15000 -> "Rp 15.000".
String formatRupiah(num value) {
  final n = value.round();
  final digits = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write('.');
    b.write(digits[i]);
  }
  return 'Rp ${n < 0 ? '-' : ''}$b';
}

class ShopDetailService {
  ShopDetailService._();
  static final instance = ShopDetailService._();

  static const maxCommentLength = 300;
  static const minCommentLength = 3;

  /// true selama data masih contoh. Ubah/hapus setelah tersambung ke database.
  static const isSample = true;

  // TODO: ganti dengan Supabase. Sementara komentar hanya tersimpan di memori.
  final Map<String, List<ShopDetailComment>> _posted = {};

  Future<ShopDetail> fetchDetail(Shop shop) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final List<ShopDetailItem> items;
    final List<ShopDetailRate> rates;
    if (shop.category == ShopCategory.exchange) {
      items = const [];
      rates = const [
        ShopDetailRate(
          currencyCode: 'USD',
          foreignAmount: 1,
          idrAmount: 15800,
          serviceFee: 2000,
        ),
        ShopDetailRate(currencyCode: 'SGD', foreignAmount: 1, idrAmount: 12300),
        ShopDetailRate(
          currencyCode: 'EUR',
          foreignAmount: 1,
          idrAmount: 17200,
          serviceFee: 2000,
        ),
      ];
    } else if (shop.category == ShopCategory.restaurant) {
      rates = const [];
      items = const [
        ShopDetailItem(name: 'Nasi Goreng Spesial', price: 15000),
        ShopDetailItem(name: 'Ayam Bakar', price: 22000),
        ShopDetailItem(name: 'Mie Goreng', price: 14000),
        ShopDetailItem(name: 'Es Teh Manis', price: 5000),
      ];
    } else {
      rates = const [];
      items = const [
        ShopDetailItem(name: 'Beras 5 kg', price: 68000),
        ShopDetailItem(name: 'Minyak Goreng 2 L', price: 36000),
        ShopDetailItem(name: 'Gula Pasir 1 kg', price: 17500),
        ShopDetailItem(name: 'Telur Ayam 1 kg', price: 28000),
      ];
    }

    final now = DateTime.now();
    final seed = [
      ShopDetailComment(
        id: 'seed-1',
        author: 'ra***ni',
        body: 'Pelayanannya ramah dan harganya sesuai.',
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ShopDetailComment(
        id: 'seed-2',
        author: 'bu***ar',
        body: 'Tempatnya mudah ditemukan, tidak terlalu ramai di sore hari.',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];

    return ShopDetail(
      items: items,
      rates: rates,
      comments: [...?_posted[shop.id], ...seed],
    );
  }

  Future<ShopDetailComment> postComment(Shop shop, String body) async {
    final text = body.trim();
    if (text.length < minCommentLength) {
      throw const ShopDetailFailure('Write at least 3 characters.');
    }
    if (text.length > maxCommentLength) {
      throw const ShopDetailFailure('Your comment is too long.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final c = ShopDetailComment(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      author: 'You',
      body: text,
      createdAt: DateTime.now(),
      mine: true,
    );
    _posted.putIfAbsent(shop.id, () => []).insert(0, c);
    return c;
  }
}
