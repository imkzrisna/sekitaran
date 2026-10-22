import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/supabase_user_profile_repository.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/user_profile_repository_interface.dart';
import 'package:sekitaran/features/global_chat/adapter/chat_gateway/chat_gateway_interface.dart';
import 'package:sekitaran/features/global_chat/adapter/chat_gateway/supabase_chat_gateway.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/session_manager_interface.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';
import 'package:sekitaran/features/global_chat/status/delete_status.dart';
import 'package:sekitaran/features/global_chat/status/edit_message_status.dart';

class ChatService {
  ChatService(this._gateway, this._session, this._profiles);

  final ChatGatewayInterface _gateway;
  final SessionManagerInterface _session;
  final UserProfileRepositoryInterface _profiles;

  Stream<List<Message>>? get chatList =>
      _session.currentSession != null ? _gateway.watchMessages() : null;

  Future<void> sendChatAsync(Message message) async {
    if (_session.currentSession == null) return;

    _gateway.sendMessageAsync(message);
  }

  Future<void> dispose() => _gateway.dispose();

  Future<DeleteStatus> deleteChatById(String id) async {
    if (_session.currentSession == null) {
      return DeleteStatus.userIsNotAuthenticated;
    }

    final currentUser = await _profiles.getByIdAsync(
      _session.currentSession?.userId ?? "",
    );

    if (currentUser == null) {
      return DeleteStatus.userIsNotAuthenticated;
    }

    if (chatList == null) {
      return DeleteStatus.emptyChat;
    }

    final message = await _gateway.getMessageByIdAsync(id);

    if (message == null) {
      return DeleteStatus.messageNotFound;
    }

    if (message.username != currentUser.username) {
      return DeleteStatus.userDoesNotOwnTheMessage;
    }

    await _gateway.deleteMessageAsync(id);

    return DeleteStatus.success;
  }

  static ChatService createSupabaseImplementation(
    SupabaseSessionManager session,
  ) {
    final repo = SupabaseUserProfileRepository();
    final gateway = SupabaseChatGateway(repo);

    return ChatService(gateway, session, repo);
  }

  Future<EditMessageStatus> editMessageAsync(
    String id,
    String newMessage,
  ) async {
    if (_session.currentSession == null) return EditMessageStatus.notAuthorized;

    final currentUser = await _profiles.getByIdAsync(
      _session.currentSession!.userId,
    );

    if (currentUser == null) {
      return EditMessageStatus.userNotFound;
    }

    final targetMessage = await _gateway.getMessageByIdAsync(id);

    if (targetMessage == null) {
      return EditMessageStatus.messageNotFound;
    }

    if (currentUser!.username != targetMessage!.username) {
      return EditMessageStatus.userDoesNotOwnTheMessage;
    }

    await _gateway.editMessageByIdAsync(
      id,
      Message(newMessage, currentUser.username).withId(id),
    );

    return EditMessageStatus.success;
  }
}
