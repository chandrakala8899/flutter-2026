import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';

class IncomingCallScreen extends StatelessWidget {
  final ConsultationSessionResponse session;
  final String callType; // "video" or "audio"

  const IncomingCallScreen({
    super.key,
    required this.session,
    required this.callType,
  });

  @override
  Widget build(BuildContext context) {
    final callerName = session.customer?.name ?? "Customer";

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ring_volume, size: 140, color: Colors.greenAccent),
            const SizedBox(height: 30),
            Text("Call from $callerName",
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            Text("$callType call • Ringing...",
                style: const TextStyle(color: Colors.white70, fontSize: 18)),
            const SizedBox(height: 100),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject
                FloatingActionButton.large(
                  backgroundColor: Colors.red,
                  child:
                      const Icon(Icons.call_end, color: Colors.white, size: 40),
                  onPressed: () => Navigator.pop(context),
                ),
                // Accept
                FloatingActionButton.large(
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.call, color: Colors.white, size: 40),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionScreen(
                          session: session,
                          isCustomer: false,
                          callType: callType == "audio"
                              ? CallType.audio
                              : CallType.video,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
