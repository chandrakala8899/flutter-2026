import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter/foundation.dart' show kAlwaysDismissedAnimation;
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import '../model/consultantresponse_model.dart';
import '../services/chat_service.dart';
import '../../colors.dart';

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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late stt.SpeechToText _speech;
  AnimationController? _micAnimationController;
  Animation<double>? _micScaleAnimation;

  bool _isListening = false;
  bool _isSending = false;
  bool _isLoadingHistory = false;
  bool _showSendButton = false;
  bool _isExtending = false;
  bool _hasShown10MinPopup = false;

  String _liveText = "";
  double _soundLevel = 0.0;

  List<Map<String, dynamic>> messages = [];

  final Set<String> _localSentMessages = {};
  final Set<String> _serverMessages = {};

  final ImagePicker _picker = ImagePicker();

  static const int _uidCustomer = 1;
  static const int _uidPractitioner = 2;

  Timer? _countdownTimer;
  Timer? _popupTimer;
  DateTime? _effectiveScheduledEnd;

  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initAnimations();
    _initSpeech();
    _loadChatHistory();

    _effectiveScheduledEnd = widget.session.scheduledEnd;
    _startCountdownTimer();
    _startPopupTimer();

    widget.chatService.connect(
      widget.isCustomer ? " " : " ",
      sessionId: widget.session.sessionId!,
    );

    widget.chatService.onMessageReceived = (data) {
      final messageId = data["id"]?.toString();
      final text = data["message"]?.toString().trim() ?? "";

      if (_localSentMessages.contains(text) ||
          (messageId != null && _serverMessages.contains(messageId))) {
        return;
      }

      setState(() {
        messages.insert(0, _processMessage(data));
        if (messageId != null) _serverMessages.add(messageId);
      });

      _scrollToBottom();
    };

    _controller.addListener(() {
      setState(() {
        _showSendButton = _controller.text.trim().isNotEmpty;
      });
    });
  }

  String _getHeaderName() {
    if (widget.isCustomer) {
      return widget.session.consultant?.name ?? "Practitioner";
    } else {
      return widget.session.customer?.name ?? "Customer";
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _startPopupTimer() {
    _popupTimer?.cancel();
    final endTime = _effectiveScheduledEnd ?? widget.session.scheduledEnd;
    if (endTime != null) {
      final timeTo10Min = endTime.subtract(const Duration(minutes: 10));
      if (DateTime.now().isBefore(timeTo10Min)) {
        _popupTimer = Timer(timeTo10Min.difference(DateTime.now()), () {
          if (mounted && !_hasShown10MinPopup) {
            _show10MinWarningPopup();
          }
        });
      } else if (endTime.difference(DateTime.now()).inMinutes <= 10) {
        if (!_hasShown10MinPopup) {
          _show10MinWarningPopup();
        }
      }
    }
  }

  void _initAnimations() {
    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _micAnimationController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  Future<void> _loadChatHistory() async {
    if (_isLoadingHistory || widget.session.sessionId == null) return;

    _isLoadingHistory = true;
    messages.clear();
    _localSentMessages.clear();
    _serverMessages.clear();
    setState(() {});

    try {
      final history =
          await _apiService.getChatHistory(widget.session.sessionId!);
      messages = history.map((m) => _processMessage(m)).toList();
      setState(() {});
    } catch (e) {
      messages = widget.initialMessages.map(_processMessage).toList();
      setState(() {});
    }

    _isLoadingHistory = false;
    _scrollToBottom();
  }

  Map<String, dynamic> _processMessage(Map<String, dynamic> data) {
    DateTime sentAt = DateTime.now();
    if (data["sentAt"] != null) {
      sentAt = DateTime.tryParse(data["sentAt"]) ?? DateTime.now();
    }

    final senderId = data["senderId"] ?? 0;
    final myId = widget.isCustomer ? _uidCustomer : _uidPractitioner;

    return {
      "id": data["id"] ?? "local_${DateTime.now().millisecondsSinceEpoch}",
      "text": data["message"] ?? "",
      "sentAt": sentAt,
      "time": _formatMessageTime(sentAt),
      "dateHeader": _getDateHeader(sentAt),
      "isMe": senderId == myId,
      "type": data["type"] ?? "text",
    };
  }

  String _formatMessageTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$minute $period";
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(date.year, date.month, date.day);

    if (msgDay == today) return "Today";
    if (msgDay == today.subtract(const Duration(days: 1))) return "Yesterday";

    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _initSpeech() async {
    await Permission.microphone.request();
    await _speech.initialize();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      _micAnimationController?.stop();
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    } else {
      setState(() {
        _isListening = true;
        _liveText = "";
        _soundLevel = 0.0;
      });

      if (_micAnimationController?.isAnimating != true) {
        _micAnimationController?.repeat(reverse: true);
      }

      await _speech.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _liveText = result.recognizedWords;
            });
          }
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() => _soundLevel = math.min(level, 1.0));
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    _isSending = true;
    _addLocalTextMessage(text);
    _localSentMessages.add(text);

    widget.chatService.sendMessage(
      sessionId: widget.session.sessionId!,
      senderId: widget.isCustomer ? _uidCustomer : _uidPractitioner,
      message: text,
    );

    _controller.clear();
    setState(() => _showSendButton = false);
    await Future.delayed(const Duration(milliseconds: 500));
    _isSending = false;
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addLocalTextMessage(String text) {
    final now = DateTime.now();
    setState(() {
      messages.insert(0, {
        "id": "local_${now.millisecondsSinceEpoch}",
        "text": text,
        "sentAt": now,
        "time": _formatMessageTime(now),
        "dateHeader": _getDateHeader(now),
        "isMe": true,
        "type": "text",
      });
    });
    _scrollToBottom();
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 30,
            runSpacing: 20,
            children: [
              _attachmentItem(Icons.camera_alt, "Camera", Colors.pink,
                  () async {
                Navigator.pop(context);
                final image =
                    await _picker.pickImage(source: ImageSource.camera);
                if (image != null) _addImageMessage(File(image.path));
              }),
              _attachmentItem(Icons.photo, "Gallery", Colors.green, () async {
                Navigator.pop(context);
                final image =
                    await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) _addImageMessage(File(image.path));
              }),
              _attachmentItem(Icons.insert_drive_file, "Document", Colors.blue,
                  () async {
                Navigator.pop(context);
                final result = await FilePicker.platform.pickFiles();
                if (result != null && result.files.single.path != null) {
                  _addDocumentMessage(File(result.files.single.path!));
                }
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _attachmentItem(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  void _addImageMessage(File file) {
    final now = DateTime.now();
    setState(() {
      messages.insert(0, {
        "id": "img_${now.millisecondsSinceEpoch}",
        "image": file,
        "sentAt": now,
        "time": _formatMessageTime(now),
        "dateHeader": _getDateHeader(now),
        "isMe": true,
        "type": "image",
      });
    });
    _scrollToBottom();
  }

  void _addDocumentMessage(File file) {
    final now = DateTime.now();
    setState(() {
      messages.insert(0, {
        "id": "doc_${now.millisecondsSinceEpoch}",
        "file": file,
        "fileName": file.path.split('/').last,
        "sentAt": now,
        "time": _formatMessageTime(now),
        "dateHeader": _getDateHeader(now),
        "isMe": true,
        "type": "document",
      });
    });
    _scrollToBottom();
  }

  Widget _bubble(Map<String, dynamic> msg) {
    final bool isMe = msg["isMe"];
    final String? type = msg["type"];

    Widget content;

    if (type == "image") {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.file(
          msg["image"],
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(width: 200, height: 200, color: Colors.grey),
        ),
      );
    } else if (type == "document") {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, color: Colors.blue),
            const SizedBox(width: 8),
            Flexible(child: Text(msg["fileName"] ?? "Document")),
          ],
        ),
      );
    } else {
      content = Text(
        msg["text"] ?? "",
        style: TextStyle(
          color: isMe ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color.fromARGB(255, 2, 40, 3) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            content,
            const SizedBox(height: 4),
            Text(
              msg["time"],
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white70 : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getDurationDisplayText() {
    final endTime = _effectiveScheduledEnd ?? widget.session.scheduledEnd;

    if (widget.session.status == SessionStatus.completed &&
        widget.session.actualDurationMinutes != null &&
        widget.session.actualDurationMinutes! > 0) {
      return "${widget.session.actualDurationMinutes} mins completed";
    }

    if (endTime != null) {
      final remaining = endTime.difference(DateTime.now());

      if (remaining.isNegative) {
        final over = -remaining;
        final min = over.inMinutes;
        final sec = over.inSeconds % 60;
        return "Over by ${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
      }

      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      final timerStr =
          "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";

      return "$timerStr";
    }

    if (widget.session.scheduledDurationMinutes != null) {
      return "${widget.session.scheduledDurationMinutes} mins scheduled";
    }

    return "Consultation";
  }

  Color _getDurationColor() {
    final endTime = _effectiveScheduledEnd ?? widget.session.scheduledEnd;
    if (endTime == null) return Colors.white70;

    final remainingMinutes = endTime.difference(DateTime.now()).inMinutes;

    if (remainingMinutes > 10) return Colors.white70;
    if (remainingMinutes > 5) return Colors.amber;
    return Colors.redAccent;
  }

  bool get _shouldShowExtendBanner {
    if (!widget.isCustomer) return false;

    final endTime = _effectiveScheduledEnd ?? widget.session.scheduledEnd;
    if (endTime == null) return false;

    final remaining = endTime.difference(DateTime.now());
    return remaining.inMinutes <= 3 && remaining.inSeconds > 0;
  }

  Future<void> _extendSession() async {
    if (_isExtending) return;

    setState(() => _isExtending = true);

    try {
      final success = await ApiService.extendSession(
        widget.session.sessionId!,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Session extended by 15 minutes"),
            backgroundColor: Colors.green,
          ),
        );
        _loadSessionDetails();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to extend session"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() => _isExtending = false);
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'extend':
        _extendSession();
        break;
      case 'end_session':
        _endSession();
        break;
      case 'clear_chat':
        _clearChat();
        break;
    }
  }

  void _endSession() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.call_end, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text("End Session?", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content:
            const Text("This will complete the current consultation session."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle end session API call
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("End Session"),
          ),
        ],
      ),
    );
  }

  void _clearChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Clear Chat?",
            style: TextStyle(fontWeight: FontWeight.bold)),
        content:
            const Text("This will clear all messages in this conversation."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                messages.clear();
              });
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }

  void _show10MinWarningPopup() {
    if (!mounted || _hasShown10MinPopup) return;

    _hasShown10MinPopup = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.timer_off, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              Text(
                "Session Ending Soon!",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Your session will end in approximately 10 minutes.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                "Extend now to continue your consultation uninterrupted.",
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Later"),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _extendSession();
              },
              icon: const Icon(Icons.more_time),
              label: const Text("Extend 15 mins"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSessionDetails() async {
    try {
      final updatedSession = await ApiService.getCurrentSession(
          widget.session.consultant!.id.toString());
      if (mounted) {
        setState(() {
          _effectiveScheduledEnd = updatedSession!.scheduledEnd;
        });
        _hasShown10MinPopup = false;
        _startPopupTimer();
      }
    } catch (e) {
      print("Failed to refresh session: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final String headerName = _getHeaderName();
    final String durationText = _getDurationDisplayText();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 2, 40, 3),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              headerName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (durationText.isNotEmpty)
              Text(
                durationText,
                style: TextStyle(
                  color: _getDurationColor(),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          // ✅ THREE DOTS MENU (WhatsApp Style)
          PopupMenuButton<String>(
            color: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              if (widget.isCustomer)
                PopupMenuItem(
                  value: 'extend',
                  child: Row(
                    children: [
                      Icon(Icons.more_time, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      const Text('Extend 15 mins',
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'end_session',
                child: Row(
                  children: [
                    Icon(Icons.call_end, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    const Text('End Session',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_chat',
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Chat', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/whats_app_background.jpg",
              fit: BoxFit.cover,
            ),
          ),
          Column(
            children: [
              if (_shouldShowExtendBanner)
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade700,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_off, color: Colors.white),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Session ending soon!\nPlease extend to continue chatting.",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _isExtending ? null : _extendSession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.orange.shade700,
                        ),
                        child: _isExtending
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.orange.shade700,
                                  ),
                                ),
                              )
                            : const Text("Extend 15 mins"),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  controller: _scrollController,
                  padding: const EdgeInsets.all(10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _bubble(messages[index]);
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                      onPressed: _showAttachmentOptions,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: "Type a message",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(25),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _showSendButton
                          ? Container(
                              key: const ValueKey('send'),
                              child: IconButton(
                                key: const ValueKey('send_button'),
                                icon: const Icon(Icons.send,
                                    color: Colors.green, size: 24),
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      Colors.green.withOpacity(0.1),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50)),
                                ),
                                onPressed: _sendMessage,
                              ),
                            )
                          : Container(
                              key: const ValueKey('mic'),
                              width: 56,
                              height: 56,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (_isListening)
                                    AnimatedBuilder(
                                      animation: _micAnimationController ??
                                          kAlwaysDismissedAnimation,
                                      builder: (context, child) {
                                        final animationValue =
                                            (_micAnimationController?.value ??
                                                    0.0)
                                                .clamp(0.0, 1.0);
                                        final soundMultiplier =
                                            _soundLevel.clamp(0.0, 1.0);
                                        final pulseSize = (48.0 +
                                                (animationValue * 16.0) +
                                                (soundMultiplier * 12.0))
                                            .clamp(48.0, 80.0);

                                        return Container(
                                          width: pulseSize,
                                          height: pulseSize,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.red.withOpacity(0.2 +
                                                (animationValue * 0.2) +
                                                (soundMultiplier * 0.2)),
                                          ),
                                        );
                                      },
                                    ),
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 48, minHeight: 48),
                                    icon: Icon(
                                      _isListening ? Icons.mic : Icons.mic_none,
                                      color: _isListening
                                          ? Colors.red
                                          : Colors.grey[600],
                                      size: 24,
                                    ),
                                    style: IconButton.styleFrom(
                                      backgroundColor: _isListening
                                          ? Colors.red.withOpacity(0.1)
                                          : Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50)),
                                    ),
                                    onPressed: _toggleListening,
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _popupTimer?.cancel();
    widget.chatService.disconnect();
    _micAnimationController?.stop();
    _micAnimationController?.dispose();
    _speech.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
