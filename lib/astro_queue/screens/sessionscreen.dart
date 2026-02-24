import 'dart:async';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';

class SessionScreen extends StatefulWidget {
  final ConsultationSessionResponse? session;
  final bool isCustomer;
  final String? channelName;

  const SessionScreen({
    super.key,
    this.session,
    required this.isCustomer,
    this.channelName,
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

  int? _remoteUid;
  SessionStatus _currentStatus = SessionStatus.waiting;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final TextEditingController _messageController = TextEditingController();
  final List<String> _messages = [];

  // Hardcoded channel as requested
  static const String _channelName = "astro_channel_123";

  // Fixed UIDs for testing (you can make dynamic later)
  static const int _uidCustomer = 1001;
  static const int _uidPractitioner = 1002;

  static const String _appId = "1a799cf30b064aabbd16218fa05b4014";

  bool _isStartingCall = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation =
        Tween<double>(begin: 0.9, end: 1.1).animate(_pulseController);
    _pulseController.repeat(reverse: true);

    debugPrint(
      "SessionScreen init → Channel: $_channelName | "
      "UID: ${widget.isCustomer ? _uidCustomer : _uidPractitioner} | "
      "Role: ${widget.isCustomer ? 'Customer' : 'Practitioner'}",
    );
  }

  Future<String> _fetchAgoraToken() async {
    final uid = widget.isCustomer ? _uidCustomer : _uidPractitioner;

    try {
      // FIXED: Correct URL – use channel and uid properly
      final url =
          "http://localhost:16679/api/agora/token?channelName=$_channelName&uid=$uid";

      debugPrint("Fetching Agora token → $url");

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );

      debugPrint(
        "Token response → Status: ${response.statusCode} | "
        "Body length: ${response.body.length} | "
        "Starts with: ${response.body.substring(0, response.body.length.clamp(0, 15))}...",
      );

      if (response.statusCode == 200) {
        final token = response.body.trim();

        if (token.isEmpty) throw Exception("Empty token from server");

        if (!token.startsWith('007')) {
          debugPrint(
              "Warning: Token does not start with '007' (not v2 format)");
        }

        debugPrint("Token received successfully (length: ${token.length})");
        return token;
      } else {
        throw Exception(
            "Token server error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint("Token fetch failed: $e");
      throw Exception("Failed to fetch token: $e");
    }
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
        throw Exception("Camera and/or Microphone permission denied");
      }

      await _cleanupEngine();

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      await _engine!.enableVideo();
      await _engine!.enableLocalVideo(true);
      await _engine!.startPreview();

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint(
                "JOIN SUCCESS → Channel: ${connection.channelId} | UID: ${connection.localUid}");
            setState(() {
              _localUserJoined = true;
              _isInCall = true;
              _currentStatus = SessionStatus.inProgress;
            });
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("REMOTE USER JOINED → UID: $remoteUid");
            setState(() {
              _remoteUid = remoteUid;
              _remoteUserJoined = true;
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            debugPrint(
                "REMOTE USER OFFLINE → UID: $remoteUid | Reason: $reason");
            if (_remoteUid == remoteUid) {
              setState(() {
                _remoteUid = null;
                _remoteUserJoined = false;
                _remoteVideoPublished = false;
              });
            }
          },
          onRemoteVideoStateChanged: (
            RtcConnection connection,
            int remoteUid,
            RemoteVideoState state,
            RemoteVideoStateReason reason,
            int elapsed,
          ) {
            debugPrint("Remote video state → UID: $remoteUid | State: $state");
            if (_remoteUid == remoteUid) {
              setState(() {
                _remoteVideoPublished =
                    state == RemoteVideoState.remoteVideoStateDecoding;
              });
            }
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("Agora SDK error → Code: $err | Message: $msg");
            setState(() {
              _errorMessage = "Agora SDK error: $err ($msg)";
            });
          },
        ),
      );

      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // ──────────────────────────────────────────────
      // TEMPORARY HARDCODED TOKEN – PASTE YOUR GENERATED TOKEN HERE
      // Get it from: https://www.agora.io/en/tools/token-generator/
      // Channel: astro_channel_123
      // UID: 1001 (customer) or 1002 (practitioner)
      // Role: Publisher
      // ──────────────────────────────────────────────
      final token =
          "007eJxTYGDeLj3zavalwN1//HeejmVdtG6jndjmTnmlRi/l95PFzxxUYDBMNLe0TE4zNkgyMDNJTExKSjE0MzK0SEs0ME0yMTA00ZGZk9kQyMiQ0F/MyMgAgSC+IENicUlRfnxyRmJeXmpOvKGRMQMDAPVdI0k="; // ← PASTE YOUR REAL TOKEN HERE

      // Optional: uncomment next line if you want to see what token is used
      // debugPrint("Using temporary hardcoded token: ${token.substring(0, 20)}...");

      debugPrint("╔════════════════════════════════════════════╗");
      debugPrint("║           Joining Agora Channel            ║");
      debugPrint("╠════════════════════════════════════════════╣");
      debugPrint("║ Channel      : $_channelName");
      debugPrint(
          "║ UID          : ${widget.isCustomer ? _uidCustomer : _uidPractitioner}");
      debugPrint("║ Token length : ${token.length}");
      debugPrint(
          "║ Token preview: ${token.substring(0, 20)}...${token.substring(token.length - 10)}");
      debugPrint("╚════════════════════════════════════════════╝");

      await _engine!.joinChannel(
        token: token,
        channelId: _channelName,
        uid: widget.isCustomer ? _uidCustomer : _uidPractitioner,
        options: const ChannelMediaOptions(
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
    } catch (e) {
      debugPrint("Failed to start call: $e");
      setState(() {
        _errorMessage =
            "Failed to start call: ${e.toString().replaceFirst('Exception: ', '').trim()}";
      });
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
    } catch (e) {
      debugPrint("Engine cleanup error: $e");
    }
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
      _currentStatus = SessionStatus.waiting;
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _toggleMic() async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(!_micMuted);
    setState(() => _micMuted = !_micMuted);
  }

  Future<void> _toggleCamera() async {
    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(!_videoMuted);
    setState(() => _videoMuted = !_videoMuted);
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.insert(0, "You: $text");
    });
    _messageController.clear();
  }

  @override
  void dispose() {
    _cleanupEngine();
    _pulseController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _isInCall ? _buildLiveCallView() : _buildWaitingView(),
          if (_errorMessage != null)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Material(
                    color: Colors.red.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
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
            padding: const EdgeInsets.all(24.0),
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
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.25),
                          Colors.white.withOpacity(0.1)
                        ],
                      ),
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
                const SizedBox(height: 16),
                Text(
                  widget.isCustomer
                      ? (widget.session?.consultant?.name ??
                          "Premium Practitioner")
                      : (widget.session?.customer?.name ?? "Customer"),
                  style: TextStyle(
                      fontSize: 20, color: Colors.white.withOpacity(0.9)),
                ),
                const SizedBox(height: 60),
                ElevatedButton.icon(
                  onPressed: _isStartingCall ? null : _startCall,
                  icon: const Icon(Icons.video_call, size: 28),
                  label: Text(
                    _isStartingCall ? "Connecting..." : "Start Video Call",
                    style: const TextStyle(fontSize: 18),
                  ),
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
                if (_remoteUserJoined) ...[
                  const CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 6),
                  const SizedBox(height: 24),
                  const Text("Waiting for video...",
                      style: TextStyle(color: Colors.white, fontSize: 22)),
                ] else ...[
                  const Icon(Icons.videocam_off,
                      size: 120, color: Colors.white54),
                  const SizedBox(height: 24),
                  const Text("Waiting for other participant...",
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                  const SizedBox(height: 12),
                  Text("Channel: $_channelName",
                      style: const TextStyle(color: Colors.white70)),
                ],
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
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _videoMuted
                    ? Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.videocam_off,
                                  color: Colors.white70, size: 40),
                              SizedBox(height: 8),
                              Text("Camera Off",
                                  style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                      )
                    : AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: _engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
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
          colors: _currentStatus == SessionStatus.inProgress
              ? [Colors.green.shade700, Colors.green.shade900]
              : [const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Icon(
            _currentStatus == SessionStatus.inProgress
                ? Icons.videocam
                : Icons.hourglass_bottom,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _currentStatus == SessionStatus.inProgress ? "LIVE" : "WAITING",
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          Text(
            _remoteUserJoined ? "Connected" : "Channel: $_channelName",
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_messages.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              margin: const EdgeInsets.only(bottom: 16),
              child: ListView.builder(
                reverse: true,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _messages[index],
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildControlButton(
                  icon: _videoMuted ? Icons.videocam_off : Icons.videocam,
                  onPressed: _toggleCamera,
                  color: _videoMuted ? Colors.grey : Colors.purple,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: _micMuted ? Icons.mic_off : Icons.mic,
                  onPressed: _toggleMic,
                  color: _micMuted ? Colors.grey : Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildControlButton(
                  icon: Icons.call_end,
                  onPressed: _leaveCall,
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      height: 50,
      width: 70,
      child: RawMaterialButton(
        onPressed: onPressed,
        elevation: 3,
        fillColor: color,
        shape: const CircleBorder(),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
