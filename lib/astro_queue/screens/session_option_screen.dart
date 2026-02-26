import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';

class SessionOptionScreen extends StatelessWidget {
  final ConsultationSessionResponse? session;
  final bool isCustomer;

  const SessionOptionScreen({
    super.key,
    this.session,
    required this.isCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange,
        title: const Text(
          "Start Session",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),

            /// SESSION INFO CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSessionInfoCard(),
            ),

            const SizedBox(height: 40),

            /// OPTIONS TITLE
            const Text(
              "Choose Session Type",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 25),

            /// OPTIONS
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildOptionCard(
                      context,
                      icon: Icons.chat_bubble_outline,
                      title: "Chat Only",
                      subtitle: "Text based consultation",
                      color: Colors.deepPurple,
                      callType: CallType.chat,
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      context,
                      icon: Icons.phone_in_talk,
                      title: "Voice Call",
                      subtitle: "Audio consultation",
                      color: Colors.green,
                      callType: CallType.audio,
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard(
                      context,
                      icon: Icons.videocam_outlined,
                      title: "Video Call",
                      subtitle: "Face to face consultation",
                      color: Colors.red,
                      callType: CallType.video,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Session Info Card
  Widget _buildSessionInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: Colors.deepPurple,
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              isCustomer
                  ? "Connected with Practitioner"
                  : "Connected with Customer",
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔹 Option Card
  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required CallType callType,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionScreen(
              session: session,
              isCustomer: isCustomer,
              callType: callType,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
