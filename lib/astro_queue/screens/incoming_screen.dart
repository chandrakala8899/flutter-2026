import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';

class IncomingCallScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final String callType; // "video", "audio", "chat"
  final bool isCustomer;

  const IncomingCallScreen({
    super.key,
    required this.session,
    required this.callType,
    required this.isCustomer,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _getCallerName() {
    if (widget.isCustomer) {
      return widget.session.consultant?.name ?? "Practitioner";
    } else {
      return widget.session.customer?.name ?? "Customer";
    }
  }

  // ✅ CONVERT STRING TO SHARED CallType
  CallType stringToCallType(String callTypeStr) {
    switch (callTypeStr.toLowerCase()) {
      case 'audio':
        return CallType.audio;
      case 'chat':
        return CallType.chat;
      default:
        return CallType.video;
    }
  }

  @override
  Widget build(BuildContext context) {
    final callerName = _getCallerName();
    final callTypeText = widget.callType.toUpperCase();
    final roleText = widget.isCustomer ? "Customer" : "Practitioner";

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing ring animation
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent.withOpacity(0.3),
                  border: Border.all(
                    color: Colors.greenAccent.withOpacity(0.8),
                    width: 4,
                  ),
                ),
                child: const Icon(
                  Icons.phone,
                  size: 80,
                  color: Colors.greenAccent,
                ),
              ),
            ),
            const SizedBox(height: 40),

            Text(callerName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("$roleText • $callTypeText CALL",
                style: const TextStyle(
                    color: Colors.white70, fontSize: 18, letterSpacing: 1.5)),
            const SizedBox(height: 60),
            Text("Ringing...",
                style: TextStyle(
                    color: Colors.white54,
                    fontSize: 20,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 80),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Reject
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.red,
                              blurRadius: 20,
                              spreadRadius: 2)
                        ]),
                    child: const Icon(Icons.call_end,
                        color: Colors.white, size: 32),
                  ),
                ),

                // Accept ✅ FIXED!
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionScreen(
                          session: widget.session,
                          isCustomer: widget.isCustomer,
                          callType:
                              stringToCallType(widget.callType), // ✅ SAME TYPE!
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Colors.green, Colors.greenAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [
                        const BoxShadow(
                            color: Colors.green,
                            blurRadius: 25,
                            spreadRadius: 3)
                      ],
                    ),
                    child:
                        const Icon(Icons.call, color: Colors.white, size: 36),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
