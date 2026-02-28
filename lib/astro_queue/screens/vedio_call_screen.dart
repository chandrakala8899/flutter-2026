import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

class VideoCallScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final String participantName;
  final RtcEngine? engine;
  final int? remoteUid;
  final String channelName;
  final bool micMuted;
  final bool videoMuted;
  final bool remoteJoined;
  final VoidCallback onMicToggle;
  final VoidCallback onCameraToggle;
  final VoidCallback onEndCall;

  const VideoCallScreen({
    super.key,
    required this.session,
    required this.isCustomer,
    required this.participantName,
    required this.engine,
    required this.remoteUid,
    required this.channelName,
    required this.micMuted,
    required this.videoMuted,
    required this.remoteJoined,
    required this.onMicToggle,
    required this.onCameraToggle,
    required this.onEndCall,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  @override
  void initState() {
    super.initState();
    // ✅ FIXED: Only log once on init
    debugPrint(
        "🎥 VideoCallScreen LOADED | UID: ${widget.remoteUid ?? 'null'}");
  }

  @override
  Widget build(BuildContext context) {
    // ✅ FIXED: Remove spam logging - only log on major state changes
    if (widget.engine == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text("Initializing...", style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black26,
        title: Text(
          "${widget.participantName} ${widget.remoteJoined ? '● Live' : '○ Calling...'}",
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => widget.engine?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🔥 REMOTE VIDEO - FULL SCREEN
          Positioned.fill(
            child: widget.remoteUid != null && widget.remoteJoined
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: widget.engine!,
                      canvas: VideoCanvas(uid: widget.remoteUid!),
                      connection: RtcConnection(channelId: widget.channelName),
                    ),
                  )
                : _buildWaitingScreen(widget.participantName),
          ),

          // 🔥 LOCAL VIDEO PIP - TOP RIGHT CORNER
          Positioned(
            top: MediaQuery.of(context).padding.top + 20,
            right: 16,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border:
                    Border.all(color: Colors.white.withOpacity(0.7), width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: widget.videoMuted
                    ? Container(
                        color: Colors.black54,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.videocam_off,
                                color: Colors.white70, size: 32),
                            Text("Camera Off",
                                style: TextStyle(color: Colors.white70)),
                          ],
                        ),
                      )
                    : AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: widget.engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
              ),
            ),
          ),

          // 🔥 MIC STATUS INDICATOR
          if (widget.micMuted)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.mic_off, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    Text("Muted",
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ),

          // 🔥 CONTROLS BAR - BOTTOM
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: widget.micMuted ? Icons.mic_off : Icons.mic,
                    color: widget.micMuted ? Colors.grey : Colors.cyan,
                    onTap: widget.onMicToggle,
                    size: 28,
                  ),
                  _buildControlButton(
                    icon:
                        widget.videoMuted ? Icons.videocam_off : Icons.videocam,
                    color: widget.videoMuted ? Colors.grey : Colors.purple,
                    onTap: widget.onCameraToggle,
                    size: 28,
                  ),
                  _buildControlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onTap: widget.onEndCall,
                    size: 32,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingScreen(String participantName) {
    return Container(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.video_call,
                  color: Colors.white54,
                  size: 60,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Calling $participantName...",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.remoteJoined
                    ? "Connected - Waiting for video"
                    : "Ringing...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 32),
              Text(
                "Session #${widget.session.sessionNumber ?? 'N/A'}",
                style: const TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 28,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size + 24,
        height: size + 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
