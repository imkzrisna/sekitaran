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
  Future<void> sendMessage(Message message) async {
    final user = await _repo.getByUsernameAsync(message.username);

    if (user == null) {
      throw Exception("user not found!");
    }

    await client.from("message").insert({
      "message": message.message,
      "username": message.username,
    });
  }

  @override
  Stream<List<Message>> watchMessages() {
    final controller = StreamController<List<Message>>.broadcast();
    List<Message> messages = [];

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
        return Message(messageText, username);
      }).toList();

      controller.add(messages);
    } catch (e) {
      controller.addError(e);
    }
  }

  @override
  Future<void> deleteMessageAsync(String chatUuid) {
    // TODO: implement deleteMessageAsync
    throw UnimplementedError();
  }

  @override
  Future<Message?> getMessageById(String chatUuid) {
    // TODO: implement getMessageById
    throw UnimplementedError();
  }
}
