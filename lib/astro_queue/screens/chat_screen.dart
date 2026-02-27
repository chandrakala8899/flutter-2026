import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/services/chat_service.dart';
import 'package:flutter_learning/colors.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final ChatService chatService;
  final List<Map<String, dynamic>> initialMessages;

  const ChatScreen({
    super.key,
    required this.session,
    required this.isCustomer,
    required this.chatService,
    required this.initialMessages,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  double _soundLevel = 0.0;
  String _liveText = "";
  List<Map<String, dynamic>> messages = [];
  bool _isSending = false;
  bool _isLoadingHistory = false;

  // 🔥 FIXED: Better duplicate prevention - separate tracking
  Set<String> _localSentMessages = {};
  Set<String> _serverMessages = {};

  static const int _uidCustomer = 1;
  static const int _uidPractitioner = 2;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    _speech = stt.SpeechToText();
    _initSpeech();

    // 🔥 FIXED: Only accept server messages that don't match local ones
    // In initState() onMessageReceived callback - Line ~70
    widget.chatService.onMessageReceived = (data) {
      final messageId = data["id"]?.toString();
      final text = data["message"]?.toString().trim() ?? "";
      final senderId = data["senderId"]?.toString() ?? "";

      // Skip if it's a duplicate of our local message
      if (_localSentMessages.contains(text) ||
          (messageId != null && _serverMessages.contains(messageId))) {
        return;
      }

      if (mounted) {
        setState(() {
          messages.insert(0, _processMessage(data));
          // 🔥 FIXED: Safe null check
          if (messageId != null && messageId.isNotEmpty) {
            _serverMessages.add(messageId);
          }
        });
      }
    };
  }

  Future<void> _loadChatHistory() async {
    if (_isLoadingHistory || widget.session.sessionId == null) return;

    _isLoadingHistory = true;
    setState(() => messages.clear());
    _localSentMessages.clear();
    _serverMessages.clear();

    try {
      final history = await _getChatHistory();
      if (mounted) {
        setState(() {
          messages = history.map((m) => _processMessage(m)).toList();
          // Track server messages from history
          for (var msg in history) {
            final id = msg["id"]?.toString();
            if (id != null && id.isNotEmpty) {
              _serverMessages.add(id);
            }
          }
        });
      }
    } catch (e) {
      print("History load error: $e");
      if (mounted) {
        setState(() {
          messages = widget.initialMessages.map(_processMessage).toList();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getChatHistory() async {
    if (widget.session.sessionId == null) return [];

    try {
      final response = await http.get(
        Uri.parse(
            "http://localhost:16679/api/chat/${widget.session.sessionId}"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data
            .map((msg) => {
                  "id": msg["id"]?.toString(),
                  "senderName": msg["senderName"] ?? "Unknown",
                  "message": msg["message"] ?? "",
                  "sentAt": msg["sentAt"] ??
                      msg["createdAt"] ??
                      msg["timestamp"] ??
                      DateTime.now().toIso8601String(),
                  "senderId":
                      msg["senderId"] ?? (msg["senderName"] == "You" ? 1 : 2),
                })
            .toList()
            .reversed
            .toList();
      }
    } catch (e) {
      print("API Error: $e");
    }
    return [];
  }

  Map<String, dynamic> _processMessage(Map<String, dynamic> data) {
    DateTime sentAt = DateTime.now();

    try {
      String? sentAtStr = data["sentAt"]?.toString()?.trim() ??
          data["createdAt"]?.toString()?.trim() ??
          data["timestamp"]?.toString()?.trim();

      if (sentAtStr != null && sentAtStr.isNotEmpty && sentAtStr != "null") {
        sentAtStr =
            sentAtStr.replaceAll('T', ' ').replaceAll('Z', '').split('.')[0];
        final parsed = DateTime.tryParse(sentAtStr);
        if (parsed != null) {
          sentAt = parsed.toLocal();
        }
      }
    } catch (e) {
      sentAt = DateTime.now();
    }

    final senderId = data["senderId"] ?? 0;
    final myId = widget.isCustomer ? _uidCustomer : _uidPractitioner;

    return {
      "id": data["id"]?.toString() ??
          "local_${DateTime.now().millisecondsSinceEpoch}",
      "sender": data["senderName"]?.toString() ?? "Unknown",
      "text": data["message"]?.toString() ?? "",
      "sentAt": sentAt,
      "time": _formatMessageTime(sentAt), // 🔥 EVERY MESSAGE HAS PROPER TIME
      "dateHeader": _getDateHeader(sentAt),
      "isMe": senderId == myId,
    };
  }

  String _formatMessageTime(DateTime time) {
    try {
      final hour = time.hour % 12;
      final displayHour = hour == 0 ? 12 : hour;
      final minutes = time.minute.toString().padLeft(2, '0');
      final period = time.hour >= 12 ? 'PM' : 'AM';
      return '${displayHour.toString().padLeft(2, '0')}:$minutes $period';
    } catch (e) {
      return DateTime.now().toString().substring(11, 16);
    }
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay.isAtSameMomentAs(today)) return "Today";
    if (msgDay.isAtSameMomentAs(yesterday)) return "Yesterday";

    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec"
    ];
    return "${date.day} ${months[date.month - 1]}";
  }

  Future<void> _initSpeech() async {
    try {
      await Permission.microphone.request();
      await _speech.initialize();
    } catch (e) {}
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    try {
      if (!await _speech.initialize()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone not available")),
          );
        }
        return;
      }
      setState(() {
        _isListening = true;
        _liveText = "";
        _soundLevel = 0.0;
      });
      _speech.listen(
        onResult: (result) =>
            setState(() => _liveText = result.recognizedWords),
        onSoundLevelChange: (level) => setState(() => _soundLevel = level),
        partialResults: true,
      );
    } catch (e) {}
  }

  void _stopListening() {
    try {
      _speech.stop();
    } catch (e) {}
    setState(() => _isListening = false);

    final text = _liveText.trim();
    if (text.isNotEmpty && !_isSending) {
      _sendVoiceMessage(text);
    }
    _liveText = "";
  }

  // 🔥 FIXED: NO DUPLICATES - Track local messages separately
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    // 🔥 Check if we already sent this exact message
    if (_localSentMessages.contains(text)) return;

    _isSending = true;

    // Add local message immediately with proper time
    _addLocalMessage(text);
    _localSentMessages.add(text); // Track locally sent message

    // Send to server (server echo will be filtered out)
    widget.chatService.sendMessage(
      sessionId: widget.session.sessionId!,
      senderId: widget.isCustomer ? _uidCustomer : _uidPractitioner,
      message: text,
    );

    _controller.clear();
    await Future.delayed(const Duration(milliseconds: 1200));
    _isSending = false;
  }

  void _sendVoiceMessage(String text) {
    if (_isSending || _localSentMessages.contains(text)) return;

    _addLocalMessage(text);
    _localSentMessages.add(text);

    widget.chatService.sendMessage(
      sessionId: widget.session.sessionId!,
      senderId: widget.isCustomer ? _uidCustomer : _uidPractitioner,
      message: text,
    );
  }

  void _addLocalMessage(String text) {
    final now = DateTime.now();
    setState(() {
      messages.insert(0, {
        "id": "local_${now.millisecondsSinceEpoch}",
        "sender": "You",
        "text": text,
        "sentAt": now,
        "time": _formatMessageTime(now), // 🔥 SHOWS PROPER CURRENT TIME
        "dateHeader": _getDateHeader(now),
        "isMe": true,
      });
    });
  }

  Widget _buildWaveform() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(9, (index) {
        final intensity = _soundLevel.abs() * 3.2;
        final baseHeight = 10 + intensity.clamp(0, 52);
        final phase =
            (DateTime.now().millisecondsSinceEpoch / 90.0) + (index * 0.8);
        final shake = math.sin(phase) * 11;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 55),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 2.2),
          width: 3.8,
          height: (baseHeight + shake).clamp(6, 60),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildDateHeader(String dateHeader) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            dateHeader,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _bubble(Map<String, dynamic> msg) {
    final bool isMe = msg["isMe"] == true;
    final String time = msg["time"]?.toString() ?? "Now";
    final String text = msg["text"]?.toString() ?? "";

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            decoration: BoxDecoration(
              color: isMe ? primaryColor : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft:
                    isMe ? const Radius.circular(20) : const Radius.circular(4),
                bottomRight:
                    isMe ? const Radius.circular(4) : const Radius.circular(20),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
          // 🔥 TIME VISIBLE ON ALL MESSAGES
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 18,
              right: isMe ? 18 : 0,
              bottom: 4,
              top: 2,
            ),
            child: Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: isMe
                    ? Colors.grey
                    : Colors.grey[600] ?? Colors.grey[700], // 🔥 FIXED!
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String headerName = widget.isCustomer
        ? (widget.session.customer?.name ??
            widget.session.consultant?.name ??
            "Practitioner")
        : (widget.session.customer?.name ?? "Customer");

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          headerName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          // 🔥 FIXED: Phone Call Navigation
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionScreen(
                    session: widget.session, // ✅ Fixed!
                    isCustomer: widget.isCustomer, // ✅ Fixed!
                    callType: CallType.audio, // ✅ Added callType
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: messages.isEmpty && !_isLoadingHistory
                  ? const Center(
                      child: Text(
                        "Start conversation...",
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : _isLoadingHistory
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          reverse: true,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 12),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            if (index >= messages.length || index < 0) {
                              return const SizedBox.shrink();
                            }

                            final currentMsg = messages[index];
                            final List<Widget> widgets = [_bubble(currentMsg)];

                            bool showDateHeader = false;
                            if (index == messages.length - 1) {
                              showDateHeader = true;
                            } else if (index < messages.length - 1) {
                              final prevIndex = index + 1;
                              final prevMsg = messages[prevIndex];
                              final currentDate =
                                  currentMsg["dateHeader"]?.toString() ?? "";
                              final prevDate =
                                  prevMsg["dateHeader"]?.toString() ?? "";
                              if (currentDate != prevDate &&
                                  currentDate.isNotEmpty) {
                                showDateHeader = true;
                              }
                            }

                            if (showDateHeader) {
                              final dateHeader =
                                  currentMsg["dateHeader"]?.toString() ??
                                      "Today";
                              widgets.insert(0, _buildDateHeader(dateHeader));
                            }

                            return Column(children: widgets);
                          },
                        ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _isListening ? _buildListeningUI() : _buildNormalInput(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningUI() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _liveText.isEmpty ? "Listening..." : _liveText,
              style:
                  const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _buildWaveform(),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _toggleListening,
            child: const Icon(Icons.mic_none, color: Colors.black, size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: "Type message...",
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
            onSubmitted: (_) => _sendMessage(),
            textInputAction: TextInputAction.send,
            enabled: !_isSending,
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: _isSending ? null : _toggleListening,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.black, size: 24),
          ),
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 22,
          backgroundColor: _isSending ? Colors.grey : primaryColor,
          child: IconButton(
            icon: const Icon(Icons.send, color: Colors.white, size: 20),
            onPressed: _isSending ? null : _sendMessage,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    try {
      _speech.stop();
    } catch (e) {}
    _controller.dispose();
    super.dispose();
  }
}
