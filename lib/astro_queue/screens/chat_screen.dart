import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/foundation.dart' show kAlwaysDismissedAnimation;
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/screens/sessionextend_banner.dart';
import 'package:flutter_learning/astro_queue/services/websocketservice.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../model/consultantresponse_model.dart';
import '../services/chat_service.dart';

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

  String _liveText = "";
  String _pendingSpeechText = "";
  double _soundLevel = 0.0;

  Timer? _speechSendTimer;
  List<Map<String, dynamic>> messages = [];

  final Set<String> _localSentMessages = {};
  final Set<String> _serverMessages = {};
  final ImagePicker _picker = ImagePicker();

  static const int _uidCustomer = 1;
  static const int _uidPractitioner = 2;

  Timer? _countdownTimer;

  // ← Updated ONLY from WebSocket SESSION_EXTENDED event (source of truth)
  DateTime? _effectiveScheduledEnd;

  final ApiService _apiService = ApiService();
  bool _isSessionEnded = false;
  late WebSocketService _webSocketService;

  // Flag to prevent double-processing when both /queue/session
  // and /queue/session-events fire for the same extension
  bool _sessionExtendedLocally = false;

  // ──────────────────────────────────────────────────────────────
  // INIT
  // ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _webSocketService = WebSocketService();
    _initAnimations();
    _initSpeech();

    _effectiveScheduledEnd = widget.session.scheduledEnd;
    _startCountdownTimer();

    _webSocketService.connect(
      userId: widget.isCustomer
          ? (widget.session.customer?.id ?? 1)
          : (widget.session.consultant?.id ?? 2),
      onSessionUpdate: _handleSessionUpdate,
      onSessionEvent: _handleSessionEvent,
      onError: (error) => debugPrint("WS Error: $error"),
    );

    if (widget.session.sessionId != null) {
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

      _loadChatHistory();
    } else {
      messages = widget.initialMessages.map(_processMessage).toList();
    }

    _controller.addListener(() {
      setState(() => _showSendButton = _controller.text.trim().isNotEmpty);
    });
  }

  // ──────────────────────────────────────────────────────────────
  // WEBSOCKET — /user/queue/session-events
  // PRIMARY handler for SESSION_EXTENDED, EXPIRY_WARNING, SESSION_EXPIRED
  // ──────────────────────────────────────────────────────────────
  void _handleSessionEvent(Map<String, dynamic> event) {
    final String? eventType = event['eventType'];
    debugPrint("⏳ ChatScreen → Session Event: $eventType | $event");

    switch (eventType) {
      case 'EXPIRY_WARNING':
        _showExpirySnackbar(
          event['message'] ?? "Your session will expire soon!",
          Colors.orange,
        );
        break;

      case 'SESSION_EXPIRED':
        _handleSessionExpired(event);
        break;

      case 'SESSION_EXTENDED':
        _sessionExtendedLocally = true;
        _handleSessionExtendedFromEvent(event);
        break;
    }
  }

  // ──────────────────────────────────────────────────────────────
  // WEBSOCKET — /user/queue/session (legacy fallback)
  // Only processes session_extended if session-events didn't already handle it
  // ──────────────────────────────────────────────────────────────
  void _handleSessionUpdate(Map<String, dynamic> data) {
    print(" FULL DATA: $data");

    if (data['type'] == 'session_extended') {
      final String? newEndStr = data['newScheduledEnd'] as String?;
      final int minutes = (data['extendedMinutes'] as int?) ?? 15;

      if (newEndStr == null) {
        debugPrint(" session_extended missing newScheduledEnd");
        return;
      }

      final DateTime? newEnd = DateTime.tryParse(newEndStr);
      if (newEnd == null) {
        debugPrint(" Could not parse: $newEndStr");
        return;
      }

      final String formattedEnd =
          "${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}";

      setState(() {
        _effectiveScheduledEnd = newEnd;
        _isSessionEnded = false;
      });

      _restartCountdownTimer();

      final now = DateTime.now();
      setState(() {
        messages.insert(0, {
          "id": "system_${now.millisecondsSinceEpoch}",
          "text":
              "Session extended by $minutes minutes!\nNew end time: $formattedEnd",
          "sentAt": now,
          "time": _formatMessageTime(now),
          "dateHeader": _getDateHeader(now),
          "isMe": false,
          "type": "system",
        });
      });

      _scrollToBottom();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Extended +$minutes mins → ends at $formattedEnd ✓"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // Raw session object — silent update only if end time is later
    if (data['type'] == null && data['scheduledEnd'] != null) {
      final DateTime? newEnd =
          DateTime.tryParse(data['scheduledEnd'].toString());
      final DateTime? current = _effectiveScheduledEnd;
      if (newEnd != null && (current == null || newEnd.isAfter(current))) {
        setState(() {
          _effectiveScheduledEnd = newEnd;
          _isSessionEnded = false;
        });
        _restartCountdownTimer();
      }
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SESSION EXTENDED — from /queue/session-events (primary)
  // Uses exact newScheduledEnd from server
  // ──────────────────────────────────────────────────────────────
  void _handleSessionExtendedFromEvent(Map<String, dynamic> event) {
    final String msg = event['message'] ?? "Session extended!";
    final int minutes = (event['minutesLeft'] as int?) ?? 15;

    //  Use server's exact newScheduledEnd — authoritative source of truth
    final String? newEndStr = event['newScheduledEnd'] as String?;

    if (newEndStr == null) {
      debugPrint(
          " SESSION_EXTENDED missing newScheduledEnd — fallback +$minutes mins from now");
    }

    final DateTime newExpiry = newEndStr != null
        ? (DateTime.tryParse(newEndStr) ??
            DateTime.now().add(Duration(minutes: minutes)))
        : DateTime.now().add(Duration(minutes: minutes));

    setState(() {
      _effectiveScheduledEnd = newExpiry;
      _isSessionEnded = false;
    });

    _restartCountdownTimer();

    final String formattedEnd =
        "${newExpiry.hour.toString().padLeft(2, '0')}:${newExpiry.minute.toString().padLeft(2, '0')}";

    final now = DateTime.now();
    setState(() {
      messages.insert(0, {
        "id": "system_${now.millisecondsSinceEpoch}",
        "text": "$msg\nNew end time: $formattedEnd",
        "sentAt": now,
        "time": _formatMessageTime(now),
        "dateHeader": _getDateHeader(now),
        "isMe": false,
        "type": "system",
      });
    });

    _scrollToBottom();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Extended +$minutes mins → ends at $formattedEnd ✓"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SESSION EXTENDED — from /queue/session (legacy fallback)
  // Used only when session-events didn't fire
  // ──────────────────────────────────────────────────────────────
  void _handleSessionExtended(Map<String, dynamic> data) {
    final String? newEndStr = data['newScheduledEnd'] as String?;
    final int minutes = (data['extendedMinutes'] as int?) ?? 15;

    if (newEndStr == null) {
      debugPrint("⚠️ Legacy session_extended missing newScheduledEnd");
      return;
    }

    final DateTime? newEnd = DateTime.tryParse(newEndStr);
    if (newEnd == null) {
      debugPrint("⚠️ Could not parse newScheduledEnd: $newEndStr");
      return;
    }

    setState(() {
      _effectiveScheduledEnd = newEnd;
      _isSessionEnded = false;
    });

    _restartCountdownTimer();

    final String formattedEnd =
        "${newEnd.hour.toString().padLeft(2, '0')}:${newEnd.minute.toString().padLeft(2, '0')}";

    final now = DateTime.now();
    setState(() {
      messages.insert(0, {
        "id": "system_${now.millisecondsSinceEpoch}",
        "text":
            "✅ Session extended by $minutes minutes!\nNew end time: $formattedEnd",
        "sentAt": now,
        "time": _formatMessageTime(now),
        "dateHeader": _getDateHeader(now),
        "isMe": false,
        "type": "system",
      });
    });

    _scrollToBottom();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Extended +$minutes mins → ends at $formattedEnd ✓"),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ──────────────────────────────────────────────────────────────
  // SESSION EXPIRED
  // ──────────────────────────────────────────────────────────────
  void _handleSessionExpired(Map<String, dynamic> event) {
    if (_isSessionEnded) return;
    _isSessionEnded = true;
    _countdownTimer?.cancel();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(event['message'] ?? "Session has expired"),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      setState(() {});
    }
  }

  void _showExpirySnackbar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  // ──────────────────────────────────────────────────────────────
  // EXTEND SESSION — API call only, NO local end-time update
  // End time comes exclusively from WebSocket SESSION_EXTENDED event
  // ──────────────────────────────────────────────────────────────
  Future<void> _extendSession() async {
    if (_isExtending || widget.session.sessionId == null) return;
    if (mounted) setState(() => _isExtending = true);

    try {
      final result =
          await ApiService.extendSession(widget.session.sessionId!.toString());

      if (!mounted) return;

      if (result['success'] == true) {
        // ✅ Update end time directly from API response
        final int minutes = (result['extendedMinutes'] as int?) ?? 15;
        final DateTime? current =
            _effectiveScheduledEnd ?? widget.session.scheduledEnd;
        final DateTime newExpiry =
            (current ?? DateTime.now()).add(Duration(minutes: minutes));

        final String formattedEnd =
            "${newExpiry.hour.toString().padLeft(2, '0')}:${newExpiry.minute.toString().padLeft(2, '0')}";

        final now = DateTime.now();

        setState(() {
          _effectiveScheduledEnd = newExpiry;
          _isSessionEnded = false;
          messages.insert(0, {
            "id": "system_${now.millisecondsSinceEpoch}",
            "text":
                "✅ Session extended by $minutes minutes!\nNew end time: $formattedEnd",
            "sentAt": now,
            "time": _formatMessageTime(now),
            "dateHeader": _getDateHeader(now),
            "isMe": false,
            "type": "system",
          });
        });

        _restartCountdownTimer();
        _scrollToBottom();

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Extended +$minutes mins → ends at $formattedEnd ✓"),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result['message'] ?? 'Extension failed'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      debugPrint("Extend error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Network error. Please try again."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isExtending = false);
    }
  }

  // ──────────────────────────────────────────────────────────────
  // COUNTDOWN TIMER
  // ──────────────────────────────────────────────────────────────
  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
        _checkIfSessionEnded();
      }
    });
  }

  void _restartCountdownTimer() {
    _countdownTimer?.cancel();
    _startCountdownTimer();
  }

  void _checkIfSessionEnded() {
    if (_isSessionEnded) return;
    final endTime = _effectiveScheduledEnd ?? widget.session.scheduledEnd;
    if (endTime != null && DateTime.now().isAfter(endTime)) {
      _isSessionEnded = true;
      _countdownTimer?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Session time completed"),
          backgroundColor: Colors.red,
        ));
        setState(() {});
      }
    }
  }

  String _getDurationDisplayText() {
    final now = DateTime.now();
    final endTime = _effectiveScheduledEnd ?? widget.session.scheduledEnd;

    if (widget.session.status == SessionStatus.completed &&
        widget.session.actualDurationMinutes != null &&
        widget.session.actualDurationMinutes! > 0) {
      return "${widget.session.actualDurationMinutes} mins completed";
    }

    if (endTime != null) {
      final remaining = endTime.difference(now);
      if (remaining.isNegative) {
        final over = now.difference(endTime);
        return "Over by ${over.inMinutes.toString().padLeft(2, '0')}:${(over.inSeconds % 60).toString().padLeft(2, '0')}";
      }
      return "${remaining.inMinutes.toString().padLeft(2, '0')}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}";
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

  // ──────────────────────────────────────────────────────────────
  // CHAT HISTORY
  // ──────────────────────────────────────────────────────────────
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
    } catch (e) {
      messages = widget.initialMessages.map(_processMessage).toList();
    }

    _isLoadingHistory = false;
    setState(() {});
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

  // ──────────────────────────────────────────────────────────────
  // SEND MESSAGE
  // ──────────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending || widget.session.sessionId == null) return;

    _isSending = true;

    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }

    _addLocalTextMessage(text);
    _localSentMessages.add(text);

    widget.chatService.sendMessage(
      sessionId: widget.session.sessionId!,
      senderId: widget.isCustomer ? _uidCustomer : _uidPractitioner,
      message: text,
    );

    _controller.clear();
    _pendingSpeechText = "";
    setState(() => _showSendButton = false);

    await Future.delayed(const Duration(milliseconds: 500));
    _isSending = false;
    _scrollToBottom();
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

  // ──────────────────────────────────────────────────────────────
  // SPEECH
  // ──────────────────────────────────────────────────────────────
  void _initAnimations() {
    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _micScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
          parent: _micAnimationController!, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    bool hasPermission = await Permission.microphone.request().isGranted;
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Microphone permission required")));
      }
      return;
    }

    bool initialized = await _speech.initialize(
      onError: (error) {
        debugPrint("Speech error: ${error.errorMsg}");
        if (mounted) {
          setState(() {
            _isListening = false;
            _soundLevel = 0.0;
            _liveText = "";
          });
        }
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') _handleSpeechDone();
      },
    );

    if (!initialized && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Speech initialization failed")));
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      _micAnimationController?.stop();
      _cancelSpeechSendTimer();
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
      if (_pendingSpeechText.trim().isNotEmpty) {
        _controller.text = _pendingSpeechText.trim();
        setState(() => _showSendButton = true);
        _pendingSpeechText = "";
      }
    } else {
      _controller.clear();
      setState(() {
        _isListening = true;
        _liveText = "";
        _pendingSpeechText = "";
        _soundLevel = 0.0;
      });
      if (_micAnimationController?.isAnimating != true) {
        _micAnimationController?.repeat(reverse: true);
      }

      try {
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _liveText = result.recognizedWords;
                if (result.finalResult) {
                  _pendingSpeechText = result.recognizedWords;
                } else {
                  _pendingSpeechText += " ${result.recognizedWords}";
                }
              });
            }
          },
          onSoundLevelChange: (level) {
            if (mounted && _isListening) {
              setState(() => _soundLevel = math.min(level * 3, 1.0));
            }
          },
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 2),
          partialResults: true,
          localeId: 'en_IN',
          cancelOnError: true,
        );
      } catch (e) {
        debugPrint("Listen error: $e");
        if (mounted) {
          setState(() {
            _isListening = false;
            _soundLevel = 0.0;
          });
        }
      }
    }
  }

  void _handleSpeechDone() {
    _micAnimationController?.stop();
    _cancelSpeechSendTimer();
    setState(() {
      _isListening = false;
      _soundLevel = 0.0;
    });
    if (_liveText.trim().isNotEmpty) {
      _controller.text = _liveText.trim();
      setState(() => _showSendButton = true);
    }
  }

  void _cancelSpeechSendTimer() {
    _speechSendTimer?.cancel();
    _speechSendTimer = null;
  }

  // ──────────────────────────────────────────────────────────────
  // ATTACHMENTS
  // ──────────────────────────────────────────────────────────────
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 30,
          runSpacing: 20,
          children: [
            _attachmentItem(Icons.camera_alt, "Camera", Colors.pink, () async {
              Navigator.pop(context);
              final image = await _picker.pickImage(source: ImageSource.camera);
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
      ),
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
              child: Icon(icon, color: Colors.white)),
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

  // ──────────────────────────────────────────────────────────────
  // MENU ACTIONS
  // ──────────────────────────────────────────────────────────────
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
        title: const Row(children: [
          Icon(Icons.call_end, color: Colors.red, size: 28),
          SizedBox(width: 12),
          Text("End Session?", style: TextStyle(fontWeight: FontWeight.bold))
        ]),
        content:
            const Text("This will complete the current consultation session."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog only — stay on ChatScreen
              _countdownTimer?.cancel();
              setState(() => _isSessionEnded = true);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text("Session ended"),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
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
              child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => messages.clear());
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }

  String _getHeaderName() {
    if (widget.isCustomer) {
      return widget.session.consultant?.name ?? "Practitioner";
    } else {
      return widget.session.customer?.name ?? "Customer";
    }
  }

  // ──────────────────────────────────────────────────────────────
  // MESSAGE BUBBLE
  // ──────────────────────────────────────────────────────────────
  Widget _bubble(Map<String, dynamic> msg) {
    final bool isMe = msg["isMe"];
    final String? type = msg["type"];

    if (type == "system") {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                msg["text"] ?? "",
                style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(msg["time"] ?? "",
                  style: TextStyle(fontSize: 11, color: Colors.blue[600])),
            ],
          ),
        ),
      );
    }

    Widget content;
    if (type == "image") {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Image.file(
          msg["image"],
          width: 200,
          height: 200,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 200,
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          ),
        ),
      );
    } else if (type == "document") {
      content = Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file, color: Colors.blue),
            const SizedBox(width: 8),
            Flexible(
                child: Text(msg["fileName"] ?? "Document",
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
    } else {
      content = Text(
        msg["text"] ?? "",
        style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
            height: 1.3),
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
                color: Colors.black.withOpacity(0.12),
                blurRadius: 2,
                offset: const Offset(0, 1))
          ],
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            content,
            const SizedBox(height: 4),
            Text(
              msg["time"] ?? "",
              style: TextStyle(
                  fontSize: 11,
                  color: isMe ? Colors.white70 : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final String headerName = _getHeaderName();
    final String durationText = _getDurationDisplayText();

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (!_isExtending) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 2, 40, 3),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(headerName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
              if (durationText.isNotEmpty)
                Text(durationText,
                    style: TextStyle(
                        color: _getDurationColor(),
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
            ],
          ),
          actions: [
            PopupMenuButton<String>(
              color: Colors.black87,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
              onSelected: _handleMenuAction,
              itemBuilder: (context) => [
                if (widget.isCustomer)
                  const PopupMenuItem(
                    value: 'extend',
                    child: Row(children: [
                      Icon(Icons.more_time, color: Colors.orange, size: 20),
                      SizedBox(width: 12),
                      Text('Extend 15 mins',
                          style: TextStyle(color: Colors.white))
                    ]),
                  ),
                const PopupMenuItem(
                  value: 'end_session',
                  child: Row(children: [
                    Icon(Icons.call_end, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('End Session', style: TextStyle(color: Colors.red))
                  ]),
                ),
                const PopupMenuItem(
                  value: 'clear_chat',
                  child: Row(children: [
                    Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                    SizedBox(width: 12),
                    Text('Clear Chat', style: TextStyle(color: Colors.white))
                  ]),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
                child: Image.asset("assets/images/whats_app_background.jpg",
                    fit: BoxFit.cover)),
            Column(
              children: [
                SessionExtendBanner(
                  session: widget.session,
                  isCustomer: widget.isCustomer,
                  effectiveScheduledEnd: _effectiveScheduledEnd,
                  onExtend: _extendSession,
                  isExtending: _isExtending,
                ),
                Expanded(
                  child: ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    padding: const EdgeInsets.all(10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) => _bubble(messages[index]),
                  ),
                ),
                // Input bar
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 10,
                          offset: Offset(0, -2))
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                          icon:
                              Icon(Icons.attach_file, color: Colors.grey[600]),
                          onPressed: _showAttachmentOptions),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? "Listening... $_liveText"
                                : "Type a message",
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none),
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
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
                                  icon: const Icon(Icons.send,
                                      color: Colors.green, size: 24),
                                  style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.green.withOpacity(0.1),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50))),
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
                                                  (soundMultiplier * 20.0))
                                              .clamp(48.0, 90.0);
                                          return Container(
                                            width: pulseSize,
                                            height: pulseSize,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.red.withOpacity(
                                                    0.3 +
                                                        (animationValue * 0.3) +
                                                        (soundMultiplier *
                                                            0.4))),
                                          );
                                        },
                                      ),
                                    IconButton(
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                          minWidth: 48, minHeight: 48),
                                      icon: Icon(
                                          _isListening
                                              ? Icons.mic
                                              : Icons.mic_none,
                                          color: _isListening
                                              ? Colors.red
                                              : Colors.grey[600],
                                          size: 24),
                                      style: IconButton.styleFrom(
                                        backgroundColor: _isListening
                                            ? Colors.red.withOpacity(0.15)
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
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────
  // DISPOSE
  // ──────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _countdownTimer?.cancel();
    _speechSendTimer?.cancel();
    widget.chatService.disconnect();
    _webSocketService.disconnect();
    _micAnimationController?.stop();
    _micAnimationController?.dispose();
    _speech.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
