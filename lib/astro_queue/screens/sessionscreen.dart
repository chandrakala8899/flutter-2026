import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/screens/chat_screen.dart';
import 'package:flutter_learning/astro_queue/screens/vedio_call_screen.dart';
import '../model/consultantresponse_model.dart';

class SessionScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final Map<String, dynamic> joinData;

  const SessionScreen({
    super.key,
    required this.session,
    required this.joinData,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  String _selectedMode = "chat";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Consultation Options")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              "Choose Consultation Type",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            RadioListTile(
              title: const Text("Chat Consultation"),
              value: "chat",
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() => _selectedMode = value!);
              },
            ),
            RadioListTile(
              title: const Text("Video Consultation"),
              value: "video",
              groupValue: _selectedMode,
              onChanged: (value) {
                setState(() => _selectedMode = value!);
              },
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                if (_selectedMode == "chat") {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        session: widget.session,
                        joinData: widget.joinData,
                      ),
                    ),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoCallScreen(
                        session: widget.session,
                        joinData: widget.joinData,
                      ),
                    ),
                  );
                }
              },
              child: const Text("Proceed"),
            )
          ],
        ),
      ),
    );
  }
}
