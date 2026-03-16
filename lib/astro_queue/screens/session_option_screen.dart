

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:flutter_learning/astro_queue/screens/wallet_screen.dart';
import 'package:flutter_learning/astro_queue/services/wallet_service.dart';

class SessionOptionScreen extends StatefulWidget {
  final ConsultationSessionResponse? session;
  final bool isCustomer;

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
  bool _checkingWallet = false;

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
    return "Available in ${remaining.inMinutes} minutes";
  }

  String _callTypeToSessionType(CallType callType) {
    switch (callType) {
      case CallType.audio:
        return 'AUDIO';
      case CallType.video:
        return 'VIDEO';
      case CallType.chat:
        return 'CHAT';
    }
  }

  // ── Wallet check → navigate ───────────────────────────────────────────────
  Future<void> _navigateToSession(CallType callType) async {
    if (widget.session == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text("Session data not available. Please go back and try again."),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Non-customer (practitioner) skips wallet check
    if (!widget.isCustomer) {
      _pushSessionScreen(callType);
      return;
    }

    // Resolve remaining minutes from scheduledEnd
    final session = widget.session!;
    final now = DateTime.now();
    int remainingMinutes = session.scheduledDurationMinutes ?? 10;
    if (session.scheduledEnd != null) {
      final rem = session.scheduledEnd!.difference(now).inMinutes;
      if (rem > 0) remainingMinutes = rem;
    }

    final customerId = session.customer?.id;
    final consultantId = session.consultant?.id;
    if (customerId == null || consultantId == null) {
      _pushSessionScreen(callType);
      return;
    }

    setState(() => _checkingWallet = true);

    final check = await WalletService.checkThreshold(
      customerId: customerId,
      practitionerId: consultantId,
      sessionType: _callTypeToSessionType(callType),
      durationMinutes: remainingMinutes,
    );

    if (!mounted) return;
    setState(() => _checkingWallet = false);

    if (check == null || check.sufficient) {
      _pushSessionScreen(callType);
      return;
    }

    // Insufficient — show dialog
    final goTopUp = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: const [
          Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFF9500)),
          SizedBox(width: 10),
          Text('Insufficient Balance', style: TextStyle(fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Required', '₹${check.requiredAmount.toStringAsFixed(0)}'),
            _row('Your balance', '₹${check.walletBalance.toStringAsFixed(0)}'),
            _row('Shortfall', '₹${check.shortfall.toStringAsFixed(0)}',
                color: Colors.red),
            const SizedBox(height: 10),
            Text(check.message,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_card_rounded, size: 16),
            label: const Text('Top Up Wallet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9500),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (goTopUp == true && mounted) {
      await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WalletScreen(userId: customerId),
          ));
      // After top-up, re-check silently and proceed if OK
      if (!mounted) return;
      final reCheck = await WalletService.checkThreshold(
        customerId: customerId,
        practitionerId: consultantId,
        sessionType: _callTypeToSessionType(callType),
        durationMinutes: remainingMinutes,
      );
      if (reCheck?.sufficient == true && mounted) {
        _pushSessionScreen(callType);
      }
    }
  }

  void _pushSessionScreen(CallType callType) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            session: widget.session!,
            isCustomer: widget.isCustomer,
            callType: callType,
          ),
        ));
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54)),
          Text(value,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: color ?? Colors.black87,
              )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.orange,
        title: const Text("Start Session",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSessionInfoCard(),
            ),
            const SizedBox(height: 40),
            Column(
              children: [
                const Text("Choose Session Type",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                if (_availabilityMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_availabilityMessage,
                        style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 15,
                            fontWeight: FontWeight.w500)),
                  ),
                if (widget.session == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text("Session data unavailable",
                        style: TextStyle(
                            color: Colors.red.shade700, fontSize: 14)),
                  ),
                if (_checkingWallet)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.orange)),
                        SizedBox(width: 8),
                        Text("Checking wallet...",
                            style:
                                TextStyle(color: Colors.orange, fontSize: 13)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 25),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildOptionCard2(
                      icon: Icons.chat_bubble_outline,
                      title: "Chat Only",
                      subtitle: "Text based consultation",
                      color: Colors.deepPurple,
                      callType: CallType.chat,
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard2(
                      icon: Icons.phone_in_talk,
                      title: "Voice Call",
                      subtitle: "Audio consultation",
                      color: Colors.green,
                      callType: CallType.audio,
                    ),
                    const SizedBox(height: 20),
                    _buildOptionCard2(
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
          color: Colors.white, borderRadius: BorderRadius.circular(18)),
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
    final bool enabled =
        _canJoinNow && widget.session != null && !_checkingWallet;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? () => _navigateToSession(callType) : null,
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
                child:
                    Icon(icon, color: enabled ? color : Colors.grey, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: enabled ? null : Colors.grey.shade400)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 14,
                            color:
                                enabled ? Colors.grey : Colors.grey.shade300)),
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

  // ← Required positional fix: pass context explicitly in _buildOptionCard
  Widget _buildOptionCard2({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required CallType callType,
  }) =>
      _buildOptionCard(
        context,
        icon: icon,
        title: title,
        subtitle: subtitle,
        color: color,
        callType: callType,
      );
}
