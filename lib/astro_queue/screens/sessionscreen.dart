import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';

class SessionScreen extends StatefulWidget {
  final ConsultationSessionResponse? session;
  final bool isCustomer;

  const SessionScreen({super.key, this.session, required this.isCustomer});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen>
    with TickerProviderStateMixin {
  RtcEngine? _engine;
  bool _isInCall = false;
  bool _localUserJoined = false;
  bool _remoteUserJoined = false;
  bool _micMuted = false;
  bool _videoMuted = false;
  int? _remoteUid;
  SessionStatus _currentStatus = SessionStatus.waiting;
  List<String> messages = [];
  final TextEditingController _messageController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const String _appId = "8dd43ad4ed32475c914486f4c70bb05d";
  late String _channelName;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    _channelName = "astro_${DateTime.now().millisecondsSinceEpoch}";
    _initializeSession();
    _startWaitingScreen();
  }

  void _initializeSession() {
    if (widget.session != null) {
      _currentStatus = widget.session!.status ?? SessionStatus.waiting;
      _channelName =
          "astro_${widget.session!.consultant?.id ?? DateTime.now().millisecondsSinceEpoch}";
    }
  }

  void _startWaitingScreen() {
    // Stay in waiting screen initially
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        debugPrint("🎥 Starting Agora initialization...");
        _initAgora();
      }
    });
  }

  Future<void> _initAgora() async {
    try {
      await [Permission.camera, Permission.microphone].request();

      _engine = createAgoraRtcEngine();
      await _engine!.initialize(const RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("✅ Local user joined");
            setState(() => _localUserJoined = true);
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("✅ Practitioner joined: $remoteUid");
            setState(() {
              _remoteUid = remoteUid;
              _remoteUserJoined = true;
              _currentStatus = SessionStatus.inProgress;
              _isInCall = true;
              messages.add(
                  "${widget.session?.consultant?.name ?? 'Practitioner'} joined the call!");
            });
          },
          onUserOffline: (RtcConnection connection, int remoteUid,
              UserOfflineReasonType reason) {
            debugPrint("❌ Practitioner left");
            setState(() {
              _remoteUid = null;
              _remoteUserJoined = false;
              _currentStatus = SessionStatus.waiting;
              messages.add("Practitioner left the call");
            });
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("Agora Error: $err - $msg");
          },
        ),
      );

      await _engine!.enableVideo();
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);

      // Join channel to wait for practitioner
      await _engine!.joinChannel(
        token: '',
        channelId: _channelName,
        uid: 0,
        options: const ChannelMediaOptions(),
      );
    } catch (e) {
      debugPrint("❌ Agora Error: $e - Demo mode activated");
    }
  }

  Future<void> _toggleMute() async {
    if (_engine == null) return;
    await _engine!.muteLocalAudioStream(!_micMuted);
    setState(() => _micMuted = !_micMuted);
  }

  Future<void> _toggleVideo() async {
    if (_engine == null) return;
    await _engine!.muteLocalVideoStream(!_videoMuted);
    setState(() => _videoMuted = !_videoMuted);
  }

  Future<void> _leaveCall() async {
    if (_engine == null) return;
    await _engine!.leaveChannel();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pulseController.dispose();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main Content
          if (_remoteUserJoined && _isInCall) _buildLiveCallScreen(),
          if (!_remoteUserJoined || !_isInCall)
            _buildProfessionalWaitingScreen(),

          // Status Bar (always visible)
          Positioned(top: 50, left: 20, right: 20, child: _buildStatusBar()),

          // Controls (only during call)
          if (_remoteUserJoined && _isInCall) _buildProfessionalControls(),
        ],
      ),
    );
  }

  Widget _buildProfessionalWaitingScreen() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6), Color(0xFF60A5FA)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 100),
            // Pulsing astrologer avatar
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white.withOpacity(0.2),
                    Colors.white.withOpacity(0.1),
                  ]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 40),

            Text(
              "Connecting to Astrologer",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 10),
            Text(
              widget.session?.consultant?.name ?? "Premium Astrologer",
              style:
                  TextStyle(fontSize: 20, color: Colors.white.withOpacity(0.9)),
            ),
            SizedBox(height: 60),

            // Status Card
            Container(
              margin: EdgeInsets.symmetric(horizontal: 40),
              padding: EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.white.withOpacity(0.9)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 30,
                    offset: Offset(0, 15),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(Icons.hourglass_empty, size: 50, color: Colors.orange),
                  SizedBox(height: 20),
                  Text(
                    "WAITING",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[700]!,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 15),
                  Text(
                    "Astrologer will join shortly\nShare channel: $_channelName",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Text("Ready for Video Call",
                          style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCallScreen() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Remote Video (Full screen)
          if (_remoteUid != null)
            Center(
              child: AgoraVideoView(
                controller: VideoViewController.remote(
                  rtcEngine: _engine!,
                  canvas: VideoCanvas(uid: _remoteUid!),
                  connection: RtcConnection(channelId: _channelName),
                ),
              ),
            )
          else
            Container(
              color: Colors.grey[900],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam, size: 80, color: Colors.white60),
                    SizedBox(height: 20),
                    Text("Astrologer Video",
                        style: TextStyle(color: Colors.white, fontSize: 20)),
                  ],
                ),
              ),
            ),

          // Local Video (PiP)
          if (_localUserJoined)
            Positioned(
              top: 120,
              right: 20,
              child: Container(
                width: 140,
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 4),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _videoMuted
                      ? Container(
                          color: Colors.grey[800],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam_off,
                                  size: 40, color: Colors.white60),
                              Text("Camera Off",
                                  style: TextStyle(color: Colors.white60)),
                            ],
                          ),
                        )
                      : AgoraVideoView(
                          controller: VideoViewController(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: 0),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _currentStatus == SessionStatus.inProgress
              ? [Colors.green, Colors.green[600]!]
              : [Color(0xFF1E40AF), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Icon(_getStatusIcon(_currentStatus), size: 20, color: Colors.white),
          SizedBox(width: 10),
          Text(
            _currentStatus == SessionStatus.inProgress
                ? "LIVE CALL"
                : "WAITING",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Spacer(),
          Text(
            _remoteUserJoined
                ? "🔴 Live"
                : "Channel: ${_channelName.split('_').last}",
            style: TextStyle(color: Colors.white.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalControls() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.all(25),
        padding: EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chat Messages
            Container(
              height: 120,
              child: ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    messages[index],
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),

            // Input + Controls
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type message...",
                      hintStyle: TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    ),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() => messages.add(value.trim()));
                        _messageController.clear();
                      }
                    },
                  ),
                ),
                SizedBox(width: 15),

                // Controls
                _buildControlButton(
                  icon: _videoMuted ? Icons.videocam_off : Icons.videocam,
                  onPressed: _toggleVideo,
                  color: _videoMuted ? Colors.grey : Colors.red,
                ),
                _buildControlButton(
                  icon: _micMuted ? Icons.mic_off : Icons.mic,
                  onPressed: _toggleMute,
                  color: _micMuted ? Colors.grey : Colors.orange,
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  onPressed: _leaveCall,
                  color: Colors.red[600]!,
                  size: 32,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    double size = 28,
  }) {
    return Container(
      width: 60,
      height: 60,
      margin: EdgeInsets.only(left: 10),
      child: RawMaterialButton(
        onPressed: onPressed,
        elevation: 10,
        fillColor: color,
        padding: EdgeInsets.all(15),
        shape: CircleBorder(),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  IconData _getStatusIcon(SessionStatus status) {
    switch (status) {
      case SessionStatus.waiting:
        return Icons.hourglass_empty;
      case SessionStatus.inProgress:
        return Icons.videocam;
      default:
        return Icons.schedule;
    }
  }
}
