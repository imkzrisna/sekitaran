import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/supabase_user_profile_repository.dart';
import 'package:sekitaran/features/global_chat/adapter/chat_gateway/supabase_chat_gateway.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';
import 'package:sekitaran/features/global_chat/chat_service.dart';
import 'package:sekitaran/features/global_chat/vo/auth_session.dart';
import 'package:sekitaran/features/global_chat/vo/message.dart';

class ChatScratchpad extends StatefulWidget {
  const ChatScratchpad({super.key});

  @override
  State<ChatScratchpad> createState() => _ChatScratchpadState();
}

class _ChatScratchpadState extends State<ChatScratchpad> {
  late final SupabaseUserProfileRepository _userRepo;
  late final SupabaseChatGateway _gateway;
  late final ChatService _service;
  late final SupabaseSessionManager _session;

  @override
  void initState() {
    super.initState();
    _userRepo = SupabaseUserProfileRepository();
    _session = SupabaseSessionManager();
    _gateway = SupabaseChatGateway(_userRepo);
    _service = ChatService(_gateway, _session);
    
    // Fire-and-forget sign in - StreamBuilder will rebuild when session is available
    // _session.signInWithPassword(
    //   email: dotenv.env["INTEGRATION_TEST_EMAIL"]!, 
    //   password: dotenv.env["INTEGRATION_TEST_PASSWORD"]!,
    // );
    _session.signInWithPassword(email: "example@gmail.com", password: "password");
    _service.sendChat(Message("Hello again", "anotherUser"));
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Global Chat Scratchpad')),
      body: StreamBuilder<AuthSession?>(
        stream: _session.sessionChanges,
        initialData: _session.currentSession,
        builder: (context, sessionSnapshot) {
          final session = sessionSnapshot.data;
          
          if (session == null) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final chatListStream = _service.chatList;
          
          return StreamBuilder<List<Message>>(
            stream: chatListStream,
            builder: (context, messageSnapshot) {
              if (messageSnapshot.hasError) {
                return Center(child: Text('Error: ${messageSnapshot.error}'));
              }
              if (!messageSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final messages = messageSnapshot.data!;
              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${message.username}: ${message.message}'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
