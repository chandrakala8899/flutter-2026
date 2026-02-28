import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_learning/astro_queue/screens/audio_call.dart';
import 'package:flutter_learning/astro_queue/screens/chat_screen.dart';
import 'package:flutter_learning/astro_queue/screens/vedio_call_screen.dart';
import 'package:flutter_learning/astro_queue/services/chat_service.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

enum CallType { chat, audio, video }

class SessionScreen extends StatefulWidget {
  final ConsultationSessionResponse? session;
  final bool isCustomer;
  final CallType callType;

  const SessionScreen({
    super.key,
    this.session,
    required this.isCustomer,
    required this.callType,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  RtcEngine? _engine;
  late ChatService _chatService;

  // Video/Audio states
  bool _localUserJoined = false;
  bool _remoteUserJoined = false;
  int? _remoteUid;
  bool _micMuted = false;
  bool _videoMuted = false;
  bool _isVoiceOnly = false;
  bool _isStartingCall = false;

  String get _channelName =>
      widget.session?.sessionId?.toString() ?? "astro_channel_123";

  static const int _uidCustomer = 1;
  static const int _uidPractitioner = 2;
  static const String _appId = "1a799cf30b064aabbd16218fa05b4014";

  @override
  void initState() {
    super.initState();

    // 🔥 Initialize Chat Service - will be used by ChatScreen
    _chatService = ChatService(
      onMessageReceived: (data) {
        print("📨 New chat message received: ${data['message']}");
      },
    );

    // 🔥 Connect chat if session exists
    if (widget.session != null) {
      _chatService.connect(
        (widget.isCustomer ? _uidCustomer : _uidPractitioner).toString(),
        sessionId: widget.session!.sessionId!,
      );
    }

    // 🔥 Start video/audio call
    if (widget.callType == CallType.audio ||
        widget.callType == CallType.video) {
      Future.delayed(const Duration(milliseconds: 500), _startCall);
    }
  }

  Future<String> _fetchAgoraToken() async {
    if (widget.session == null) return "temp-token";

    try {
      final joinData = await http
          .get(
            Uri.parse(
                "http://localhost:16679/api/agora/token?channelName=$_channelName&uid=${widget.isCustomer ? _uidCustomer : _uidPractitioner}"),
          )
          .timeout(const Duration(seconds: 10));

      if (joinData.statusCode == 200) {
        final token = joinData.body.trim();
        if (token.length > 100) return token;
      }
    } catch (_) {}

    return "007eJxTYMh/8rSYV2DRDN3VRmmaftfL2/yO2zDfjAkUds8+VH21XVqBwTDR3NIyOc3YIMnAzCQxMSkpxdDMyNAiLdHANMnEwNBk6d35mQ2BjAzvf6cxMzJAIIgvyJBYXFKUH5+ckZiXl5oTb2hkzMAAALm9I+M=";
  }

  Future<void> _startCall() async {
    if (_isStartingCall) return;
    _isStartingCall = true;
    setState(() {});

    try {
      final statuses =
          await [Permission.camera, Permission.microphone].request();
      if (statuses[0] != PermissionStatus.granted ||
          statuses[1] != PermissionStatus.granted) {
        throw Exception("Camera & Microphone permissions required");
      }

      await _cleanupEngine();

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _engine!.enableAudio();

      if (widget.callType == CallType.audio) {
        _isVoiceOnly = true;
      } else {
        await _engine!.enableVideo();
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
      }

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) => setState(() {
          _localUserJoined = true;
        }),
        onUserJoined: (_, uid, __) => setState(() {
          _remoteUid = uid;
          _remoteUserJoined = true;
        }),
        onUserOffline: (_, uid, __) {
          if (_remoteUid == uid) setState(() => _remoteUserJoined = false);
        },
        onError: (err, msg) {
          debugPrint("Agora Error: $err - $msg");
        },
      ));

      final token = await _fetchAgoraToken();
      await _engine!.joinChannel(
        token: token,
        channelId: _channelName,
        uid: widget.isCustomer ? _uidCustomer : _uidPractitioner,
        options: ChannelMediaOptions(
          publishCameraTrack: !_isVoiceOnly,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Call failed: $e")),
      );
    } finally {
      _isStartingCall = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _cleanupEngine() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    await _engine!.release();
    _engine = null;
  }

  Future<void> _leaveCall() async {
    await _cleanupEngine();
    _chatService.disconnect();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session Ended")),
      );
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

  void _openFullChat() {
    if (widget.session == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          session: widget.session!,
          isCustomer: widget.isCustomer,
          chatService: _chatService,
          initialMessages: [], 
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cleanupEngine();
    _chatService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String participantName =
        widget.isCustomer ? "Practitioner" : "Customer";

    // 🔥 CHAT MODE - Fullscreen ChatScreen
    if (widget.callType == CallType.chat) {
      return ChatScreen(
        session: widget.session!,
        isCustomer: widget.isCustomer,
        chatService: _chatService,
        initialMessages: [],
      );
    }

    // 🔥 AUDIO/VIDEO CALL with Chat FAB
    return Scaffold(
      body: widget.callType == CallType.audio
          ? AudioCallScreen(
              session: widget.session!,
              isCustomer: widget.isCustomer,
              participantName: participantName,
              engine: _engine,
              micMuted: _micMuted,
              onMicToggle: _toggleMic,
              onEndCall: _leaveCall,
            )
          : VideoCallScreen(
              session: widget.session!,
              isCustomer: widget.isCustomer,
              participantName: participantName,
              engine: _engine,
              remoteUid: _remoteUid,
              channelName: _channelName,
              micMuted: _micMuted,
              videoMuted: _videoMuted,
              remoteJoined: _remoteUserJoined,
              onMicToggle: _toggleMic,
              onCameraToggle: _toggleCamera,
              onEndCall: _leaveCall,
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFullChat, 
        child: const Icon(Icons.chat_bubble_outline),
        backgroundColor: Colors.deepPurple,
        tooltip: "Open Chat",
      ),
    );
  }
}
