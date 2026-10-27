import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/auth/auth_service.dart';
import 'package:sekitaran/features/auth/entity/user_profile.dart';
import 'package:sekitaran/features/auth/login_page.dart';
import 'package:sekitaran/features/auth/persistence/user_profile_repository/supabase_user_profile_repository.dart';
import 'package:sekitaran/features/chat/widget/chat_bubble.dart'
    show ChatColors;
import 'package:sekitaran/features/chat/widget/chat_message_list.dart';
import 'package:sekitaran/features/global_chat/adapter/session_manager/supabase_session_manager.dart';
import 'package:sekitaran/features/global_chat/chat_service.dart';
import 'package:sekitaran/features/global_chat/entity/message.dart';
import 'package:sekitaran/features/global_chat/status/send_chat_status.dart';
import 'package:sekitaran/features/home/radial_nav_menu.dart';
import 'package:sekitaran/features/home/user_radial_menu.dart';

/// Halaman Global Chat untuk Regular User.
class GlobalChatPage extends StatefulWidget {
  const new({super.key});

  @override
  State<StatefulWidget> createState() => _GlobalChatPageState();
}

class _GlobalChatPageState extends State<GlobalChatPage> {
  // Posisi tombol menu melingkar. Samakan dengan radial_nav_menu.dart.
  static const _fabSize = 58.0;
  static const _fabRight = 20.0;
  static const _fabBottom = 40.0;
  static const _sendSize = 46.0;

  late Future<void> _initAsyncFuture;

  late SupabaseUserProfileRepository _userProfile;
  late SupabaseSessionManager _session;
  late ChatService _service;

  UserProfile? _currentUser;
  Stream<List<Message>>? _messages; // dibuat satu kali, bukan tiap rebuild
  bool _roleBlocked = false;
  bool _sending = false;

  final messageController = TextEditingController();

  bool _isLoggedIn() {
    return _session.currentSession != null;
  }

  Future<void> _initAsync() async {
    if (!_isLoggedIn()) return;

    final profile = await AuthService.instance.fetchMyProfile();
    final role = profile?['role'];
    if (role == null || role == 'business') {
      _roleBlocked = true;
      return;
    }

    _currentUser = await _userProfile.getByIdAsync(
      _session.currentSession!.userId,
    );
    if (_currentUser != null) {
      _messages = _service.chatList;
    }
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
  void dispose() {
    messageController.dispose();
    _service.dispose(); // tutup channel realtime
    super.dispose();
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _send() async {
    final user = _currentUser;
    final text = messageController.text.trim();
    if (user == null || text.isEmpty || _sending) return;
    _sending = true;
    messageController.clear();
    try {
      final status = await _service.sendChatAsync(
        Message(text, user.username).withAvatarUrl(user.avatarUrl),
      );
      if (status != SendChatStatus.success && mounted) {
        messageController.text = text;
        _snack('Pesan gagal dikirim. Silakan coba lagi.');
      }
    } catch (_) {
      if (mounted) {
        messageController.text = text;
        _snack('Pesan gagal dikirim. Periksa koneksi internet.');
      }
    } finally {
      _sending = false;
    }
  }

  // ---------- Tampilan ----------

  TextStyle _hint() =>
      GoogleFonts.poppins(fontSize: 13, color: ChatColors.grey);

  Widget _centered(IconData icon, String text, {Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 30, color: ChatColors.grey),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: _hint()),
            ?action,
          ],
        ),
      ),
    );
  }

  Widget _restricted() => _centered(
    Icons.lock_outline,
    'Global chat is only available for regular users.',
  );

  Widget _loginRequired() => _centered(
    Icons.lock_outline,
    'Please log in to join the chat.',
    action: TextButton(
      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      ),
      child: Text(
        'Go to login',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: ChatColors.green,
        ),
      ),
    ),
  );

  Widget _loading() =>
      const Center(child: CircularProgressIndicator(color: ChatColors.green));

  Widget _header({required bool keyboardOpen}) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(28, keyboardOpen ? 20 : 56, 28, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Text(
                'Global Chat',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: ChatColors.green,
                ),
              ),
              Positioned(
                top: -14,
                right: -22,
                child: Text(
                  '*',
                  style: GoogleFonts.poppins(
                    fontSize: 44,
                    fontWeight: FontWeight.w500,
                    color: ChatColors.green,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(bottom: 3),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ChatColors.accent, width: 1.5),
              ),
            ),
            child: Text(
              'Connect with other Sekitaran users',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: ChatColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => _centered(
    Icons.forum_outlined,
    'Belum ada pesan. Jadilah yang pertama menyapa!',
  );

  Widget _sendButton() {
    return ListenableBuilder(
      listenable: messageController,
      builder: (_, _) {
        final can = messageController.text.trim().isNotEmpty;
        return Material(
          color: can ? ChatColors.green : ChatColors.border,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: can ? _send : null,
            child: const SizedBox(
              width: _sendSize,
              height: _sendSize,
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        );
      },
    );
  }

  Widget _inputBar({required bool keyboardOpen, required double safeBottom}) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide(color: c, width: 1.2),
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        // Saat keyboard tertutup, sisakan ruang untuk tombol menu melingkar.
        keyboardOpen ? 16 : _fabRight + _fabSize + 12,
        keyboardOpen
            ? 10
            : _fabBottom + (_fabSize - _sendSize) / 2 + safeBottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: messageController,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 4,
              style: GoogleFonts.poppins(fontSize: 14, color: ChatColors.ink),
              decoration: InputDecoration(
                hintText: 'Tulis pesan...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w300,
                  color: const Color(0xFF9A9A9A),
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                enabledBorder: border(ChatColors.border),
                focusedBorder: border(ChatColors.green),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _sendButton(),
        ],
      ),
    );
  }

  Widget _ready(
    List<Message> messages, {
    required bool keyboardOpen,
    required double safeBottom,
  }) {
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? _empty()
              : ChatMessageList(
                  messages: messages,
                  currentUsername: _currentUser!.username,
                ),
        ),
        _inputBar(keyboardOpen: keyboardOpen, safeBottom: safeBottom),
      ],
    );
  }

  Widget _body({required bool keyboardOpen, required double safeBottom}) {
    return FutureBuilder(
      future: _initAsyncFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return _loading();
        if (_roleBlocked) return _restricted();
        final stream = _messages;
        if (stream == null || _currentUser == null) return _loginRequired();

        return StreamBuilder<List<Message>>(
          stream: stream,
          builder: (context, snap) {
            if (_session.currentSession == null) return _loginRequired();
            if (snap.hasError) {
              return _centered(
                Icons.cloud_off_outlined,
                'Gagal memuat pesan. Buka ulang halaman ini.',
              );
            }
            final messages = snap.data;
            if (messages == null) return _loading();
            return _ready(
              messages,
              keyboardOpen: keyboardOpen,
              safeBottom: safeBottom,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: ChatColors.bg,
          body: SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(keyboardOpen: keyboardOpen),
                    Expanded(
                      child: _body(
                        keyboardOpen: keyboardOpen,
                        safeBottom: safeBottom,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const UserRadialMenu(current: RadialNavItem.chat),
      ],
    );
  }
}
