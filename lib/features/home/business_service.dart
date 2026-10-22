import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceFailure implements Exception {
  const ServiceFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class Business {
  const Business({required this.id, required this.name});
  final String id;
  final String name;
}

class StoreOverview {
  const StoreOverview({
    required this.listedItems,
    required this.commentCount,
    required this.unreadCount,
  });
  final int listedItems;
  final int commentCount;
  final int unreadCount;
}

class StoreComment {
  const StoreComment({
    required this.id,
    required this.authorMasked,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });
  final String id;
  final String authorMasked;
  final String body;
  final DateTime createdAt;
  final bool isRead;
}

/// "just now", "2 minutes ago", "1 hour ago", "3 days ago"
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) {
    final n = d.inMinutes;
    return '$n minute${n == 1 ? '' : 's'} ago';
  }
  if (d.inHours < 24) {
    final n = d.inHours;
    return '$n hour${n == 1 ? '' : 's'} ago';
  }
  final n = d.inDays;
  return '$n day${n == 1 ? '' : 's'} ago';
}

class BusinessService {
  BusinessService._();
  static final instance = BusinessService._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ServiceFailure {
      rethrow;
    } on AuthException {
      throw const ServiceFailure('Sesi berakhir. Silakan masuk kembali.');
    } on PostgrestException catch (e) {
      throw ServiceFailure('Gagal memuat data: ${e.message}');
    } catch (_) {
      throw const ServiceFailure(
        'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }
  }

  /// Daftar toko milik user yang sedang login (kosong = belum punya toko).
  Future<List<Business>> fetchMyBusinesses() {
    return _guard(() async {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) {
        throw const ServiceFailure('Sesi berakhir. Silakan masuk kembali.');
      }
      final rows = await _client
          .from('businesses')
          .select('id, name')
          .eq('owner_id', uid)
          .order('created_at');
      return rows
          .map(
            (r) => Business(id: r['id'] as String, name: r['name'] as String),
          )
          .toList();
    });
  }

  Future<StoreOverview> fetchOverview(String businessId) {
    return _guard(() async {
      final res = await _client.rpc(
        'business_overview',
        params: {'p_business_id': businessId},
      );
      final list = res as List;
      if (list.isEmpty) {
        return const StoreOverview(
          listedItems: 0,
          commentCount: 0,
          unreadCount: 0,
        );
      }
      final r = list.first as Map<String, dynamic>;
      return StoreOverview(
        listedItems: (r['listed_items'] as num).toInt(),
        commentCount: (r['comment_count'] as num).toInt(),
        unreadCount: (r['unread_count'] as num).toInt(),
      );
    });
  }

  Future<List<StoreComment>> fetchRecentComments(
    String businessId, {
    int limit = 20,
  }) {
    return _guard(() async {
      final res = await _client.rpc(
        'recent_comments',
        params: {'p_business_id': businessId, 'p_limit': limit},
      );
      return (res as List).map((e) {
        final r = e as Map<String, dynamic>;
        return StoreComment(
          id: r['id'] as String,
          authorMasked: r['author_masked'] as String,
          body: r['body'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          isRead: r['is_read'] as bool,
        );
      }).toList();
    });
  }

  /// Semua komentar toko (terbaru dulu), dimuat bertahap.
  Future<List<StoreComment>> fetchComments(
    String businessId, {
    int limit = 20,
    int offset = 0,
  }) {
    return _guard(() async {
      final res = await _client.rpc(
        'business_comments',
        params: {
          'p_business_id': businessId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return (res as List).map((e) {
        final r = e as Map<String, dynamic>;
        return StoreComment(
          id: r['id'] as String,
          authorMasked: r['author_masked'] as String,
          body: r['body'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          isRead: r['is_read'] as bool,
        );
      }).toList();
    });
  }

  Future<void> markCommentRead(String commentId) {
    return _guard(() async {
      final res = await _client.rpc(
        'mark_comment_read',
        params: {'p_comment_id': commentId},
      );
      if (res != true) {
        throw const ServiceFailure('Komentar tidak ditemukan.');
      }
    });
  }

  Future<void> markAllCommentsRead(String businessId) {
    return _guard(() async {
      await _client.rpc(
        'mark_comments_read',
        params: {'p_business_id': businessId},
      );
    });
  }
}
