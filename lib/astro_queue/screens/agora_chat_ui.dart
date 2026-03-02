import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

class AgoraChatScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final ApiService chatService;
  final List<Map<String, dynamic>> initialMessages;
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

  String? _currentUid;
  String? _peerUid;

  static const String _handlerKey = "AGORA_CHAT_CONN_HANDLER";

  @override
  void initState() {
    super.initState();
    _resolveUsersAndInit();
  }

  // ─── STEP 0: Resolve IDs from SharedPreferences ────────────────────────────
  Future<void> _resolveUsersAndInit() async {
    try {
      final user = await UserModel.getLoggedInUser();

      if (user == null) {
        _setError("No logged-in user found. Please log in again.");
        return;
      }

      _currentUid = user.agoraUid;

      if (_currentUid == null || _currentUid!.isEmpty) {
        _setError("User ID missing from stored session.\n$user");
        return;
      }

      final s = widget.session;
      _peerUid = widget.isCustomer
          ? s.consultant?.id?.toString()
          : s.customer?.id?.toString();

      _log(
          "👤 [AgoraChat] Me   → uid: $_currentUid | name: ${user.name} | role: ${user.roleEnum.name}");
      _log("👤 [AgoraChat] Peer → uid: $_peerUid");

      if (_peerUid == null || _peerUid!.isEmpty) {
        _setError(
          "Could not determine peer ID from session.\nRaw: ${s.toJson()}",
        );
        return;
      }

      await _initializeChat();
    } catch (e) {
      _log("❌ [AgoraChat] User resolve error: $e");
      _setError("Failed to load user: $e");
    }
  }

  void _setError(String msg) {
    if (mounted)
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
  }

  Future<String> _fetchToken() async {
    _log("🌐 [AgoraChat] Fetching token for userId: $_currentUid");
    final token = await widget.chatService.getAgoraChatToken(_currentUid!);
    _log("✅ [AgoraChat] Token received: $token");
    if (token.isEmpty) throw Exception("Backend returned empty token");
    return "007eJxTYDDTMH1U8OiBr5VkeuMzET77DRz97DrTznxmtk/YmK9blaXAYJpkmmKYYpKYapaaYmJmaGFhmpxmlpJoZmJskGZqZGC8z39pZkMgI4N5pzcjIwMrAyMQgvgqDKnm5gapiZYGuoZmhia6hoZphrqJ5kmGumlp5gZJKSZAOcNkAE02JJw=";
  }

  Future<void> _initializeChat() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
        });
      }

      const String hardcodedToken =
          "007eJxTYDDTMH1U8OiBr5VkeuMzET77DRz97DrTznxmtk/YmK9blaXAYJpkmmKYYpKYapaaYmJmaGFhmpxmlpJoZmJskGZqZGC8z39pZkMgI4N5pzcjIwMrAyMQgvgqDKnm5gapiZYGuoZmhia6hoZphrqJ5kmGumlp5gZJKSZAOcNkAE02JJw=";

      // 1️⃣ Init SDK
      await ChatUIKit.instance.init(
        options: ChatOptions(
          appKey: "6110025533#1666962", // YOUR CHAT APP KEY
          autoLogin: false,
        ),
      );

      _log("✅ [AgoraChat] SDK initialised");

      // 2️⃣ Logout old session if exists
      final loggedInUser = ChatUIKit.instance.currentUserId;
      if (loggedInUser != null) {
        await ChatUIKit.instance.logout();
        _log("🔄 Logged out stale session: $loggedInUser");
      }

      // 3️⃣ Add connection handler
      ChatClient.getInstance.addConnectionEventHandler(
        _handlerKey,
        ConnectionEventHandler(
          onConnected: () {
            _log("🔗 TCP connected — loading history");
            _loadHistory();
          },
          onDisconnected: () => _log("🔌 TCP disconnected"),
          onTokenWillExpire: () async {
            _log("⚠️ Token will expire (hardcoded token mode)");
          },
          onTokenDidExpire: () {
            _log("🔴 Token expired — app restart required in hardcode mode");
          },
        ),
      );

      // 4️⃣ Login with HARDCODED token
      await ChatUIKit.instance.loginWithToken(
        userId: _currentUid!,
        token: hardcodedToken,
      );

      _log("✅ Logged in as $_currentUid");

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      _log("❌ Init/Login error: $e");
      _setError(e.toString());
    }
  }

  // ─── HISTORY (called from onConnected — TCP guaranteed live) ───────────────
  Future<void> _loadHistory() async {
    try {
      _log("📜 [AgoraChat] Fetching history with peer: $_peerUid");
      final cursor =
          await ChatClient.getInstance.chatManager.fetchHistoryMessages(
        conversationId: _peerUid!,
        type: ChatConversationType.Chat,
        startMsgId: "",
        pageSize: 50,
      );
      _log("📜 [AgoraChat] ${cursor.data.length} messages loaded");
      for (final msg in cursor.data) {
        final body = msg.body;
        final content =
            body is ChatTextMessageBody ? body.content : body.type.name;
        _log("  🗨 [${msg.serverTime}] ${msg.from} → ${msg.to}: $content");
      }
    } catch (e) {
      _log("⚠️ [AgoraChat] History error: $e");
    }
  }

  @override
  void dispose() {
    try {
      ChatClient.getInstance.removeConnectionEventHandler(_handlerKey);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    return widget.isFullScreen
        ? _buildFullScreen(body)
        : _buildBottomSheet(body);
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF075E54)),
            SizedBox(height: 16),
            Text("Connecting to chat…",
                style: TextStyle(color: Colors.white70, fontSize: 15)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[300], size: 64),
              const SizedBox(height: 16),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _resolveUsersAndInit,
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

    // MessagesView reads from Agora SDK's internal store
    // History populated by fetchHistoryMessages in onConnected
    return MessagesView(
      profile: ChatUIKitProfile.contact(id: _peerUid!),
    );
  }

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
                  color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
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
                  const Text("online",
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              onPressed: () => _log("📹 Video call tapped")),
          IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: () => _log("📞 Voice call tapped")),
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
              color: Colors.black26, blurRadius: 20, offset: Offset(0, -2))
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
                        shape: BoxShape.circle),
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
                        const Text("Live Chat",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 18)),
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
                      onPressed: () => _log("📹 Video call tapped")),
                  IconButton(
                      icon: const Icon(Icons.call, color: Colors.white),
                      onPressed: () => _log("📞 Voice call tapped")),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle),
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
