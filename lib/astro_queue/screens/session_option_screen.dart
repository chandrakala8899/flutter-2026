import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';

class SessionOptionScreen extends StatefulWidget {
  final ConsultationSessionResponse? session;
  final bool isCustomer; // ← Now directly used (no reloading needed)

  const SessionOptionScreen({
    super.key,
    this.session,
    required this.isCustomer,
  });

  @override
  State<SessionOptionScreen> createState() => _SessionOptionScreenState();
}

class _SessionOptionScreenState extends State<SessionOptionScreen> {
  late final Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  bool get _canJoinNow {
    final session = widget.session;
    if (session?.scheduledStart == null) return true;

    final now = DateTime.now();
    final allowedTime =
        session!.scheduledStart!.subtract(const Duration(minutes: 5));

    return now.isAfter(allowedTime) || now.isAtSameMomentAs(allowedTime);
  }

  String get _availabilityMessage {
    if (_canJoinNow) return '';

    final session = widget.session;
    if (session?.scheduledStart == null) return '';

    final allowedTime =
        session!.scheduledStart!.subtract(const Duration(minutes: 5));

    final remaining = allowedTime.difference(DateTime.now());

    if (remaining.isNegative) return '';

    final minutes = remaining.inMinutes;

    return "Available in $minutes minutes";
  }

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
        iconTheme: const IconThemeData(color: Colors.white),
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

            /// TITLE + MESSAGE (only for customer)
            Column(
              children: [
                const Text(
                  "Choose Session Type",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                if (_availabilityMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _availabilityMessage,
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
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

  Widget _buildSessionInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
              widget.isCustomer
                  ? "Connected with Practitioner"
                  : "Connected with Customer",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required CallType callType,
  }) {
    final bool enabled = _canJoinNow;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionScreen(
                    session: widget.session,
                    isCustomer: widget.isCustomer,
                    callType: callType,
                  ),
                ),
              );
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: enabled
                    ? color.withOpacity(0.2)
                    : Colors.grey.withOpacity(0.2)),
            boxShadow: [
              BoxShadow(
                color: (enabled ? color : Colors.grey).withOpacity(0.08),
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
                  color: (enabled ? color : Colors.grey).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: enabled ? color : Colors.grey,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: enabled ? null : Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: enabled ? Colors.grey : Colors.grey.shade300,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                enabled
                    ? Icons.arrow_forward_ios_rounded
                    : Icons.lock_clock_rounded,
                size: 18,
                color: enabled ? null : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
