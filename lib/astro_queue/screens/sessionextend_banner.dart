import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

class SessionExtendBanner extends StatelessWidget {
  final ConsultationSessionResponse session;
  final bool isCustomer;
  final DateTime? effectiveScheduledEnd;
  final VoidCallback onExtend;
  final bool isExtending;

  const SessionExtendBanner({
    super.key,
    required this.session,
    required this.isCustomer,
    this.effectiveScheduledEnd,
    required this.onExtend,
    this.isExtending = false,
  });

  @override
  Widget build(BuildContext context) {
    final endTime = effectiveScheduledEnd ?? session.scheduledEnd;
    if (!isCustomer || endTime == null) return const SizedBox.shrink();

    final remaining = endTime.difference(DateTime.now());
    if (remaining.inMinutes > 5 || remaining.isNegative) return const SizedBox.shrink();

    final min = remaining.inMinutes.toString().padLeft(2, '0');
    final sec = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.deepOrange.shade600],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_off, color: Colors.white, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              "Session ends in $min:$sec\nExtend now to continue",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: isExtending ? null : onExtend,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: isExtending
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text("Extend 15 mins", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}