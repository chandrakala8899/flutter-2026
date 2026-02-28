import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/material.dart';

class AgoraChatScreen extends StatefulWidget {
  final bool isCustomer;
  final String currentUserId;
  final String peerUserId;
  final bool isFullScreen;

  const AgoraChatScreen({
    super.key,
    required this.isCustomer,
    required this.currentUserId,
    required this.peerUserId,
    this.isFullScreen = false,
  });

  @override
  State<AgoraChatScreen> createState() => _AgoraChatScreenState();
}

class _AgoraChatScreenState extends State<AgoraChatScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);

      await ChatUIKit.instance.init(
        options: ChatOptions(
          appKey: "6110025533#1665686",
          autoLogin: false,
        ),
      );

      await ChatUIKit.instance.loginWithPassword(
        userId: widget.currentUserId,
        password: "123456",
      );

      print("✅ Agora Chat Login Success");
    } catch (e) {
      print("❌ Chat Init/Login Error → $e");
      setState(() => _errorMessage = "Chat login failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatBody = _isLoading
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF075E54)),
                SizedBox(height: 16),
                Text("Connecting to chat...",
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          )
        : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red[300], size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _initializeChat,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF075E54),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              )
            : MessagesView(
                profile: ChatUIKitProfile.contact(id: widget.peerUserId),
              );

    if (widget.isFullScreen) {
      // 🔥 WHATSAPP FULL SCREEN CHAT
      return Scaffold(
        backgroundColor: const Color(0xFF075E54), // WhatsApp Green
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
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      "online",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white),
              onPressed: () => print("Video call"),
            ),
            IconButton(
              icon: const Icon(Icons.call, color: Colors.white),
              onPressed: () => print("Voice call"),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF075E54),
                Color(0xFF128C7E),
                Colors.white,
              ],
              stops: [0.0, 0.1, 0.15],
            ),
          ),
          child: chatBody,
        ),
      );
    } else {
      // 🔥 WHATSAPP BOTTOM SHEET (Call overlay)
      return Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF075E54),
              Color(0xFF128C7E),
              Colors.white,
            ],
            stops: [0.0, 0.1, 0.15],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 20,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          children: [
            // 🔥 WHATSAPP GRADIENT HEADER
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
                          Text(
                            "Live Chat",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          Text(
                            widget.isCustomer ? "Practitioner" : "Customer",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: chatBody),
          ],
        ),
      );
    }
  }
}
