import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/practioner_profile_response.dart';
import 'package:flutter_learning/astro_queue/model/session_request_model.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/chat_screen.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:flutter_learning/astro_queue/screens/customer_queue_screen.dart';
import 'package:flutter_learning/astro_queue/screens/incoming_screen.dart'
    hide CallType;
import 'package:flutter_learning/astro_queue/screens/wallet_screen.dart';
import 'package:flutter_learning/astro_queue/services/chat_service.dart';
import 'package:flutter_learning/astro_queue/services/wallet_service.dart';
import 'package:flutter_learning/astro_queue/services/websocketservice.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class CustomerHome extends StatefulWidget {
    final bool? isCustomer;
  const CustomerHome({super.key, this.isCustomer});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  UserModel? currentUser;
  List<ConsultationSessionResponse> allSessions = [];
  List<PractionerProfileResponse> practitioners = [];
  WalletBalance? walletBalance;
  List<SessionDuration> _durations = [];

  late WebSocketService webSocketService;
  bool isLoading = true;
  bool isSocketConnected = false;
  bool _navigatingToSession = false;

  late ChatService _chatService;
  final Set<int> _bookingInProgress = {};
  late Razorpay _razorpay;

  String? _currentOrderId;
  double _currentAmount = 0;

  @override
  void initState() {
    super.initState();

    webSocketService = WebSocketService();
    _chatService = ChatService();

    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    _loadData();
  }

  @override
  void dispose() {
    webSocketService.disconnect();
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_currentOrderId == null) return;

    final success = await WalletService.confirmTopUp(
      gatewayOrderId: response.orderId!,
      gatewayPaymentId: response.paymentId!,
      gatewaySignature: response.signature!,
    );

    if (success) {
      await _loadData(showLoading: false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "₹${_currentAmount.toStringAsFixed(0)} added to wallet",
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment verification failed"),
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Payment cancelled or failed"),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet: ${response.walletName}");
  }

  Future<void> _loadData({bool showLoading = true}) async {
    if (!mounted) return;
    if (showLoading) setState(() => isLoading = true);

    try {
      final user = await ApiService.getLoggedInUser();
      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final results = await Future.wait([
        ApiService.getAllUsers(),
        ApiService.getCustomerSessions(
          customerId: user.userId!,
          statuses: ["WAITING", "CALLED", "IN_PROGRESS"],
        ),
        WalletService.getBalance(user.userId!),
        WalletService.getDurations(),
      ]);

      if (!mounted) return;

      final allPractitioners =
          (results[0] as List<PractionerProfileResponse>?) ?? [];

      setState(() {
        currentUser = user;
        // Show ONLY available practitioners
        practitioners = allPractitioners.where((p) => p.isAvailable).toList();
        allSessions = (results[1] as List<ConsultationSessionResponse>?) ?? [];
        walletBalance = results[2] as WalletBalance?;
        _durations = (results[3] as List<SessionDuration>?) ?? [];
        isLoading = false;
      });

      if (!isSocketConnected && user.userId != null) {
        _connectWebSocket(user.userId!);
      }
    } catch (e) {
      debugPrint("Load data error: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load data: $e")),
        );
      }
    }
  }

  // ─── WebSocket ────────────────────────────────────────────────────────────

  void _connectWebSocket(int customerId) {
    webSocketService.connect(
      userId: customerId,
      onSessionUpdate: (data) {
        if (!mounted) return;
        if (data['type'] == 'session_extended') {
          _handleSessionExtended(data);
          return;
        }
        if (data['type'] == 'incoming_call') {
          _handleIncomingCall(data);
          return;
        }
        final status = data["status"]?.toString().toUpperCase();
        _loadData(showLoading: false);
        if (status == "CALLED") _showCallDialog(data);
        if (status == "IN_PROGRESS") _autoOpenSession(data);
      },
      onExpiryNotification: (data) {
        if (!mounted) return;
        _showExpiryNotification(data);
      },
      onError: (error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Connection issue: $error")),
          );
      },
    );
    if (mounted) setState(() => isSocketConnected = true);
  }

  void _handleSessionExtended(Map<String, dynamic> data) {
    final sessionId = data['sessionId'] as int?;
    final newEndStr = data['newScheduledEnd'] as String?;
    final minutes = data['extendedMinutes'] as int? ?? 15;
    if (sessionId == null) return;
    final newEnd = DateTime.tryParse(newEndStr ?? '');
    setState(() {
      for (var i = 0; i < allSessions.length; i++) {
        if (allSessions[i].sessionId == sessionId) {
          allSessions[i] = allSessions[i].copyWith(scheduledEnd: newEnd);
          break;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text("✅ Session extended by $minutes minutes!"),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 5),
    ));
  }

  void _showExpiryNotification(Map<String, dynamic> data) {
    final message = data['message'] ?? "Session update";
    final action = data['action'] ?? "";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(action == "REBOOK"
            ? "❌ Session Expired"
            : "⚠️ Session Expiring Soon"),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK")),
          if (action == "EXTEND")
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Extend coming soon...")),
                );
              },
              child: const Text("Extend Now"),
            ),
        ],
      ),
    );
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (!mounted) return;
    try {
      final session =
          ConsultationSessionResponse.fromJson(data['session'] ?? data);
      final callTypeStr = data['callType']?.toString() ?? 'video';
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IncomingCallScreen(
                session: session, callType: callTypeStr, isCustomer: true),
          )).then((_) => _loadData(showLoading: false));
    } catch (e) {
      debugPrint("Incoming call error: $e");
    }
  }

  void _showCallDialog(Map<String, dynamic> data) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.phone_callback, color: Colors.green, size: 28),
          SizedBox(width: 12),
          Text("Practitioner Called!", style: TextStyle(color: Colors.green)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Session #${data["sessionNumber"] ?? '?'}"),
          const SizedBox(height: 8),
          const Text("Tap to join the call",
              style: TextStyle(color: Colors.grey)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Later")),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam, size: 18),
            label: const Text("Join Call"),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _joinCalledSession(data);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _joinCalledSession(Map<String, dynamic> data) async {
    try {
      ConsultationSessionResponse? s;
      try {
        s = allSessions.firstWhere((x) => x.status == SessionStatus.called);
      } catch (_) {
        s = allSessions.isNotEmpty ? allSessions.first : null;
      }
      if (s != null && mounted) {
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionScreen(
                  session: s!, isCustomer: true, callType: CallType.video),
            ));
      }
    } catch (e) {
      debugPrint("Join session error: $e");
    }
  }

  void _autoOpenSession(Map<String, dynamic> data) {
    if (_navigatingToSession || !mounted) return;
    _navigatingToSession = true;
    final sessionId = data["sessionId"] as int?;
    if (sessionId == null) {
      _navigatingToSession = false;
      return;
    }
    ConsultationSessionResponse? session;
    try {
      session = allSessions.firstWhere((s) => s.sessionId == sessionId);
    } catch (_) {
      try {
        session =
            allSessions.firstWhere((s) => s.status == SessionStatus.inProgress);
      } catch (_) {
        session = allSessions.isNotEmpty ? allSessions.first : null;
      }
    }
    if (session != null && mounted) {
      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chatService: _chatService,
              session: session!,
              isCustomer: true,
              initialMessages: const [],
            ),
          )).then((_) {
        if (mounted) {
          _navigatingToSession = false;
          _loadData(showLoading: false);
        }
      });
    } else {
      _navigatingToSession = false;
    }
  }

  Future<void> _bookConsultation(
    PractionerProfileResponse practitioner,
    String sessionType,
  ) async {
    if (_bookingInProgress.contains(practitioner.id)) return;
    if (sessionType == null || !mounted) return;

    final selectedDuration = await _pickDuration(practitioner, sessionType);
    if (selectedDuration == null || !mounted) return;

    final durationMinutes = selectedDuration.durationMinutes;
    final practitionerId = practitioner.id;
    final rate = _rateForType(practitioner, sessionType);
    final estimatedCost = rate * durationMinutes;

    setState(() => _bookingInProgress.add(practitioner.id));

    try {
      // Step 3: Wallet threshold check
      if (currentUser?.userId != null) {
        final check = await WalletService.checkThreshold(
          customerId: currentUser!.userId!,
          practitionerId: practitionerId,
          sessionType: sessionType,
          durationMinutes: durationMinutes,
        );

        if (check != null && !check.sufficient && mounted) {
          final proceed = await _showInsufficientWalletDialog(check);
          if (proceed != true || !mounted) return;
          await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WalletScreen(userId: currentUser!.userId!),
              ));
          if (!mounted) return;
          final newBal = await WalletService.getBalance(currentUser!.userId!);
          if (mounted) setState(() => walletBalance = newBal);
          return;
        }
      }

      final now = DateTime.now();
      final startTime = now.add(const Duration(minutes: 2));
      final endTime = startTime.add(Duration(minutes: durationMinutes));

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Confirm Booking"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _confirmRow("Practitioner", practitioner.userName),
              _confirmRow("Specialization", practitioner.specialization),
              const Divider(height: 20),
              Row(children: [
                _sessionTypeChip(sessionType),
                const SizedBox(width: 8),
                Text(selectedDuration.label,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Text('@ ₹${rate.toStringAsFixed(0)}/min',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
              const Divider(height: 20),
              _confirmRow(
                "Total cost",
                "₹${estimatedCost.toStringAsFixed(0)}",
                valueColor: const Color(0xFFFF9500),
                bold: true,
              ),
              if (walletBalance != null)
                _confirmRow(
                  "Wallet balance",
                  "₹${walletBalance!.balance!.toStringAsFixed(0)}",
                  valueColor: walletBalance!.balance! >= estimatedCost
                      ? Colors.green.shade700
                      : Colors.red.shade700,
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Book Now"),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()));

      final request = ConsultationSessionRequest(
        customerId: currentUser!.userId!,
        consultantId: practitionerId,
        startDate: startTime,
        endDate: endTime,
        sessionType: sessionType,
      );

      final session =
          await ApiService.createSession(request: request, context: context);

      if (mounted && Navigator.canPop(context)) Navigator.pop(context);

      if (session != null && mounted) {
        final newBal = await WalletService.getBalance(currentUser!.userId!);
        if (mounted) setState(() => walletBalance = newBal);

        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerQueueScreen(
                consultantId: practitionerId,
                customerId: currentUser!.userId!,
              ),
            )).then((_) => _loadData(showLoading: false));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Booking failed: $e"),
              backgroundColor: Colors.red.shade700),
        );
    } finally {
      if (mounted) setState(() => _bookingInProgress.remove(practitioner.id));
    }
  }

  // ─── Step 1 Bottom Sheet: Pick Session Type + See Rates ──────────────────

  Future<String?> _pickSessionType(PractionerProfileResponse practitioner) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 20),
            Text(practitioner.userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(practitioner.specialization,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.star_rounded,
                  color: Color(0xFFFFCC00), size: 15),
              const SizedBox(width: 4),
              Text(practitioner.rating.toStringAsFixed(1),
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(width: 14),
              const Icon(Icons.people_outline, color: Colors.white30, size: 14),
              const SizedBox(width: 4),
              Text('${practitioner.totalSessions} sessions',
                  style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('SELECT SESSION TYPE',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
            _sessionTypeRow(
              icon: Icons.phone_in_talk_rounded,
              label: 'Audio Call',
              sublabel: 'Voice consultation',
              rate: practitioner.audioRatePerMin,
              color: const Color(0xFF00A8FF),
              value: 'AUDIO',
            ),
            const SizedBox(height: 10),
            _sessionTypeRow(
              icon: Icons.videocam_rounded,
              label: 'Video Call',
              sublabel: 'Face-to-face consultation',
              rate: practitioner.videoRatePerMin,
              color: const Color(0xFF7B61FF),
              value: 'VIDEO',
            ),
            const SizedBox(height: 10),
            _sessionTypeRow(
              icon: Icons.chat_bubble_rounded,
              label: 'Chat',
              sublabel: 'Text-based consultation',
              rate: practitioner.chatRatePerMin,
              color: const Color(0xFF00C896),
              value: 'CHAT',
            ),
          ],
        ),
      ),
    );
  }

  // ─── Step 2 Bottom Sheet: Pick Duration (10 / 30 / 60 min) ──────────────

  Future<SessionDuration?> _pickDuration(
      PractionerProfileResponse practitioner, String sessionType) {
    final rate = _rateForType(practitioner, sessionType);
    // Fallback durations if API returned empty
    final durations = _durations.isNotEmpty
        ? _durations
        : [
            SessionDuration(
                id: 1,
                durationMinutes: 10,
                label: '10 Min',
                description: 'Quick consultation'),
            SessionDuration(
                id: 2,
                durationMinutes: 30,
                label: '30 Min',
                description: 'Standard consultation'),
            SessionDuration(
                id: 3,
                durationMinutes: 60,
                label: '60 Min',
                description: 'Deep consultation'),
          ];

    return showModalBottomSheet<SessionDuration>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF161B22),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sheetHandle(),
            const SizedBox(height: 20),
            // Header
            Row(children: [
              _sessionTypeChip(sessionType),
              const SizedBox(width: 10),
              Text(practitioner.userName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '₹${rate.toStringAsFixed(0)}/min',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.white10),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('SELECT DURATION',
                  style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ),
            const SizedBox(height: 12),
            ...durations.map((d) {
              final cost = rate * d.durationMinutes;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, d),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        // Clock icon
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.timer_outlined,
                              color: Color(0xFFFF9500), size: 22),
                        ),
                        const SizedBox(width: 14),
                        // Label + description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d.label,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              if (d.description.isNotEmpty)
                                Text(d.description,
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                        ),
                        // Cost badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.35)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${cost.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Color(0xFFFF9500),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800),
                              ),
                              const Text(
                                'total',
                                style: TextStyle(
                                    color: Color(0xFFFF9500), fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white24, size: 14),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ─── Shared Sheet Widgets ─────────────────────────────────────────────────

  Widget _sheetHandle() => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
            color: Colors.white12, borderRadius: BorderRadius.circular(2)),
      );

  Widget _sessionTypeRow({
    required IconData icon,
    required String label,
    required String sublabel,
    required double rate,
    required Color color,
    required String value,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(sublabel,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            // Rate badge — shown in this sheet, NOT on the practitioner card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '₹${rate.toStringAsFixed(0)}',
                    style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
                  ),
                  Text('per min',
                      style: TextStyle(
                          color: color.withOpacity(0.7), fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white24, size: 14),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  double _rateForType(PractionerProfileResponse p, String type) {
    switch (type) {
      case 'VIDEO':
        return p.videoRatePerMin;
      case 'CHAT':
        return p.chatRatePerMin;
      default:
        return p.audioRatePerMin;
    }
  }

  Widget _sessionTypeChip(String type) {
    const map = {
      'AUDIO': (Icons.phone_in_talk_rounded, Color(0xFF00A8FF)),
      'VIDEO': (Icons.videocam_rounded, Color(0xFF7B61FF)),
      'CHAT': (Icons.chat_bubble_rounded, Color(0xFF00C896)),
    };
    final e =
        map[type] ?? const (Icons.phone_in_talk_rounded, Color(0xFF00A8FF));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: e.$2.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: e.$2.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(e.$1, size: 13, color: e.$2),
        const SizedBox(width: 4),
        Text(type,
            style: TextStyle(
                color: e.$2, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Future<bool?> _showInsufficientWalletDialog(ThresholdCheckResult check) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFF9500)),
          SizedBox(width: 10),
          Text('Insufficient Balance', style: TextStyle(fontSize: 17)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow(
                'Required', '₹${check.requiredAmount.toStringAsFixed(0)}'),
            _confirmRow(
                'Your balance', '₹${check.walletBalance.toStringAsFixed(0)}'),
            _confirmRow('Shortfall', '₹${check.shortfall.toStringAsFixed(0)}',
                valueColor: const Color(0xFFFF3B30)),
            const SizedBox(height: 12),
            Text(check.message,
                style: const TextStyle(color: Colors.black54, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_card_rounded, size: 16),
            label: const Text('Top Up Wallet'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9500),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              _showTopUpOptions();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showTopUpOptions() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Top Up Wallet",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              /// OPTION 1 → Wallet Plans
              ListTile(
                leading: const Icon(Icons.card_giftcard, color: Colors.orange),
                title: const Text("View Plans"),
                subtitle: const Text("Choose from wallet packages"),
                onTap: () {
                  Navigator.pop(context);
                  _openWallet();
                },
              ),

              const Divider(),

              /// OPTION 2 → Quick Recharge
              ListTile(
                leading: const Icon(Icons.flash_on, color: Colors.green),
                title: const Text("Quick Recharge"),
                subtitle: const Text("Enter amount and recharge instantly"),
                onTap: () {
                  Navigator.pop(context);
                  _showQuickRechargeDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showQuickRechargeDialog() async {
    final controller = TextEditingController();
    double amount = 0;
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentBalance = walletBalance!.availableBalance ?? 0;
            final newBalance = currentBalance + amount;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// TITLE
                    const Row(
                      children: [
                        Icon(Icons.account_balance_wallet,
                            color: Color(0xFFFF9500)),
                        SizedBox(width: 8),
                        Text(
                          "Quick Recharge",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    /// INPUT
                    TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      enabled: !isLoading,
                      decoration: InputDecoration(
                        prefixText: "₹ ",
                        labelText: "Enter amount",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          amount = double.tryParse(value) ?? 0;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    /// SUMMARY
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _row("You pay", "₹${amount.toStringAsFixed(0)}"),
                          const SizedBox(height: 6),
                          _row(
                            "Wallet gets",
                            "₹${amount.toStringAsFixed(0)}",
                            valueColor: Colors.green,
                            bold: true,
                          ),
                          const Divider(),
                          _row(
                            "Current Balance",
                            "₹${currentBalance.toStringAsFixed(2)}",
                          ),
                          const SizedBox(height: 6),
                          _row(
                            "New Balance",
                            "₹${newBalance.toStringAsFixed(2)}",
                            valueColor: Colors.green,
                            bold: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                isLoading ? null : () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9500),
                            ),
                            onPressed: isLoading
                                ? null
                                : () async {
                                    if (amount <= 0) return;

                                    setState(() => isLoading = true);

                                    /// 1️⃣ Initiate payment from backend
                                    final initRes =
                                        await WalletService.initiateTopUp(
                                      userId: currentUser!.userId!,
                                      amount: amount,
                                    );

                                    if (initRes == null) {
                                      setState(() => isLoading = false);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "Failed to initiate payment"),
                                        ),
                                      );
                                      return;
                                    }

                                    final orderId = initRes['gatewayOrderId'];

                                    /// store for success callback
                                    _currentOrderId = orderId;
                                    _currentAmount = amount;

                                    var options = {
                                      'key': initRes['razorpayKeyId'],
                                      'amount': initRes['amountInPaise'],
                                      'order_id': orderId,
                                      'name': 'Aumraa Wallet',
                                      'description': 'Wallet Recharge',
                                      'prefill': {
                                        'contact': currentUser?.name ?? '',
                                        'email': currentUser?.name ?? '',
                                      },
                                      'theme': {'color': '#FF9500'}
                                    };

                                    try {
                                      _razorpay.open(options);
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text("Payment failed")),
                                      );
                                    }

                                    setState(() => isLoading = false);
                                  },
                            child: isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text("Pay ₹${amount.toStringAsFixed(0)}"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(
    String label,
    String value, {
    Color valueColor = Colors.black,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
          Text(value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: valueColor ?? Colors.black87,
                fontSize: bold ? 15 : 13,
              )),
        ],
      ),
    );
  }

  // ─── Session Getters ──────────────────────────────────────────────────────

  List<ConsultationSessionResponse> get waitingSessions =>
      allSessions.where((s) => s.status == SessionStatus.waiting).toList();

  List<ConsultationSessionResponse> get activeSessions => allSessions
      .where((s) =>
          s.status == SessionStatus.called ||
          s.status == SessionStatus.inProgress)
      .toList();

  int get liveCallCount =>
      allSessions.where((s) => s.status == SessionStatus.called).length;

  void _openSession(ConsultationSessionResponse session) {
    final type = session.sessionType?.toUpperCase();

    if (type == "CHAT") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatService: _chatService,
            session: session,
            isCustomer: true,
            initialMessages: const [],
          ),
        ),
      );
    } else if (type == "AUDIO") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            session: session,
            isCustomer: true,
            callType: CallType.audio,
          ),
        ),
      );
    } else if (type == "VIDEO") {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionScreen(
            session: session,
            isCustomer: true,
            callType: CallType.video,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid session type"),
        ),
      );
    }
  }

  void _openQueueScreen(ConsultationSessionResponse session) {
    final cid = session.consultant?.id ?? 0;
    if (cid == 0 || currentUser?.userId == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CustomerQueueScreen(
              consultantId: cid, customerId: currentUser!.userId!),
        )).then((_) => _loadData(showLoading: false));
  }

  void _openWallet() {
    if (currentUser?.userId == null) return;
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WalletScreen(userId: currentUser!.userId!),
        )).then((_) async {
      if (mounted && currentUser?.userId != null) {
        final b = await WalletService.getBalance(currentUser!.userId!);
        if (mounted) setState(() => walletBalance = b);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Welcome ${currentUser?.name ?? 'Customer'}",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange.shade700,
        actions: [
          if (walletBalance != null)
            GestureDetector(
              onTap: _openWallet,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white38),
                ),
                child: Row(children: [
                  const Icon(Icons.account_balance_wallet_rounded,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text('₹${walletBalance!.balance!.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ]),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined,
                color: Colors.white),
            onPressed: _openWallet,
            tooltip: 'Wallet',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadData(showLoading: false),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(showLoading: false),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Stats
                  Row(children: [
                    Expanded(
                        child: _statsCard("Live Calls", liveCallCount,
                            Colors.green.shade600)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _statsCard("In Queue", waitingSessions.length,
                            Colors.orange.shade700)),
                  ]),

                  // Wallet summary
                  if (walletBalance != null) ...[
                    const SizedBox(height: 16),
                    _walletSummaryCard(),
                  ],

                  const SizedBox(height: 28),

                  // Waiting sessions
                  if (waitingSessions.isNotEmpty) ...[
                    const Text("⏳ Your Waiting Sessions",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...waitingSessions.map((s) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.schedule,
                                color: Colors.orange),
                            title: Text("Session #${s.sessionNumber}"),
                            subtitle: Text(
                                "With ${s.consultantName ?? 'Practitioner'}"),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _openQueueScreen(s),
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Active sessions
                  if (activeSessions.isNotEmpty) ...[
                    const Text("🎥 Active Sessions",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...activeSessions.map((s) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.video_call,
                                color: Colors.green),
                            title: Text("Session #${s.sessionNumber}"),
                            subtitle: Text(
                                "Status: ${s.status?.name.toUpperCase() ?? '?'}"),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _openSession(s),
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Choose a Practitioner",
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                      if (practitioners.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text('${practitioners.length} online',
                              style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (practitioners.isEmpty)
                    _emptyPractitioners()
                  else
                    ...practitioners.map((p) => _practitionerCard(p)),
                ],
              ),
            ),
    );
  }

  Widget _practitionerCard(PractionerProfileResponse p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          /// Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.orange.shade100,
            child: Text(
              p.userName.isNotEmpty ? p.userName[0].toUpperCase() : '?',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),

          const SizedBox(width: 12),

          /// Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.userName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 2),
                Text(
                  p.specialization,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text(
                      p.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 10),
                  ],
                ),
              ],
            ),
          ),

          /// ACTION BUTTONS
          Row(
            children: [
              _consultButton(
                icon: Icons.phone,
                color: const Color(0xFF00A8FF),
                price: p.audioRatePerMin,
                onTap: () => _bookConsultation(p, "AUDIO"),
              ),
              _consultButton(
                icon: Icons.videocam,
                color: const Color(0xFF7B61FF),
                price: p.videoRatePerMin,
                onTap: () => _bookConsultation(p, "VIDEO"),
              ),
              _consultButton(
                icon: Icons.chat_bubble,
                color: const Color(0xFF00C896),
                price: p.chatRatePerMin,
                onTap: () => _bookConsultation(p, "CHAT"),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _consultButton({
    required IconData icon,
    required Color color,
    required double price,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            "₹$price/min",
            style: const TextStyle(fontSize: 10),
          )
        ],
      ),
    );
  }

  Widget _emptyPractitioners() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [
        Icon(Icons.person_off_outlined, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text("No practitioners available right now",
            style: TextStyle(color: Colors.grey, fontSize: 15),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text("Pull down to refresh",
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
      ]),
    );
  }

  Widget _walletSummaryCard() {
    final bal = walletBalance!.balance;
    final isLow = bal < 100;
    return GestureDetector(
      onTap: _openWallet,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isLow
                ? [Colors.red.shade800, Colors.red.shade600]
                : [Colors.orange.shade700, Colors.orange.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: Colors.white, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Wallet Balance",
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text("₹${bal.toStringAsFixed(2)}",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              if (isLow)
                const Text("Low balance — tap to top up",
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text("Top Up",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Widget _statsCard(String title, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(children: [
        Text(value.toString(),
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ]),
    );
  }
}
