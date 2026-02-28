import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

class AgoraChatScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final ApiService chatService;
  final List<Map<String, dynamic>>
      initialMessages; // always empty – SDK handles history
  final bool isFullScreen;

  const AgoraChatScreen({
    super.key,
    required this.session,
    required this.isCustomer,
    required this.chatService,
    required this.initialMessages,
    this.isFullScreen = false,
  });

  @override
  State<AgoraChatScreen> createState() => _AgoraChatScreenState();
}

class _AgoraChatScreenState extends State<AgoraChatScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // Customer     → Agora userId "1", peers with "2"
  // Practitioner → Agora userId "2", peers with "1"
  late final String _currentUid;
  late final String _peerUid;

  @override
  void initState() {
    super.initState();
    _currentUid = widget.isCustomer ? "1" : "2";
    _peerUid = widget.isCustomer ? "2" : "1";
    _initializeChat();
  }

  // ─── STEP 1: Init SDK ──────────────────────────────────────────────────────
  // ─── STEP 2: Check if already logged in ───────────────────────────────────
  // ─── STEP 3: Logout previous user if needed ────────────────────────────────
  // ─── STEP 4: Fetch token from backend → print it ──────────────────────────
  // ─── STEP 5: Login with token ─────────────────────────────────────────────
  // ─── STEP 6: Fetch history from Agora SDK → print each message ────────────
  // MessagesView then shows everything automatically.
  Future<void> _initializeChat() async {
    try {
      if (mounted)
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });

      // 1️⃣ Init Agora IM SDK
      await ChatUIKit.instance.init(
        options: ChatOptions(
          appKey: "6110025533#1665686",
          autoLogin: false,
        ),
      );
      _log("✅ [AgoraChat] SDK initialised");

      final loggedInUser = ChatUIKit.instance.currentUserId;

      // 2️⃣ Already logged in as correct user → just load history
      if (loggedInUser == _currentUid) {
        _log("✅ [AgoraChat] Already logged in as: $_currentUid");
        await _loadHistory();
        return;
      }

      // 3️⃣ Different user logged in → logout first
      if (loggedInUser != null && loggedInUser != _currentUid) {
        await ChatUIKit.instance.logout();
        _log("🔄 [AgoraChat] Logged out previous user: $loggedInUser");
      }

      // 4️⃣ Fetch Agora IM token from backend and PRINT it
      final token = await widget.chatService.getAgoraChatToken(_currentUid);
      _log("🟢 [AgoraChat] Token received for [$_currentUid]: $token");

      if (token.isEmpty) throw Exception("Backend returned an empty token");

      // 5️⃣ Login with token
      await ChatUIKit.instance.loginWithToken(
        userId: _currentUid,
        token: token,
      );
      _log("✅ [AgoraChat] Login success – userId: $_currentUid");

      // 6️⃣ Load history from Agora SDK
      await _loadHistory();
    } catch (e) {
      _log("❌ [AgoraChat] Init/Login error: $e");
      if (mounted) setState(() => _errorMessage = "Chat login failed:\n$e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── LOAD HISTORY FROM AGORA SDK (not backend, not websocket) ──────────────
  Future<void> _loadHistory() async {
    try {
      _log("📜 [AgoraChat] Fetching history for conversation with: $_peerUid");

      final cursor =
          await ChatClient.getInstance.chatManager.fetchHistoryMessages(
        conversationId: _peerUid,
        type: ChatConversationType.Chat,
        startMsgId: "", // empty = fetch from latest
        pageSize: 50,
      );

      _log(
          "📜 [AgoraChat] ${cursor.data.length} messages loaded from Agora SDK");

      for (final msg in cursor.data) {
        final body = msg.body;
        final content =
            body is ChatTextMessageBody ? body.content : body.type.name;
        _log("  🗨 [${msg.serverTime}] ${msg.from} → ${msg.to}: $content");
      }

      // MessagesView reads from the SDK's internal conversation store,
      // which fetchHistoryMessages has now populated — no setState needed.
    } catch (e) {
      // Non-fatal: MessagesView still works, just won't show old messages
      _log("⚠️ [AgoraChat] History fetch failed (non-fatal): $e");
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    return widget.isFullScreen
        ? _buildFullScreen(body)
        : _buildBottomSheet(body);
  }

  Widget _buildBody() {
    // Loading state while SDK inits + token fetch + login
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF075E54)),
            SizedBox(height: 16),
            Text(
              "Connecting to chat…",
              style: TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // Error state with retry
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeChat,
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF075E54),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ Agora UIKit MessagesView
    // Reads from the SDK's internal store (populated by fetchHistoryMessages)
    // and receives new messages in real-time automatically.
    return MessagesView(
      profile: ChatUIKitProfile.contact(id: _peerUid),
    );
  }

  // ── Full-screen Scaffold ───────────────────────────────────────────────────
  Widget _buildFullScreen(Widget body) {
    return Scaffold(
      backgroundColor: const Color(0xFF075E54),
      appBar: AppBar(
        backgroundColor: const Color(0xFF075E54),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.isCustomer ? Icons.person : Icons.support_agent,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isCustomer ? "Practitioner" : "Customer",
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16),
                  ),
                  const Text(
                    "online",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () => _log("📹 Video call tapped"),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () => _log("📞 Voice call tapped"),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF075E54), Color(0xFF128C7E), Colors.white],
            stops: [0.0, 0.1, 0.15],
          ),
        ),
        child: body,
      ),
    );
  }

  // ── Bottom-sheet mode ──────────────────────────────────────────────────────
  Widget _buildBottomSheet(Widget body) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF075E54), Color(0xFF128C7E), Colors.white],
          stops: [0.0, 0.1, 0.15],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 20, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: const BoxDecoration(
              color: Color(0xFF075E54),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.isCustomer ? Icons.person : Icons.support_agent,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Live Chat",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18),
                        ),
                        Text(
                          widget.isCustomer ? "Practitioner" : "Customer",
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam, color: Colors.white),
                    onPressed: () => _log("📹 Video call tapped"),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.white),
                    onPressed: () => _log("📞 Voice call tapped"),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
