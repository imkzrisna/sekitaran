import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sekitaran/features/explore/explore_service.dart';

class ShopDetailFailure implements Exception {
  const ShopDetailFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShopDetailItem {
  const ShopDetailItem({required this.name, this.price});
  final String name;
  final num? price;
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

  /// Data sudah berasal dari database.
  static bool get isSample => false;

  SupabaseClient get _client => Supabase.instance.client;

  // ---------- Parsing ----------

  List<Map<String, dynamic>> _list(Object? v) => v is List
      ? [
          for (final e in v)
            if (e is Map) Map<String, dynamic>.from(e),
        ]
      : const [];

  num? _numOrNull(Object? v) {
    if (v == null) return null;
    return v is num ? v : num.tryParse('$v');
  }

  ShopDetailItem _item(Map<String, dynamic> m) =>
      ShopDetailItem(name: '${m['name'] ?? ''}', price: _numOrNull(m['price']));

  ShopDetailRate _rate(Map<String, dynamic> m) => ShopDetailRate(
    currencyCode: '${m['currency_code'] ?? '-'}',
    foreignAmount: _numOrNull(m['foreign_amount']) ?? 1,
    idrAmount: _numOrNull(m['idr_amount']) ?? 0,
    serviceFee: _numOrNull(m['service_fee_idr']),
  );

  ShopDetailComment _comment(Map<String, dynamic> m) {
    final mine = m['mine'] == true;
    return ShopDetailComment(
      id: '${m['id']}',
      author: mine ? 'You' : '${m['author'] ?? 'user'}',
      body: '${m['body'] ?? ''}',
      createdAt:
          DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
      mine: mine,
    );
  }

  String _message(String raw, {required String fallback}) {
    final m = raw.toLowerCase();
    if (m.contains('comment_too_short')) return 'Write at least 3 characters.';
    if (m.contains('comment_too_long')) return 'Your comment is too long.';
    if (m.contains('comment_rate_limited')) {
      return 'You are commenting too fast. Please try again later.';
    }
    if (m.contains('comment_duplicate')) {
      return 'You already posted this comment on this shop.';
    }
    if (m.contains('comment_own_shop')) {
      return "You can't comment on your own shop.";
    }
    if (m.contains('shop_not_found')) {
      return 'This shop is no longer available.';
    }
    if (m.contains('not_authenticated')) return 'Please log in again.';
    return fallback;
  }

  // ---------- Panggilan ke database ----------

  Future<ShopDetail> fetchDetail(Shop shop) async {
    try {
      final itemRows = await _client
          .from('items')
          .select('id, name, price, created_at')
          .eq('business_id', shop.id)
          .eq('is_active', true)
          .order('created_at');

      final rateRows = await _client
          .from('exchange_rates')
          .select(
            'currency_code, foreign_amount, idr_amount, '
            'service_fee_idr, created_at',
          )
          .eq('business_id', shop.id)
          .order('created_at');

      // Komentar butuh nama yang disamarkan lewat fungsi SQL. Jika fungsi
      // belum dipasang atau gagal, halaman tetap tampil tanpa komentar.
      var comments = <ShopDetailComment>[];
      try {
        final res = await _client.rpc(
          'shop_detail',
          params: {'p_business_id': shop.id},
        );
        if (res is Map) {
          comments = _list(res['comments']).map(_comment).toList();
        }
      } catch (_) {}

      return ShopDetail(
        items: _list(itemRows).map(_item).toList(),
        rates: _list(rateRows).map(_rate).toList(),
        comments: comments,
      );
    } on AuthException {
      throw const ShopDetailFailure('Session expired. Please log in again.');
    } on PostgrestException catch (e) {
      throw ShopDetailFailure(
        _message(e.message, fallback: 'Could not load this shop.'),
      );
    } on FormatException {
      throw const ShopDetailFailure('Unexpected data from the server.');
    } on TypeError {
      throw const ShopDetailFailure('Unexpected data from the server.');
    } catch (_) {
      throw const ShopDetailFailure(
        'Could not connect to the server. Check your internet connection.',
      );
    }
  }

  Future<ShopDetailComment> postComment(Shop shop, String body) async {
    final text = body.trim();
    if (text.length < minCommentLength) {
      throw const ShopDetailFailure('Write at least 3 characters.');
    }
    if (text.length > maxCommentLength) {
      throw const ShopDetailFailure('Your comment is too long.');
    }
    try {
      final id = await _client.rpc(
        'add_store_comment',
        params: {'p_business_id': shop.id, 'p_body': text},
      );
      return ShopDetailComment(
        id: '$id',
        author: 'You',
        body: text,
        createdAt: DateTime.now(),
        mine: true,
      );
    } on AuthException {
      throw const ShopDetailFailure('Session expired. Please log in again.');
    } on PostgrestException catch (e) {
      throw ShopDetailFailure(
        _message(e.message, fallback: 'Could not post your comment.'),
      );
    } catch (_) {
      throw const ShopDetailFailure(
        'Could not connect to the server. Check your internet connection.',
      );
    }
  }
}
