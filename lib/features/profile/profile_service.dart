import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileFailure implements Exception {
  const ProfileFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Foto profil: file disimpan di Storage (bucket `avatars`, folder `<uid>`),
/// alamatnya dicatat di profiles.avatar_url.
class ProfileService {
  ProfileService._();
  static final instance = ProfileService._();

  static const bucket = 'avatars';
  static const maxBytes = 2 * 1024 * 1024;
  static const _types = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  SupabaseClient get _client => Supabase.instance.client;

  String _uid() {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) {
      throw const ProfileFailure('Session expired. Please log in again.');
    }
    return uid;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on ProfileFailure {
      rethrow;
    } on StorageException catch (e) {
      throw ProfileFailure('Storage error: ${e.message}');
    } on PostgrestException catch (e) {
      throw ProfileFailure('Could not save profile: ${e.message}');
    } catch (_) {
      throw const ProfileFailure(
        'Could not connect to the server. Check your internet connection.',
      );
    }
  }

  Future<String?> fetchAvatarUrl() {
    return _guard(() async {
      final row = await _client
          .from('profiles')
          .select('avatar_url')
          .eq('id', _uid())
          .maybeSingle();
      final v = row?['avatar_url'];
      return (v is String && v.isNotEmpty) ? v : null;
    });
  }

  /// Mengunggah foto baru, mencatat alamatnya, lalu menghapus foto lama.
  Future<String> uploadAvatar(Uint8List bytes, String fileName) {
    return _guard(() async {
      final uid = _uid();
      final ext = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : '';
      final type = _types[ext];
      if (type == null) {
        throw const ProfileFailure(
          'Unsupported photo format. Use JPG, PNG, or WebP.',
        );
      }
      if (bytes.length > maxBytes) {
        throw const ProfileFailure('Photo is too large (max 2 MB).');
      }

      String? old;
      try {
        old = await fetchAvatarUrl();
      } on ProfileFailure {
        old = null;
      }

      // Nama unik tiap unggah agar foto baru tidak tertahan cache.
      final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      final storage = _client.storage.from(bucket);
      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: FileOptions(contentType: type),
      );
      final url = storage.getPublicUrl(path);

      try {
        final rows = await _client
            .from('profiles')
            .update({
              'avatar_url': url,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', uid)
            .select();
        if (rows.isEmpty) throw const ProfileFailure('Profile not found.');
      } catch (_) {
        await _removeObject(path); // jangan tinggalkan file yatim
        rethrow;
      }

      if (old != null) {
        final oldPath = _pathFromUrl(old);
        if (oldPath != null) await _removeObject(oldPath);
      }
      return url;
    });
  }

  Future<void> removeAvatar() {
    return _guard(() async {
      final uid = _uid();
      final old = await fetchAvatarUrl();
      final rows = await _client
          .from('profiles')
          .update({
            'avatar_url': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', uid)
          .select();
      if (rows.isEmpty) throw const ProfileFailure('Profile not found.');
      if (old != null) {
        final oldPath = _pathFromUrl(old);
        if (oldPath != null) await _removeObject(oldPath);
      }
    });
  }

  Future<void> _removeObject(String path) async {
    try {
      await _client.storage.from(bucket).remove([path]);
    } catch (_) {
      // Gagal menghapus file lama tidak boleh menggagalkan aksi utama.
    }
  }

  String? _pathFromUrl(String url) {
    const marker = '/object/public/$bucket/';
    final i = url.indexOf(marker);
    if (i == -1) return null;
    return Uri.decodeComponent(
      url.substring(i + marker.length).split('?').first,
    );
  }
}
