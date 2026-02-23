import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
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

  /* =========================================================
     LOAD INITIAL DATA
     ========================================================= */
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

      /// ✅ Connect WebSocket only once
      if (!isSocketConnected) {
        _connectWebSocket(user.userId!);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
      }
      debugPrint("LOAD DATA ERROR: $e");
    }
  }

  void _connectWebSocket(int customerId) {
    webSocketService.connect(
      customerId: customerId,
      onCustomerUpdate: (data) {
        if (!mounted) return;

        final status = data["status"];

        _loadData();

        if (status == "CALLED") {
          _showCallDialog(data);
        }

        if (status == "IN_PROGRESS") {
          _autoOpenSession(data);
        }
      },
      onError: (error) {
        debugPrint("WebSocket Error: $error");
      },
    );

    isSocketConnected = true;
  }

  void _showCallDialog(Map<String, dynamic> data) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("📞 Consultant is calling!"),
        content: Text("Session #${data["sessionNumber"]}"),
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

  /* =========================================================
     AUTO OPEN SESSION SAFELY
     ========================================================= */
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

  /* =========================================================
     FILTER HELPERS
     ========================================================= */
  List<ConsultationSessionResponse> get waitingSessions =>
      allSessions.where((s) => s.status == SessionStatus.waiting).toList();

  List<ConsultationSessionResponse> get activeSessions => allSessions
      .where((s) =>
          s.status == SessionStatus.called ||
          s.status == SessionStatus.inProgress)
      .toList();

  int get liveCallCount =>
      allSessions.where((s) => s.status == SessionStatus.inProgress).length;

  /* =========================================================
     OPEN MANUAL SESSION
     ========================================================= */
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
     UI
     ========================================================= */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Welcome ${currentUser?.name ?? ""}"),
        backgroundColor: Colors.orange,
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
                            "Live Calls", liveCallCount, Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _statsCard(
                            "In Queue", waitingSessions.length, Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  /// WAITING
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

                  /// ACTIVE
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

                  /// PRACTITIONERS
                  const Text("Available Practitioners",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  ...practitioners.map((p) => Card(
                        child: ListTile(
                          title: Text(p.name),
                          subtitle: const Text("Astrologer Practitioner"),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerQueueScreen(
                                    consultantId: p.userId!,
                                    customerId: currentUser!.userId!,
                                  ),
                                ),
                              );
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
