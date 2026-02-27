import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_learning/astro_queue/screens/agora_chat_ui.dart'; // ← AgoraChatScreen
import 'package:flutter_learning/astro_queue/screens/audio_call.dart';
import 'package:flutter_learning/astro_queue/screens/vedio_call_screen.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';

enum CallType {
  chat,
  audio,
  video,
}

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

  static const String _channelName = "astro_channel_123";
  static const int _uidCustomer = 1;
  static const int _uidPractitioner = 2;
  static const String _appId = "1a799cf30b064aabbd16218fa05b4014";

  bool _isStartingCall = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController);
    _pulseController.repeat(reverse: true);

    // Only start RTC call for audio/video
    if (widget.callType == CallType.audio ||
        widget.callType == CallType.video) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (widget.callType == CallType.audio) {
          _isVoiceOnly = true;
        }
        _startCall();
      });
    }
  }

  Future<String> _fetchAgoraToken() async {
    final uid = widget.isCustomer ? _uidCustomer : _uidPractitioner;
    try {
      final url =
          "http://localhost:16679/api/agora/token?channelName=$_channelName&uid=$uid";
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final token = response.body.trim();
        if (token.length > 100) return token;
      }
    } catch (_) {}

    // ================================================================
    // PASTE YOUR NEW LONG TOKEN HERE (from agora.io token generator)
    // It must be 180+ characters long!
    return "007eJxTYMh/8rSYV2DRDN3VRmmaftfL2/yO2zDfjAkUds8+VH21XVqBwTDR3NIyOc3YIMnAzCQxMSkpxdDMyNAiLdHANMnEwNBk6d35mQ2BjAzvf6cxMzJAIIgvyJBYXFKUH5+ckZiXl5oTb2hkzMAAALm9I+M=";
    // ================================================================
  }

  // Add this method to SessionScreen (same pattern as _fetchAgoraToken)
  Future<String> _fetchChatToken() async {
    final int uid = widget.isCustomer ? _uidCustomer : _uidPractitioner;
    final String chatChannel =
        widget.session?.sessionId?.toString() ?? _channelName;

    try {
      final url =
          "http://localhost:16679/api/agora/chat-token?chatChannel=$chatChannel&userId=${uid.toString()}";
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final token = response.body.trim();
        if (token.length > 100) {
          print("✅ Chat token received: ${token.length} chars");
          return token;
        }
      }
    } catch (e) {
      print("❌ Chat token failed: $e");
    }

    // 🔥 TEMPORARY TOKEN GENERATOR (Like your RTC fallback)
    return _generateTemporaryChatToken(uid.toString());
  }

  /// 🔥 NEW: Generate TEMP CHAT TOKENS (Copy your RTC fallback pattern)
  String _generateTemporaryChatToken(String userId) {
    print("🆘 Using TEMPORARY Chat token for $userId");

    // Generate NEW temp tokens using your App ID + Certificate
    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int expireTime = currentTime + 7200; // 2 hours

    final Map<String, dynamic> payload = {
      "appId": "1a799cf30b064aabbd16218fa05b4014",
      "userId": userId,
      "issueTs": currentTime,
      "expireTs": expireTime,
      "chatroom": widget.session?.sessionId ?? "session_default"
    };

    final String payloadString = jsonEncode(payload);
    print("🔥 Chat payload: $payloadString");

    // HMAC-SHA256 (same as backend)
    final appCertificate = "f883c7e82d934cc8a3d3adbb858bc782";
    final keyBytes = utf8.encode(appCertificate);
    final hmac = Hmac(sha256, keyBytes);
    final signature = hmac.convert(utf8.encode(payloadString)).bytes;

    final token = base64Url.encode(signature);
    print("✅ TEMP Chat token: $token (${token.length} chars)");
    return token;
  }

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

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      await _engine!.enableAudio();

      if (_isVoiceOnly) {
        await _engine!.disableVideo();
      } else {
        await _engine!.enableVideo();
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
      }

      _engine!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) => setState(() {
          _localUserJoined = true;
          _isInCall = true;
          _currentStatus = SessionStatus.inProgress;
        }),
        onUserJoined: (_, remoteUid, __) => setState(() {
          _remoteUid = remoteUid;
          _remoteUserJoined = true;
        }),
        onUserOffline: (_, remoteUid, __) {
          if (_remoteUid == remoteUid) {
            setState(() {
              _remoteUid = null;
              _remoteUserJoined = false;
              _remoteVideoPublished = false;
            });
          }
        },
        onRemoteVideoStateChanged: (_, remoteUid, state, __, ___) {
          if (_remoteUid == remoteUid) {
            setState(() => _remoteVideoPublished =
                state == RemoteVideoState.remoteVideoStateDecoding);
          }
        },
        onError: (err, msg) {
          debugPrint("Agora Error: $err - $msg");
          setState(() => _errorMessage = "Agora Error: $err");
        },
      ));

      final token = await _fetchAgoraToken();
      await _engine!.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicHighQuality,
        scenario: AudioScenarioType.audioScenarioChatroom,
      );

      await _engine!.joinChannel(
        token: token,
        channelId: _channelName,
        uid: widget.isCustomer ? _uidCustomer : _uidPractitioner,
        options: ChannelMediaOptions(
          publishCameraTrack: !_isVoiceOnly,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      setState(() => _errorMessage = "Failed to start call: $e");
      await _cleanupEngine();
    } finally {
      _isStartingCall = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _cleanupEngine() async {
    if (_engine == null) return;
    try {
      await _engine!.leaveChannel();
      await _engine!.stopPreview();
      await _engine!.release(sync: true);
    } catch (_) {}
    _engine = null;
  }

  Future<void> _leaveCall() async {
    await _cleanupEngine();
    setState(() {
      _isInCall = false;
      _localUserJoined = false;
      _remoteUserJoined = false;
      _remoteVideoPublished = false;
      _remoteUid = null;
      _currentStatus = SessionStatus.completed;
    });
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
    await _engine!.muteLocalVideoStream(!_videoMuted);
    setState(() => _videoMuted = !_videoMuted);
  }

  Future<void> _toggleVoiceMode() async {
    if (_engine == null) return;

    setState(() => _isVoiceOnly = !_isVoiceOnly);

    if (_isVoiceOnly) {
      await _engine!.muteLocalVideoStream(true);
      await _engine!.disableVideo();
      await _engine!.stopPreview();
    } else {
      await _engine!.enableVideo();
      await _engine!.enableLocalVideo(true);
      await _engine!.muteLocalVideoStream(false);
      await _engine!.startPreview();
    }
  }

  // ====================== CHAT BUTTON (opens Agora Chat UIKit) ======================
  void _openChat() {
    if (widget.session == null) return;

    final String peerUserId = widget.isCustomer
        ? (widget.session!.consultant?.id?.toString() ??
            "practitioner_${widget.session!.sessionId ?? 'default'}")
        : (widget.session!.customer?.id?.toString() ??
            "customer_${widget.session!.sessionId ?? 'default'}");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.95,
        minChildSize: 0.5,
        maxChildSize: 0.98,
        builder: (context, scrollController) => AgoraChatScreen(
          // session: widget.session,
          isCustomer: widget.isCustomer,
          currentUserId:
              (widget.isCustomer ? _uidCustomer : _uidPractitioner).toString(),
          peerUserId: peerUserId,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cleanupEngine();
    _pulseController.dispose();
    super.dispose();
  }

  // ====================== BUILD METHOD (CLEAN) ======================
  @override
  Widget build(BuildContext context) {
    // ====================== FULL CHAT SCREEN ======================
    if (widget.callType == CallType.chat) {
      final String peerUserId = widget.isCustomer
          ? (widget.session?.consultant?.id?.toString() ??
              "practitioner_${widget.session?.sessionId ?? 'default'}")
          : (widget.session?.customer?.id?.toString() ??
              "customer_${widget.session?.sessionId ?? 'default'}");

      return AgoraChatScreen(
        // session: widget.session,
        isCustomer: widget.isCustomer,
        currentUserId:
            (widget.isCustomer ? _uidCustomer : _uidPractitioner).toString(),
        peerUserId: peerUserId,
      );
    }

    // ====================== AUDIO / VIDEO CALL ======================
    return Scaffold(
      body: widget.callType == CallType.audio
          ? AudioCallScreen(
              session: widget.session!,
              isCustomer: widget.isCustomer,
              engine: _engine,
            )
          : VideoCallScreen(
              session: widget.session!,
              isCustomer: widget.isCustomer,
              engine: _engine,
            ),
      // Optional floating chat button for audio/video
      floatingActionButton: widget.callType != CallType.chat
          ? FloatingActionButton(
              onPressed: _openChat,
              child: const Icon(Icons.chat_bubble_outline),
              backgroundColor: Colors.deepPurple,
            )
          : null,
    );
  }
}
