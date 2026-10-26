// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';
import 'package:sekitaran/features/global_chat/chat_service.dart';
import 'package:sekitaran/features/global_chat/vo/auth_session.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';
import 'package:uuid/uuid.dart';

class ChatScratchpad extends StatefulWidget {
  const ChatScratchpad({super.key});

  @override
  State<ChatScratchpad> createState() => _ChatScratchpadState();
}

class _ChatScratchpadState extends State<ChatScratchpad> {
  late final ChatService _service;
  late final SupabaseSessionManager _session;

  late final Future<void> _initAsyncFuture;

  Future<void> _initAsync() async {
    await _session.signInWithPasswordAsync(
      email: "example@gmail.com",
      password: "password",
    );

    final id = Uuid().v4();
    final sendChatStatus = await _service.sendChatAsync(
      Message(
        "How are you?",
        "anotherUser",
      ).withId(id).withAvatarUrl("somewhere/in/the/database.jpg"),
    );

    final status = await _service.editMessageAsync(id, "I'm doing great!");

    print("update status: $status");
    print("send chat status: $sendChatStatus");
  }

  @override
  void initState() {
    super.initState();
    _session = SupabaseSessionManager();
    _service = ChatService.createSupabaseImplementation(_session);

    // Fire-and-forget sign in - StreamBuilder will rebuild when session is available
    // _session.signInWithPassword(
    //   email: dotenv.env["INTEGRATION_TEST_EMAIL"]!,
    //   password: dotenv.env["INTEGRATION_TEST_PASSWORD"]!,
    // );
    _initAsyncFuture = _initAsync();
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
      body: FutureBuilder(
        future: _initAsyncFuture,
        builder: (context, snapshot) {
          if (snapshot.error != null) {
            print("an errro occured: ${snapshot.error}");
          }

          return StreamBuilder<AuthSession?>(
            stream: _session.sessionChanges,
            initialData: _session.currentSession,
            builder: (context, sessionSnapshot) {
              final session = sessionSnapshot.data;

              // mengecek apakah user sudah login
              if (session == null) {
                return const Center(child: CircularProgressIndicator());
              }

              final chatListStream = _service.chatList;

              return StreamBuilder<List<Message>>(
                stream: chatListStream,
                builder: (context, messageSnapshot) {
                  if (messageSnapshot.hasError) {
                    return Center(
                      child: Text('Error: ${messageSnapshot.error}'),
                    );
                  }

                  // menampilkan loading bila chat belum ke load
                  if (!messageSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = messageSnapshot.data!;

                  // belum ada yang ngechat
                  if (messages.isEmpty) {
                    return const Center(child: Text('No messages yet'));
                  }

                  // penampilan pesan
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${message.avatarUrl}: ${message.username}: ${message.message}',
                        ),
                      );
                    },
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
