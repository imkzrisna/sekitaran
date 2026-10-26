import 'package:flutter/foundation.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/user_profile_repository_interface.dart';
import 'package:sekitaran/features/global_chat/adapter/chat_gateway/chat_gateway_interface.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';

class SupabaseChatGateway implements ChatGatewayInterface {
  final SupabaseClient client = Supabase.instance.client;
  final UserProfileRepositoryInterface _repo;
  RealtimeChannel? _channel;

  new(this._repo);

  @override
  Future<void> dispose() async {
    await _channel?.unsubscribe();
    _channel = null;
  }

  @override
  Future<void> sendMessageAsync(Message message) async {
    final user = await _repo.getByUsernameAsync(message.username);

    if (user == null) {
      throw Exception("user not found!");
    }

    await client.from("message").insert({
      // a bit risky but it's more testable. Hopefully there's no data inconsistency bug occuring
      "id": message.id,
      "message": message.message,
      "username": message.username,
      "created_at": DateTime.now().toString(),
      "user_id": user.userId,
      "avatar_url": message.avatarUrl,
    });
  }

  @override
  Stream<List<Message>> watchMessages() {
    final controller = StreamController<List<Message>>.broadcast();

    _channel = client
        .channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'message',
          callback: (payload) {
            _fetchAndEmitMessages(controller);
          },
        )
        .subscribe();

    // Initial fetch
    _fetchAndEmitMessages(controller);

    return controller.stream;
  }

  Future<void> _fetchAndEmitMessages(
    StreamController<List<Message>> controller,
  ) async {
    try {
      final response = await client
          .from('message')
          .select('*')
          .order('created_at', ascending: true);

      final List<Message> messages = (response as List).map((row) {
        final username = row["username"] as String;
        final messageText = row['message'] as String? ?? '';
        final avatarUrl = row["avatar_url"] as String? ?? "";

        return Message(messageText, username).withAvatarUrl(avatarUrl);
      }).toList();

      controller.add(messages);
    } catch (e) {
      controller.addError(e);
    }
  }

  @override
  Future<void> deleteMessageAsync(String chatUuid) async {
    try {
      await client.from("message").delete().eq("id", chatUuid);
    } catch (e) {
      debugPrint("failed to delete messages!: $e");
    }
  }

  @override
  Future<Message?> getMessageByIdAsync(String chatUuid) async {
    final queriedMessage = await client
        .from("message")
        .select("*")
        .eq("id", chatUuid);

    final row = (queriedMessage as List).firstOrNull;

    if (row == null) {
      return null;
    }

    return Message(
      row["message"],
      row["username"],
    ).withAvatarUrl(row["avatar_url"]);
  }

  @override
  Future<void> editMessageByIdAsync(String chatUuid, Message newMessage) async {
    await client
        .from("message")
        .update({
          "message": newMessage.message,
          "updated_at": DateTime.now().toString(),
        })
        .eq("id", chatUuid);
  }
}
