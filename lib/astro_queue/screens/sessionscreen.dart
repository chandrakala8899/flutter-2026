import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/screens/agora_chat_ui.dart';
import 'package:flutter_learning/astro_queue/screens/vedio_call_screen.dart';
import 'package:flutter_learning/astro_queue/services/chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}

enum CallType { chat, audio, video }

class SessionScreen extends StatefulWidget {
  final ConsultationSessionResponse? session;
  final bool isCustomer;
  final String? channelName;
  final String? token;
  final CallType callType;

  const SessionScreen({
    super.key,
    this.session,
    required this.isCustomer,
    required this.callType,
    this.channelName,
    this.token,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  RtcEngine? _engine;

  bool _isInCall = false;
  bool _localUserJoined = false;
  bool _remoteUserJoined = false;
  bool _remoteVideoPublished = false;
  bool _micMuted = false;
  bool _videoMuted = false;
  bool _isVoiceOnly = false;
  int? _remoteUid;
  SessionStatus _currentStatus = SessionStatus.waiting;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  final TextEditingController _messageController = TextEditingController();

  String get _channelName => widget.channelName ?? "astro_channel_123";

  static const int _uidCustomer = 1;
  static const int _uidPractitioner = 2;
  static const String _appId = "1a799cf30b064aabbd16218fa05b4014";

  bool _isStartingCall = false;
  String? _errorMessage;
  late ApiService _apiService;

  // ── WebSocket ChatService ONLY for audio/video in-call text chat ────────────
  // NOT used for CallType.chat — Agora IM SDK handles that entirely.
  late ChatService _chatService;
  List<Map<String, dynamic>> _messages = [];

  static const ValueKey _remoteVideoKey = ValueKey('remote_video');

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController);
    _pulseController.repeat(reverse: true);

    // WebSocket only needed for audio/video side-chat, not for CallType.chat
    if (widget.callType != CallType.chat) {
      _chatService = ChatService(
        onMessageReceived: (data) {
          final messageId = data["id"];
          final alreadyExists = _messages.any((m) => m["id"] == messageId);
          if (!alreadyExists) {
            setState(() {
              _messages.insert(0, {
                "id": messageId,
                "sender": data["senderName"]?.toString() ?? "Unknown",
                "text": data["message"]?.toString() ?? "",
                "isMe": data["senderId"] ==
                    (widget.isCustomer ? _uidCustomer : _uidPractitioner),
              });
            });
          }
        },
      );
      if (widget.session != null) {
        _chatService.connect(
          (widget.isCustomer ? _uidCustomer : _uidPractitioner).toString(),
          sessionId: widget.session!.sessionId!,
        );
      }
    }

    // Auto-start audio/video call
    if (widget.callType == CallType.audio ||
        widget.callType == CallType.video) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (widget.callType == CallType.audio) _isVoiceOnly = true;
        _startCall();
      });
    }

    // CallType.chat → nothing to do here.
    // AgoraChatScreen handles SDK init, token fetch, login, and history itself.
  }

  // ─── RTC TOKEN (for audio/video only) ──────────────────────────────────────
  Future<String> _fetchAgoraToken() async {
    final uid = widget.isCustomer ? _uidCustomer : _uidPractitioner;
    try {
      final url =
          "http://192.168.1:16679/api/agora/token?channelName=$_channelName&uid=$uid";
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final token = response.body.trim();
        if (token.length > 100) return token;
      }
    } catch (e) {
      _log("RTC token fetch failed: $e");
    }
    // Fallback temp token
    return "007eJxTYLBkXxwuPCOZVyvnwefljzwPqiX1LA/bwXvro/NT9olxDVsVGAwTzS0tk9OMDZIMzEwSE5OSUgzNjAwt0hINTJNMDAxNXDYuymwIZGSYnBXCxMgAgSC+IENicUlRfnxyRmJeXmpOvKGRMQMDANbDI44=";
  }

  // ─── START RTC CALL ────────────────────────────────────────────────────────
  Future<void> _startCall() async {
    if (_isStartingCall) return;
    _isStartingCall = true;
    _errorMessage = null;
    setState(() {});

    try {
      final statuses =
          await [Permission.camera, Permission.microphone].request();
      if (statuses[Permission.camera] != PermissionStatus.granted ||
          statuses[Permission.microphone] != PermissionStatus.granted) {
        throw Exception("Camera & Microphone permission required");
      }

      await _cleanupEngine();
      _engine = createAgoraRtcEngine();

      await _engine!.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (connection, elapsed) {
          _log("✅ JOINED: $_channelName");
          if (mounted) {
            setState(() {
              _localUserJoined = true;
              _isInCall = true;
              _currentStatus = SessionStatus.inProgress;
            });
          }
        },
        onUserJoined: (connection, remoteUid, elapsed) {
          _log("🎉 REMOTE JOINED: $remoteUid");
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
              _remoteUserJoined = true;
            });
          }
        },
        onFirstRemoteVideoFrame:
            (connection, remoteUid, width, height, elapsed) {
          _log("📹 REMOTE VIDEO FRAME: $remoteUid");
          if (mounted && _remoteUid == remoteUid) {
            setState(() => _remoteVideoPublished = true);
          }
        },
        onError: (err, msg) {
          _log("❌ RTC ERROR: $err - $msg");
          if (mounted) setState(() => _errorMessage = "Error: $err");
        },
      ));

      await _engine!.enableAudio();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      if (_isVoiceOnly) {
        await _engine!.disableVideo();
      } else {
        await _engine!.enableVideo();
        await _engine!.startPreview();
        await _engine!.setVideoEncoderConfiguration(
          const VideoEncoderConfiguration(
            dimensions: VideoDimensions(width: 540, height: 960),
            frameRate: 15,
            bitrate: 800,
            orientationMode: OrientationMode.orientationModeFixedPortrait,
            degradationPreference: DegradationPreference.maintainQuality,
          ),
        );
        await _engine!.setParameters('{"che.video.low_latency_mode":1}');
        await _engine!.setParameters('{"che.video.color_range":2}');
        await _engine!.setParameters('{"che.video.color_space":1}');
        await _engine!.setParameters('{"che.video.enable_hw_decoder":1}');
      }

      final token = widget.token ?? await _fetchAgoraToken();
      await _engine!.joinChannel(
        token: token,
        channelId: _channelName,
        uid: widget.isCustomer ? _uidCustomer : _uidPractitioner,
        options: ChannelMediaOptions(
          publishMicrophoneTrack: true,
          publishCameraTrack: !_isVoiceOnly,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      _log("🚀 RTC CALL STARTED: $_channelName");
    } catch (e) {
      _log("❌ CALL FAILED: $e");
      if (mounted) setState(() => _errorMessage = "Failed to start call: $e");
    } finally {
      _isStartingCall = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _cleanupEngine() async {
    if (_engine == null) return;
    try {
      await _engine!.leaveChannel();
      if (!_isVoiceOnly) await _engine!.stopPreview();
      await _engine!.release();
    } catch (e) {
      _log("Engine cleanup error: $e");
    }
    _engine = null;
    if (mounted) {
      setState(() {
        _remoteUid = null;
        _remoteUserJoined = false;
        _localUserJoined = false;
        _remoteVideoPublished = false;
        _isInCall = false;
      });
    }
  }

  Future<void> _leaveCall() async {
    await _cleanupEngine();
    if (widget.callType != CallType.chat) _chatService.disconnect();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Session Ended"), backgroundColor: Colors.red),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _toggleMic() async {
    if (_engine == null) return;
    setState(() => _micMuted = !_micMuted);
    await _engine!.muteLocalAudioStream(_micMuted);
  }

  Future<void> _toggleCamera() async {
    if (_engine == null || _isVoiceOnly) return;
    setState(() => _videoMuted = !_videoMuted);
    await _engine!.muteLocalVideoStream(_videoMuted);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.session == null) return;
    final senderId = widget.isCustomer ? _uidCustomer : _uidPractitioner;
    _chatService.sendMessage(
      sessionId: widget.session!.sessionId!,
      senderId: senderId,
      message: text,
    );
    _messageController.clear();
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── 🔥 CHAT MODE: hand off entirely to AgoraChatScreen ───────────────────
    if (widget.callType == CallType.chat) {
      if (widget.session == null) {
        return const Scaffold(
          body: Center(child: Text("No session provided.")),
        );
      }
      // AgoraChatScreen owns everything:
      //   ✅ Agora IM SDK init
      //   ✅ Token fetch from backend (printed to console)
      //   ✅ Login with token
      //   ✅ fetchHistoryMessages() from Agora SDK
      //   ✅ Real-time messaging via MessagesView
      // No websocket. No spinner here. No backend history call.
      return AgoraChatScreen(
        session: widget.session!,
        isCustomer: widget.isCustomer,
        chatService: _apiService,
        initialMessages: const [],
        isFullScreen: true,
      );
    }

    // ── 🔥 VIDEO / AUDIO CALL MODE ────────────────────────────────────────────
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isStartingCall
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text("Connecting...", style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : Stack(
              children: [
                if (_isInCall) _buildLiveCallView() else _buildWaitingView(),
                if (_errorMessage != null)
                  Positioned(
                    top: 100,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error, color: Colors.red.shade200),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_errorMessage!,
                                  style: const TextStyle(color: Colors.white))),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () =>
                                setState(() => _errorMessage = null),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  // ─── LIVE CALL VIEW ────────────────────────────────────────────────────────
  Widget _buildLiveCallView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_isVoiceOnly)
          _buildAudioCallScreen()
        else if (_remoteUid != null && _remoteUserJoined)
          VideoCallScreen(
            key: _remoteVideoKey,
            session: widget.session ?? ConsultationSessionResponse(),
            isCustomer: widget.isCustomer,
            participantName: widget.isCustomer ? "Practitioner" : "Customer",
            engine: _engine!,
            remoteUid: _remoteUid,
            channelName: _channelName,
            micMuted: _micMuted,
            videoMuted: _videoMuted,
            remoteJoined: _remoteUserJoined,
            onMicToggle: _toggleMic,
            onCameraToggle: _toggleCamera,
            onEndCall: _leaveCall,
          )
        else if (_remoteUserJoined)
          Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 20),
                  Text("Waiting for video...",
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          )
        else
          _buildWaitingScreen(),
      ],
    );
  }

  // ─── AUDIO CALL SCREEN ─────────────────────────────────────────────────────
  Widget _buildAudioCallScreen() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 1500),
                    width: _remoteUserJoined ? 100 : 80,
                    height: _remoteUserJoined ? 100 : 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: _remoteUserJoined ? 3 : 2,
                      ),
                    ),
                  ),
                  Icon(
                    _remoteUserJoined ? Icons.mic : Icons.phone,
                    size: _remoteUserJoined ? 60 : 50,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text(
              widget.isCustomer ? "Practitioner" : "Customer",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _remoteUserJoined
                    ? " "
                    : "${widget.isCustomer ? "Calling" : "Waiting for call"}...",
                key: ValueKey(_remoteUserJoined),
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 18),
              ),
            ),
            const Spacer(),
            Container(
              margin: const EdgeInsets.all(30),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAudioControlButton(
                    icon: _micMuted ? Icons.mic_off : Icons.mic,
                    color: _micMuted ? Colors.grey : Colors.cyan,
                    onPressed: _toggleMic,
                  ),
                  _buildAudioControlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onPressed: _leaveCall,
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.4), blurRadius: 20, spreadRadius: 4),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  // ─── WAITING VIEW (before joining) ─────────────────────────────────────────
  Widget _buildWaitingView() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _pulseAnimation,
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: const Icon(Icons.video_call,
                        size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  widget.isCustomer
                      ? "Connecting to Practitioner"
                      : "Waiting for Customer",
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade900.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMessage!,
                        style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 20),
                ],
                ElevatedButton.icon(
                  onPressed: _isStartingCall ? null : _startCall,
                  icon: const Icon(Icons.video_call),
                  label: Text(_isStartingCall ? "Connecting..." : "Join Call"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── WAITING SCREEN (joined, remote not yet connected) ─────────────────────
  Widget _buildWaitingScreen() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_call, color: Colors.white54, size: 80),
            const SizedBox(height: 24),
            Text(
              "Waiting for ${widget.isCustomer ? 'Practitioner' : 'Customer'}...",
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 32),
            Text(
              "Session #${widget.session?.sessionNumber ?? 'N/A'}",
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cleanupEngine();
    _pulseController.dispose();
    _messageController.dispose();
    // Only disconnect websocket if it was used (audio/video mode)
    if (widget.callType != CallType.chat) _chatService.disconnect();
    super.dispose();
  }
}
