import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_learning/astro_queue/screens/audio_call.dart';
import 'package:flutter_learning/astro_queue/screens/chat_screen.dart';
import 'package:flutter_learning/astro_queue/screens/vedio_call_screen.dart';
import 'package:flutter_learning/astro_queue/services/chat_service.dart';
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

  final TextEditingController _messageController = TextEditingController();

  static const String _channelName = "astro_channel_123";
  static const int _uidCustomer = 1;
  static const int _uidPractitioner = 2;
  static const String _appId = "1a799cf30b064aabbd16218fa05b4014";

  bool _isStartingCall = false;
  String? _errorMessage;

  late ChatService _chatService;
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();

    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulseAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController);
    _pulseController.repeat(reverse: true);

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

    if (widget.callType == CallType.audio ||
        widget.callType == CallType.video) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (widget.callType == CallType.audio) {
          _isVoiceOnly = true;
        }
        _startCall();
      });
    }
    _getChatHistory();
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

      // 🔥 FIXED AUDIO + VIDEO INITIALIZATION
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
          publishCameraTrack: !_isVoiceOnly, // 🔥 FIXED
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
      // Switch to Audio-only
      await _engine!.muteLocalVideoStream(true);
      await _engine!.disableVideo();
      await _engine!.stopPreview();
    } else {
      // Switch back to Video
      await _engine!.enableVideo();
      await _engine!.enableLocalVideo(true);
      await _engine!.muteLocalVideoStream(false);
      await _engine!.startPreview();
    }
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

  void _openChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildChatBottomSheet(),
    );
  }

  Widget _buildChatBottomSheet() {
    final participantName =
        widget.isCustomer ? "Practitioner Chat" : "Customer Chat";

    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF2F4F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.95,
          minChildSize: 0.3,
          maxChildSize: 0.98,
          builder: (context, scrollController) {
            return Column(
              children: [
                /// ⭐ Header
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade600,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, color: Colors.white),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          participantName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.white),
                      )
                    ],
                  ),
                ),

                /// ⭐ Messages
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: AssetImage("assets/chat_bg.png"),
                      ),
                    ),
                    child: _messages.isEmpty
                        ? const Center(
                            child: Text("Start conversation..."),
                          )
                        : ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(18),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              final isMe = msg['isMe'] == true;

                              return Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(14),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.75,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isMe ? Colors.deepPurple : Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: const [
                                      BoxShadow(
                                        blurRadius: 3,
                                        color: Colors.black12,
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      /// Sender Name
                                      Text(
                                        msg['sender'] ?? "Unknown",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.grey,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      /// Message
                                      Text(
                                        msg['text'] ?? "",
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      /// Time
                                      if (msg['time'] != null)
                                        Text(
                                          msg['time'],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isMe
                                                ? Colors.white60
                                                : Colors.grey,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                /// ⭐ Bottom Input Area
                Container(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                    left: 14,
                    right: 14,
                    top: 10,
                  ),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: widget.isCustomer
                                ? "Ask your question..."
                                : "Write answer...",
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      CircleAvatar(
                        backgroundColor: Colors.deepPurple,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      )
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getChatHistory() async {
    if (widget.session == null) return [];

    final response = await http.get(
      Uri.parse("http://localhost:16679/api/chat/${widget.session!.sessionId}"),
    );

    if (response.statusCode != 200) return [];

    final List data = json.decode(response.body);

    return data
        .map((msg) => {
              "id": msg["id"],
              "sender": msg["senderName"] ?? "Unknown",
              "text": msg["message"] ?? "",
              "isMe": msg["senderId"] ==
                  (widget.isCustomer ? _uidCustomer : _uidPractitioner),
            })
        .toList()
        .reversed
        .toList();
  }

  @override
  void dispose() {
    _cleanupEngine();
    _pulseController.dispose();
    _messageController.dispose();
    _chatService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.callType == CallType.chat) {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _getChatHistory(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return ChatScreen(
            session: widget.session!,
            isCustomer: widget.isCustomer,
            chatService: _chatService,
            initialMessages: snapshot.data!,
          );
        },
      );
    }
    if (widget.callType == CallType.audio) {
      return AudioCallScreen(
        session: widget.session!,
        isCustomer: widget.isCustomer,
        engine: _engine,
      );
    }

    return VideoCallScreen(
      session: widget.session!,
      isCustomer: widget.isCustomer,
      engine: _engine,
    );
  }

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
                    child:
                        const Icon(Icons.person, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  widget.isCustomer
                      ? "Connecting to Practitioner"
                      : "Waiting for Customer",
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                ElevatedButton.icon(
                  onPressed: _isStartingCall ? null : _startCall,
                  icon: const Icon(Icons.video_call),
                  label: Text(
                      _isStartingCall ? "Connecting..." : "Start Video Call"),
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

  Widget _buildLiveCallView() {
    if (_isVoiceOnly) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.phone_in_talk,
                  size: 120, color: Colors.greenAccent),
              const SizedBox(height: 30),
              const Text("Voice Call Active",
                  style: TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              Text(
                  "Connected with ${widget.isCustomer ? 'Practitioner' : 'Customer'}",
                  style: const TextStyle(color: Colors.white70, fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_remoteUid != null && _remoteVideoPublished)
          AgoraVideoView(
            controller: VideoViewController.remote(
              rtcEngine: _engine!,
              canvas: VideoCanvas(uid: _remoteUid),
              connection: RtcConnection(channelId: _channelName),
            ),
          )
        else
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_remoteUserJoined)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  const Icon(Icons.videocam_off,
                      size: 120, color: Colors.white54),
                const SizedBox(height: 20),
                Text(
                    _remoteUserJoined
                        ? "Waiting for video..."
                        : "Waiting for other participant...",
                    style: const TextStyle(color: Colors.white, fontSize: 20)),
              ],
            ),
          ),
        if (_localUserJoined)
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              width: 140,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _videoMuted
                    ? Container(
                        color: Colors.grey[900],
                        child: const Center(
                            child: Text("Camera Off",
                                style: TextStyle(color: Colors.white70))),
                      )
                    : AgoraVideoView(
                        controller: VideoViewController(
                            rtcEngine: _engine!,
                            canvas: const VideoCanvas(uid: 0)),
                      ),
              ),
            ),
          ),
        Positioned(top: 16, left: 16, right: 16, child: _buildStatusBar()),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildControls()),
      ],
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.green.shade900]),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Icon(_isVoiceOnly ? Icons.phone_in_talk : Icons.videocam,
              color: Colors.white),
          const SizedBox(width: 8),
          Text(_isVoiceOnly ? "VOICE CALL" : "VIDEO CALL",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(_remoteUserJoined ? "Connected" : "Connecting...",
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
              icon: _isVoiceOnly ? Icons.videocam : Icons.phone_in_talk,
              onPressed: _toggleVoiceMode,
              color: Colors.teal),
          _buildControlButton(
              icon: _micMuted ? Icons.mic_off : Icons.mic,
              onPressed: _toggleMic,
              color: _micMuted ? Colors.grey : Colors.orange),
          if (!_isVoiceOnly)
            _buildControlButton(
                icon: _videoMuted ? Icons.videocam_off : Icons.videocam,
                onPressed: _toggleCamera,
                color: _videoMuted ? Colors.grey : Colors.purple),
          _buildControlButton(
              icon: Icons.chat_bubble_outline,
              onPressed: _openChat,
              color: Colors.deepPurple),
          _buildControlButton(
              icon: Icons.call_end, onPressed: _leaveCall, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon,
      required VoidCallback onPressed,
      required Color color}) {
    return SizedBox(
      height: 55,
      width: 55,
      child: RawMaterialButton(
        onPressed: onPressed,
        elevation: 4,
        fillColor: color,
        shape: const CircleBorder(),
        child: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }
}
