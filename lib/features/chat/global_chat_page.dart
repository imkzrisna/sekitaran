import 'package:flutter/material.dart';
import 'package:sekitaran/features/auth/entity/user_profile.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/supabase_user_profile_repository.dart';
import 'package:sekitaran/features/chat/widget/owned_chat.dart';
import 'package:sekitaran/features/chat/widget/unowned_chat.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';
import 'package:sekitaran/features/global_chat/chat_service.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/home/user_radial_menu.dart';

/// Halaman Global Chat. Sengaja kosong; isinya menyusul.
class GlobalChatPage extends StatefulWidget {
  const new({super.key});

  @override
  State<StatefulWidget> createState() => _GlobalChatPageState();
}

class _GlobalChatPageState extends State<GlobalChatPage> {
  static const _bg = Color(0xFFF2F9F8);
  static const _green = Color(0xFF103D17);

  late Future<void> _initAsyncFuture;

  late SupabaseUserProfileRepository _userProfile;
  late SupabaseSessionManager _session;
  late ChatService _service;

  late UserProfile? _currentUser;

  final messageController = TextEditingController();

  bool _isLoggedIn() {
    return _session.currentSession != null;
  }

  Future<void> _initAsync() async {
    await _session.signInWithPasswordAsync(
      email: "124240154@student.upnyk.ac.id",
      password: "sayakurangtawu3",
    );

    if (!_isLoggedIn()) return;

    _currentUser = await _userProfile.getByIdAsync(
      _session.currentSession!.userId,
    );
  }

  @override
  void initState() {
    super.initState();
    _session = SupabaseSessionManager();
    _userProfile = SupabaseUserProfileRepository();
    _service = ChatService.createSupabaseImplementation(_session);

    _initAsyncFuture = _initAsync();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: _bg,
          body: FutureBuilder(
            future: _initAsyncFuture,
            builder: (context, snapshot) {
              final chatlist = _service.chatList;

              if (chatlist == null) {
                return SizedBox.expand(
                  child: Center(child: Text("you are not logged in!")),
                );
              }

              return StreamBuilder(
                stream: chatlist,
                builder: (context, messageSnapshot) {
                  if (_session.currentSession == null) {
                    return SizedBox.expand(
                      child: Center(child: Text("you are not logged in!")),
                    );
                  }

                  final messages = messageSnapshot.data!;

                  return SizedBox.expand(
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Column(
                        children: [
                          messages.isEmpty || messageSnapshot.data == null
                              ? Center(child: Text("belum ada pesan!"))
                              : Expanded(
                                  child: ListView.builder(
                                    itemCount: messages.length,
                                    itemBuilder: (context, index) {
                                      final message = messages[index];

                                      return Padding(
                                        padding: EdgeInsetsGeometry.symmetric(
                                          horizontal: 0,
                                          vertical: 5,
                                        ),
                                        child: Align(
                                          alignment:
                                              _currentUser!.username ==
                                                  message.username
                                              ? Alignment.centerRight
                                              : Alignment.centerLeft,
                                          child:
                                              _currentUser!.username ==
                                                  message.username
                                              ? OwnedChat(message: message)
                                              : UnownedChat(message: message),
                                        ),
                                      );
                                    },
                                  ),
                                ),

                          Row(
                            spacing: 5,
                            children: [
                              Expanded(
                                child: TextField(
                                  keyboardType: TextInputType.multiline,
                                  maxLines: null,
                                  controller: messageController,
                                  decoration: InputDecoration(
                                    hint: Text("pesan"),
                                    border: OutlineInputBorder(
                                      borderSide: BorderSide(width: 2),
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(25 / 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    shape: const CircleBorder(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  onPressed: () async {
                                    await _service.sendChatAsync(
                                      Message(
                                        messageController.text,
                                        _currentUser!.username,
                                      ).withAvatarUrl(_currentUser!.avatarUrl),
                                    );
                                  },
                                  child: Icon(Icons.send),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        UserRadialMenu(current: RadialNavItem.chat),
      ],
    );
  }
}
