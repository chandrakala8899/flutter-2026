import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

class AudioCallScreen extends StatelessWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final String participantName;
  final RtcEngine? engine;
  final bool micMuted;
  final VoidCallback onMicToggle;
  final VoidCallback onEndCall;

  const AudioCallScreen({
    super.key,
    required this.session,
    required this.isCustomer,
    required this.participantName,
    required this.engine,
    required this.micMuted,
    required this.onMicToggle,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: onEndCall),
        title: Text("$participantName ${micMuted ? '(Muted)' : ''}"),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone_in_talk,
                        size: 140, color: Colors.greenAccent),
                    const SizedBox(height: 30),
                    Text("$participantName is on the call",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 24)),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                      icon: micMuted ? Icons.mic_off : Icons.mic,
                      color: micMuted ? Colors.grey : Colors.white,
                      onPressed: onMicToggle),
                  _buildControlButton(
                      icon: Icons.call_end,
                      color: Colors.red,
                      size: 70,
                      onPressed: onEndCall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton(
      {required IconData icon,
      required Color color,
      double size = 58,
      required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: color == Colors.red
                ? Colors.red
                : Colors.white.withOpacity(0.2),
            shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      ),
    );
  }
}
