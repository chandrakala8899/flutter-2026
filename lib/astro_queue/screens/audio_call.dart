import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

class AudioCallScreen extends StatelessWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final RtcEngine? engine;

  const AudioCallScreen({
    super.key,
    required this.session,
    required this.isCustomer,
    required this.engine,
  });

  @override
  Widget build(BuildContext context) {
    final name = isCustomer ? "Practitioner" : "Customer";

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor:
            Colors.transparent, 
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(), // 🔥 CLOSE BUTTON
        ),
        title: Row(
          children: [
            const SizedBox(width: 8),
            Text(
              name,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔥 CALL STATUS
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.phone_in_talk,
                      size: 120,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$name is on the call',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // 🔥 CALL CONTROLS
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.black26,
                border: Border(
                  top: BorderSide(color: Colors.white12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 🔥 MUTE BUTTON
                  _buildControlButton(
                    icon: Icons.mic,
                    isActive: true,
                    color: Colors.white,
                    onPressed: () {
                      // TODO: Toggle mute
                    },
                  ),

                  // 🔥 END CALL BUTTON (RED)
                  _buildControlButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    size: 60,
                    onPressed: () {
                      Navigator.of(context).pop(); // 🔥 EXIT CALL
                    },
                  ),

                  // 🔥 SPEAKER BUTTON
                  _buildControlButton(
                    icon: Icons.volume_up,
                    isActive: true,
                    color: Colors.white,
                    onPressed: () {
                      // TODO: Toggle speaker
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 REUSABLE CONTROL BUTTON
  Widget _buildControlButton({
    required IconData icon,
    bool isActive = false,
    required Color color,
    double size = 52,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color:
              color == Colors.red ? Colors.red : Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: color == Colors.red ? Colors.redAccent : Colors.white38,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.6,
        ),
      ),
    );
  }
}
