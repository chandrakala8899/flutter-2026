import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

class VideoCallScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final RtcEngine? engine;

  const VideoCallScreen({
    super.key,
    required this.session,
    required this.isCustomer,
    required this.engine,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int? remoteUid;

  bool micMuted = false;
  bool cameraMuted = false;

  String get participantName =>
      widget.isCustomer ? "Practitioner" : "Customer";

  @override
  void initState() {
    super.initState();

    widget.engine?.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (_, uid, __) {
          setState(() => remoteUid = uid);
        },
        onUserOffline: (_, uid, __) {
          if (remoteUid == uid) {
            setState(() => remoteUid = null);
          }
        },
      ),
    );
  }

  /// =============================
  /// Toggle Mic
  /// =============================
  Future<void> _toggleMic() async {
    micMuted = !micMuted;
    await widget.engine?.muteLocalAudioStream(micMuted);
    setState(() {});
  }

  /// =============================
  /// Toggle Camera
  /// =============================
  Future<void> _toggleCamera() async {
    cameraMuted = !cameraMuted;
    await widget.engine?.muteLocalVideoStream(cameraMuted);
    setState(() {});
  }

  /// =============================
  /// End Call
  /// =============================
  Future<void> _endCall() async {
    await widget.engine?.leaveChannel();

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      /// ================= Header =================
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Row(
          children: [
            const Icon(Icons.circle, color: Colors.green, size: 12),
            const SizedBox(width: 8),
            Text("$participantName Online"),
          ],
        ),
        actions: const [
          Icon(Icons.videocam, color: Colors.white),
          SizedBox(width: 16),
        ],
      ),

      /// ================= Video Body =================
      body: Stack(
        children: [

          /// Remote Video
          Positioned.fill(
            child: remoteUid != null
                ? AgoraVideoView(
                    controller: VideoViewController.remote(
                      rtcEngine: widget.engine!,
                      canvas: VideoCanvas(uid: remoteUid),
                      connection: const RtcConnection(
                        channelId: "astro_channel_123",
                      ),
                    ),
                  )
                : const Center(
                    child: Text(
                      "Waiting for participant...",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
          ),

          /// Local Preview Window
          Positioned(
            top: 80,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white54, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: cameraMuted
                    ? Container(
                        color: Colors.black87,
                        child: const Center(
                          child: Icon(Icons.videocam_off,
                              color: Colors.white),
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

          /// ================= Controls =================
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  _controlButton(
                    icon: micMuted ? Icons.mic_off : Icons.mic,
                    color: micMuted ? Colors.grey : Colors.orange,
                    onTap: _toggleMic,
                  ),

                  _controlButton(
                    icon: cameraMuted
                        ? Icons.videocam_off
                        : Icons.videocam,
                    color: cameraMuted ? Colors.grey : Colors.purple,
                    onTap: _toggleCamera,
                  ),

                  /// Chat Button (if you want open chat screen)
                  _controlButton(
                    icon: Icons.chat,
                    color: Colors.deepPurple,
                    onTap: () {},
                  ),

                  /// End Call
                  _controlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    onTap: _endCall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Control Button Widget
  Widget _controlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: color,
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onTap,
      ),
    );
  }
}