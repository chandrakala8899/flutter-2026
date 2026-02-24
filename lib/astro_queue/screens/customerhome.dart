import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/session_request_model.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:flutter_learning/astro_queue/screens/customer_queue_screen.dart';
import 'package:flutter_learning/astro_queue/services/websocketservice.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  UserModel? currentUser;
  List<UserModel> practitioners = [];
  List<ConsultationSessionResponse> allSessions = [];

  late WebSocketService webSocketService;

  bool isLoading = true;
  bool isSocketConnected = false;
  bool _navigatingToSession = false;
  bool _isStartingCall = false; // Prevent double-click

  @override
  void initState() {
    super.initState();
    webSocketService = WebSocketService();
    _loadData();
  }

  @override
  void dispose() {
    // webSocketService.disconnect();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() => isLoading = true);

    try {
      final user = await ApiService.getLoggedInUser();
      final users = await ApiService.getAllUsers();

      if (user == null) return;

      final sessions = await ApiService.getCustomerSessions(
        customerId: user.userId!,
        statuses: ["WAITING", "CALLED", "IN_PROGRESS"],
      );

      if (!mounted) return;

      setState(() {
        currentUser = user;
        practitioners =
            users.where((u) => u.roleEnum == Role.practitioner).toList();
        allSessions = sessions;
        isLoading = false;
      });

      if (!isSocketConnected) {
        _connectWebSocket(user.userId!);
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      debugPrint("LOAD DATA ERROR: $e");
    }
  }

  /* =========================================================
     DATE & TIME PICKER – PROPER VALIDATION
     ========================================================= */
  Future<DateTime?> pickDateTime(
    BuildContext context, {
    DateTime? initialDate,
    String? title,
  }) async {
    final DateTime now = DateTime.now();

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      helpText: title ?? "Select Date",
      confirmText: "Next",
      cancelText: "Cancel",
    );

    if (pickedDate == null) return null;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          initialDate ?? now.add(const Duration(hours: 1))),
      helpText: title ?? "Select Time",
    );

    if (pickedTime == null) return null;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selected.isBefore(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a future date/time")),
      );
      return null;
    }

    return selected;
  }

  /* =========================================================
     WEBSOCKET + OTHER HELPERS (unchanged)
     ========================================================= */
  void _connectWebSocket(int customerId) {
    webSocketService.connect(
      customerId: customerId,
      onCustomerUpdate: (data) {
        if (!mounted) return;
        final status = data["status"];
        _loadData();
        if (status == "CALLED") _showCallDialog(data);
        if (status == "IN_PROGRESS") _autoOpenSession(data);
      },
      onError: (error) => debugPrint("WebSocket Error: $error"),
    );
    isSocketConnected = true;
  }

  void _showCallDialog(Map<String, dynamic> data) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("📞 Your practitioner is ready to start the session"),
        content: Text("Session ${data["sessionNumber"]}"),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _autoOpenSession(data);
            },
            child: const Text("Join"),
          ),
        ],
      ),
    );
  }

  void _autoOpenSession(Map<String, dynamic> data) {
    if (_navigatingToSession) return;
    _navigatingToSession = true;

    final sessionId = data["sessionId"];
    final session = allSessions.firstWhere(
      (s) => s.sessionId == sessionId,
      orElse: () => allSessions.first,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          session: session,
          isCustomer: true,
          channelName: session.sessionId.toString(),
        ),
      ),
    ).then((_) {
      _navigatingToSession = false;
      _loadData();
    });
  }

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
        builder: (_) => SessionScreen(
          session: session,
          isCustomer: true,
          channelName: session.sessionId.toString(),
        ),
      ),
    ).then((_) => _loadData());
  }

  void _openQueueScreen(ConsultationSessionResponse session) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerQueueScreen(
          consultantId: session.consultant!.id!,
          customerId: currentUser!.userId!,
        ),
      ),
    ).then((_) => _loadData());
  }

  /* =========================================================
     MAIN UI
     ========================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Welcome ${currentUser?.name ?? ""}",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _statsCard(
                              "Live Calls", liveCallCount, Colors.green)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: _statsCard("In Queue", waitingSessions.length,
                              Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // WAITING SESSIONS
                  if (waitingSessions.isNotEmpty) ...[
                    const Text("⏳ Awaiting Consultation",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    ...waitingSessions.map((session) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.schedule,
                                color: Colors.orange),
                            title: Text("Session #${session.sessionNumber}"),
                            subtitle: const Text("Waiting in queue"),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _openQueueScreen(session),
                          ),
                        )),
                  ],

                  const SizedBox(height: 25),

                  // ACTIVE SESSIONS
                  if (activeSessions.isNotEmpty) ...[
                    const Text("🎥 Active Sessions",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    ...activeSessions.map((session) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.video_call,
                                color: Colors.green),
                            title: Text("Session #${session.sessionNumber}"),
                            subtitle:
                                Text("Status: ${session.status?.name ?? ''}"),
                            trailing:
                                const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () => _openSession(session),
                          ),
                        )),
                  ],

                  const SizedBox(height: 30),

                  // AVAILABLE PRACTITIONERS
                  const Text("Available Practitioners",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  ...practitioners.map((p) => Card(
                        child: ListTile(
                          title: Text(p.name ?? "Unknown"),
                          subtitle: const Text("Astrologer Practitioner"),
                          trailing: ElevatedButton(
                            onPressed: () async {
                              if (_isStartingCall) return;
                              setState(() => _isStartingCall = true);

                              try {
                                // Step 1: Pick start time
                                final startTime = await pickDateTime(context,
                                    title: "Select Consultation Start Time");
                                if (startTime == null) return;

                                // Step 2: Pick end time
                                DateTime? endTime;
                                do {
                                  endTime = await pickDateTime(context,
                                      initialDate: startTime
                                          .add(const Duration(hours: 1)),
                                      title: "Select Consultation End Time");
                                  if (endTime == null) return;

                                  if (endTime.isBefore(startTime)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "End time must be after start time")),
                                    );
                                  }
                                } while (endTime!.isBefore(startTime));

                                // Step 3: Show confirmation dialog
                                final bool? confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text("Confirm Consultation"),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            "With: ${p.name ?? 'Practitioner'}"),
                                        const SizedBox(height: 8),
                                        Text(
                                            "Start: ${startTime.toString().substring(0, 16)}"),
                                        Text(
                                            "End:   ${endTime.toString().substring(0, 16)}"),
                                        const SizedBox(height: 12),
                                        const Text(
                                            "Are you sure you want to book this session?"),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text("Cancel"),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text("Confirm"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed != true) return;

                                // Step 4: Show loading
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                      child: CircularProgressIndicator()),
                                );

                                // Step 5: Create session
                                final request = ConsultationSessionRequest(
                                  customerId: currentUser!.userId!,
                                  consultantId: p.userId!,
                                  startDate: startTime,
                                  endDate: endTime,
                                );

                                final session = await ApiService.createSession(
                                    request: request);

                                // Close loading
                                if (mounted && Navigator.canPop(context)) {
                                  Navigator.pop(context);
                                }

                                if (session != null) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerQueueScreen(
                                        consultantId: p.userId!,
                                        customerId: currentUser!.userId!,
                                      ),
                                    ),
                                  ).then((_) => _loadData());
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text("Failed to create session")),
                                  );
                                }
                              } catch (e) {
                                debugPrint("Consult error: $e");
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error: $e")),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isStartingCall = false);
                                }
                              }
                            },
                            child: const Text("Consult"),
                          ),
                        ),
                      )),
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Text(value.toString(),
              style: TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 5),
          Text(title),
        ],
      ),
    );
  }
}
