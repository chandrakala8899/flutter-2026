import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../model/consultantresponse_model.dart';

class VideoCallScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final Map<String, dynamic> joinData;

  const VideoCallScreen({
    super.key,
    required this.session,
    required this.joinData,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RtcEngine _engine;
  int? remoteUid;

  @override
  void initState() {
    super.initState();
    _initAgora();
  }

  Future<void> _initAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: "1a799cf30b064aabbd16218fa05b4014",
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onUserJoined: (connection, uid, elapsed) {
          setState(() => remoteUid = uid);
        },
        onUserOffline: (connection, uid, reason) {
          setState(() => remoteUid = null);
        },
      ),
    );

    await _engine.enableVideo();

    await _engine.joinChannel(
      token: widget.joinData["rtcToken"],
      channelId: widget.joinData["channelName"],
      uid: widget.joinData["uid"],
      options: const ChannelMediaOptions(),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Video Consultation")),
      body: Stack(
        children: [
          if (remoteUid != null)
            AgoraVideoView(
              controller: VideoViewController.remote(
                rtcEngine: _engine,
                canvas: VideoCanvas(uid: remoteUid),
                connection: RtcConnection(
                  channelId: widget.joinData["channelName"],
                ),
              ),
            ),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 120,
              height: 160,
              child: AgoraVideoView(
                controller: VideoViewController(
                  rtcEngine: _engine,
                  canvas: const VideoCanvas(uid: 0),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}