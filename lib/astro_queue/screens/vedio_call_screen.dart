import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

class VideoCallScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // 🔥 CRITICAL FIX: Show loading until engine is ready
    if (engine == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text(
                "Initializing video engine...",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "$participantName ${remoteJoined ? '• Connected' : '• Calling...'}",
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // Remote Video (Full Screen)
          Positioned.fill(
            child: remoteUid != null && remoteJoined
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: engine!,
                      canvas: VideoCanvas(uid: remoteUid!),
                      connection: RtcConnection(channelId: channelName),
                    ),
                  )
                : const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 20),
                        Text("Waiting for other person...",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 18)),
                      ],
                    ),
                  ),
          ),

          // Local Video Preview (Picture-in-Picture)
          Positioned(
            top: 60,
            right: 16,
            child: Container(
              width: 120,
              height: 170,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: videoMuted
                    ? const Center(
                        child: Icon(Icons.videocam_off,
                            color: Colors.white70, size: 40))
                    : AgoraVideoView(
                        controller: VideoViewController(
                          rtcEngine: engine!,
                          canvas: const VideoCanvas(uid: 0),
                        ),
                      ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _controlButton(micMuted ? Icons.mic_off : Icons.mic,
                      Colors.blue, onMicToggle),
                  _controlButton(
                      videoMuted ? Icons.videocam_off : Icons.videocam,
                      Colors.purple,
                      onCameraToggle),
                  _controlButton(Icons.call_end, Colors.red, onEndCall,
                      isLarge: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton(IconData icon, Color color, VoidCallback onTap,
      {bool isLarge = false}) {
    return CircleAvatar(
      radius: isLarge ? 32 : 28,
      backgroundColor: color,
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: isLarge ? 32 : 26),
        onPressed: onTap,
      ),
    );
  }
}
