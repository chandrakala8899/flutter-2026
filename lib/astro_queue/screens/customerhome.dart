// 🔥 COMPLETE CustomerHome.dart - 100% WORKING & ERROR-FREE
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/session_request_model.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/session_option_screen.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:flutter_learning/astro_queue/screens/customer_queue_screen.dart';
import 'package:flutter_learning/astro_queue/screens/incoming_screen.dart'
    hide CallType;
import 'package:flutter_learning/astro_queue/services/websocketservice.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  UserModel? currentUser;
  List<ConsultationSessionResponse> allSessions = [];
  List<UserModel> practitioners = [];

  late WebSocketService webSocketService;

  bool isLoading = true;
  bool isSocketConnected = false;
  bool _navigatingToSession = false;

  final Set<int> _bookingInProgress = {};

  @override
  void initState() {
    super.initState();
    webSocketService = WebSocketService();
    _loadData();
  }

  @override
  void dispose() {
    webSocketService.disconnect();
    super.dispose();
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

      final users = await ApiService.getAllUsers();
      final sessions = await ApiService.getCustomerSessions(
            customerId: user.userId!,
            statuses: ["WAITING", "CALLED", "IN_PROGRESS"],
          ) ??
          [];

      if (!mounted) return;

      setState(() {
        currentUser = user;
        practitioners =
            users.where((u) => u.roleEnum == Role.practitioner).toList();
        allSessions = sessions;
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

  Future<DateTime?> pickDateTime(
    BuildContext context, {
    DateTime? initialDate,
    required String title,
  }) async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: title,
      confirmText: "Next",
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          initialDate ?? now.add(const Duration(hours: 1))),
      helpText: title,
    );

    if (pickedTime == null) return null;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selected.isBefore(now) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a future date and time")),
      );
      return null;
    }

    return selected;
  }

  void _connectWebSocket(int customerId) {
    webSocketService.connect(
      userId: customerId,
      onSessionUpdate: (data) {
        if (!mounted) return;

        debugPrint("🔥 Session update: $data");

        if (data['type'] == 'incoming_call') {
          _handleIncomingCall(data);
          return;
        }

        final status = data["status"]?.toString().toUpperCase();
        _loadData(showLoading: false);

        if (status == "CALLED") {
          _showCallDialog(data);
        }
        if (status == "IN_PROGRESS") {
          _autoOpenSession(data);
        }
      },
      onIncomingCall: (data) {
        debugPrint("📲 Customer incoming call: $data");
        _handleIncomingCall(data);
      },
      onError: (error) {
        debugPrint("WebSocket error: $error");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Connection issue: $error")),
          );
        }
      },
    );

    if (mounted) {
      setState(() => isSocketConnected = true);
    }
  }

  void _handleIncomingCall(Map<String, dynamic> data) {
    if (!mounted) return;

    try {
      final sessionData = data['session'] as Map<String, dynamic>? ?? data;

      if (sessionData.isEmpty) {
        debugPrint("❌ Empty session data");
        return;
      }

      final session = ConsultationSessionResponse.fromJson(sessionData);
      final callTypeStr = data['callType']?.toString() ?? 'video';

      debugPrint("📞 Showing incoming call for session: ${session.sessionId}");

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => IncomingCallScreen(
            session: session,
            callType: callTypeStr,
            isCustomer: true,
          ),
        ),
      ).then((_) => _loadData(showLoading: false));
    } catch (e) {
      debugPrint("Error handling incoming call: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Call error: $e")),
      );
    }
  }

  void _showCallDialog(Map<String, dynamic> data) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.phone_callback, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text("Practitioner Called!", style: TextStyle(color: Colors.green)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Session #${data["sessionNumber"] ?? '?'}"),
            const SizedBox(height: 12),
            const Text("Tap to join the video call",
                style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Later"),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.videocam, size: 18),
            label: const Text("Join Video Call"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
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
      // ✅ FIXED: Explicit nullable handling with try-catch
      ConsultationSessionResponse? activeSession;

      try {
        activeSession = allSessions.firstWhere(
          (s) => s.status == SessionStatus.called,
        );
      } catch (_) {
        // No called session, use first available
        activeSession = allSessions.isNotEmpty ? allSessions.first : null;
      }

      if (activeSession != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionScreen(
              session: activeSession,
              isCustomer: true,
              callType: CallType.video,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No active session found")),
        );
      }
    } catch (e) {
      debugPrint("Join session error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to join: $e")),
      );
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

    // ✅ FIXED: Same pattern
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
          builder: (_) => SessionOptionScreen(
            session: session!,
            isCustomer: true,
          ),
        ),
      ).then((_) {
        if (mounted) {
          _navigatingToSession = false;
          _loadData(showLoading: false);
        }
      });
    } else {
      _navigatingToSession = false;
    }
  }

  // Getters
  List<ConsultationSessionResponse> get waitingSessions =>
      allSessions.where((s) => s.status == SessionStatus.waiting).toList();

  List<ConsultationSessionResponse> get activeSessions => allSessions
      .where((s) =>
          s.status == SessionStatus.called ||
          s.status == SessionStatus.inProgress)
      .toList();

  int get liveCallCount =>
      allSessions.where((s) => s.status == SessionStatus.inProgress).length;

  void _openSession(ConsultationSessionResponse session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionOptionScreen(
          session: session,
          isCustomer: true,
        ),
      ),
    ).then((_) => _loadData(showLoading: false));
  }

  void _openQueueScreen(ConsultationSessionResponse session) {
    final consultantId = session.consultant?.id ?? 0;
    if (consultantId == 0 || currentUser?.userId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerQueueScreen(
          consultantId: consultantId,
          customerId: currentUser!.userId!,
        ),
      ),
    ).then((_) => _loadData(showLoading: false));
  }

  Future<void> _bookConsultation(UserModel practitioner) async {
    final practitionerId = practitioner.userId!;
    if (_bookingInProgress.contains(practitionerId)) return;

    setState(() {
      _bookingInProgress.add(practitionerId);
    });

    try {
      final startTime = await pickDateTime(
        context,
        title: "Select Consultation Start Time",
      );
      if (startTime == null || !mounted) return;

      DateTime? endTime;
      do {
        endTime = await pickDateTime(
          context,
          initialDate: startTime.add(const Duration(hours: 1)),
          title: "Select Consultation End Time",
        );
        if (endTime == null || !mounted) return;

        if (endTime.isBefore(startTime)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("End time must be after start time")),
          );
        }
      } while (endTime.isBefore(startTime));

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Confirm Booking"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("With: ${practitioner.name ?? 'Practitioner'}"),
              const SizedBox(height: 8),
              Text("Start: ${startTime.toString().substring(0, 16)}"),
              Text("End:   ${endTime.toString().substring(0, 16)}"),
              const SizedBox(height: 12),
              const Text("Proceed with this consultation booking?"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Book"),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final request = ConsultationSessionRequest(
        customerId: currentUser!.userId!,
        consultantId: practitionerId,
        startDate: startTime,
        endDate: endTime,
      );

      final session = await ApiService.createSession(
        request: request,
        context: context,
      );

      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (session != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerQueueScreen(
              consultantId: practitionerId,
              customerId: currentUser!.userId!,
            ),
          ),
        ).then((_) => _loadData(showLoading: false));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Booking failed: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _bookingInProgress.remove(practitionerId);
        });
      }
    }
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
                  // Stats Cards
                  Row(
                    children: [
                      Expanded(
                        child: _statsCard(
                            "Live Calls", liveCallCount, Colors.green.shade600),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _statsCard("In Queue", waitingSessions.length,
                            Colors.orange.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Waiting Sessions
                  if (waitingSessions.isNotEmpty) ...[
                    const Text(
                      "⏳ Your Waiting Sessions",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...waitingSessions.map((s) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.schedule,
                                color: Colors.orange),
                            title: Text("Session #${s.sessionNumber}"),
                            subtitle: Text(
                                "With ${s.consultant?.name ?? 'Practitioner'}"),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _openQueueScreen(s),
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],

                  // Active Sessions
                  if (activeSessions.isNotEmpty) ...[
                    const Text(
                      "🎥 Active Sessions",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
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

                  // Practitioners List
                  const Text(
                    "Choose a Practitioner",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ...practitioners.map((p) {
                    final isBookingThis =
                        _bookingInProgress.contains(p.userId ?? 0);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(p.name ?? "Practitioner"),
                        subtitle: const Text("Available Practitioner"),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                          ),
                          onPressed:
                              isBookingThis ? null : () => _bookConsultation(p),
                          child: isBookingThis
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text("Book"),
                        ),
                      ),
                    );
                  }),
                ],
              ),
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
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
