import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:http/http.dart' as http;

class PractitionerQueueScreen extends StatefulWidget {
  final int consultantId;
  const PractitionerQueueScreen({super.key, required this.consultantId});

  @override
  State<PractitionerQueueScreen> createState() =>
      _PractitionerQueueScreenState();
}

class _PractitionerQueueScreenState extends State<PractitionerQueueScreen> {
  List<Map<String, dynamic>> queue = [];
  Map<String, dynamic>? currentSession;
  bool isLoading = false;
  int queueSize = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted) _loadInitialData();
    });
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadQueue(), _loadCurrentSession()]);
  }

  Future<void> _loadQueue() async {
    setState(() => isLoading = true);
    try {
      final response = await http
          .get(Uri.parse(
              'http://localhost:16679/api/sessions/queue/${widget.consultantId}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            queue = List<Map<String, dynamic>>.from(data);
            queueSize = queue.length;
          });
        }
      }
    } catch (e) {
      print("Queue error: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadCurrentSession() async {
    try {
      final response = await http
          .get(Uri.parse(
              'http://localhost:16679/api/sessions/current/${widget.consultantId}'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        if (mounted) {
          setState(() {
            currentSession = jsonDecode(response.body);
          });
        }
      } else {
        if (mounted) setState(() => currentSession = null);
      }
    } catch (e) {
      print("No current session: $e");
      if (mounted) setState(() => currentSession = null);
    }
  }

  Future<void> _callNextCustomer() async {
    try {
      final response = await http.post(
        Uri.parse(
            'http://localhost:16679/api/sessions/call-next/${widget.consultantId}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Called next customer'),
              backgroundColor: Colors.green),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        await _loadInitialData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: ${response.statusCode}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _startSession(Map<String, dynamic> session) async {
    try {
      final response = await http.post(
        Uri.parse(
            'http://localhost:16679/api/sessions/${session['sessionId']}/start'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session started'),
            backgroundColor: Colors.blue,
          ),
        );

        // 🔥 Navigate to SessionScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionScreen(
              isCustomer: false,
              channelName: session['sessionId'].toString(),
            ),
          ),
        ).then((_) => _loadInitialData());
      }
    } catch (e) {
      print("Start failed: $e");
    }
  }

  Future<void> _completeSession(int sessionId) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:16679/api/sessions/$sessionId/complete'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Session completed'),
              backgroundColor: Colors.green),
        );
        await _loadInitialData();
      }
    } catch (e) {
      print("Complete failed: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'WAITING':
        return Colors.orange;
      case 'CALLED':
        return Colors.blue;
      case 'CUSTOMER_JOINED':
        return Colors.teal;
      case 'IN_PROGRESS':
        return Colors.green;
      case 'COMPLETED':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getDisplayStatus(String? status) {
    switch (status) {
      case 'CALLED':
        return "Called – waiting for customer";
      case 'CUSTOMER_JOINED':
        return "Customer joined – connecting";
      case 'IN_PROGRESS':
        return "In call";
      case 'COMPLETED':
        return "Completed";
      default:
        return status ?? "Unknown";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Queue ($queueSize) - Consultant #${widget.consultantId}"),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadInitialData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current session card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: currentSession != null
                  ? LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade400])
                  : LinearGradient(
                      colors: [Colors.grey.shade400, Colors.grey.shade300]),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  currentSession != null
                      ? Icons.videocam
                      : Icons.schedule_outlined,
                  color: Colors.white,
                  size: 48,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSession == null
                            ? "No Active Session"
                            : _getDisplayStatus(currentSession!['status']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (currentSession != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          "Customer: ${currentSession!['customer']['name'] ?? 'N/A'}",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16),
                        ),
                        Text(
                          "Session #${currentSession!['sessionNumber']}",
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16),
                        ),
                        if (currentSession!['status'] == 'CALLED')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "Waiting for customer to accept...",
                              style: TextStyle(
                                  color: Colors.yellow[300],
                                  fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // CALL NEXT button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: queue.isEmpty || isLoading || currentSession != null
                  ? null
                  : _callNextCustomer,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                elevation: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.call, size: 28),
                  const SizedBox(width: 16),
                  Text(
                    queue.isEmpty
                        ? "No Waiting Customers"
                        : currentSession != null
                            ? "Session Active"
                            : "CALL NEXT CUSTOMER",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (queue.isNotEmpty && currentSession == null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "$queueSize",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Queue list
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green))
                : queue.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.people_outline,
                                size: 100, color: Colors.grey),
                            SizedBox(height: 24),
                            Text("No customers waiting",
                                style: TextStyle(
                                    fontSize: 22, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: queue.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final session = queue[index];
                          final status =
                              session['status']?.toString() ?? 'UNKNOWN';

                          return Card(
                            elevation: 6,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(20),
                              leading: CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.orange.shade100,
                                child: Text(
                                  "${index + 1}",
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
                                ),
                              ),
                              title: Text(
                                session['customer']['name'] ??
                                    'Unknown Customer',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 18),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      "Session #${session['sessionNumber'] ?? 'N/A'}"),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(status)
                                          .withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _getStatusColor(status),
                                          width: 1.5),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color: _getStatusColor(status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (status == 'CALLED')
                                    IconButton(
                                      onPressed: () => _startSession(session),
                                      icon: const Icon(Icons.check_circle,
                                          color: Colors.green),
                                      tooltip: "Accept & Start",
                                    ),
                                  if (status == 'IN_PROGRESS' ||
                                      status == 'CUSTOMER_JOINED')
                                    IconButton(
                                      onPressed: () => _completeSession(
                                          session['sessionId']),
                                      icon: const Icon(Icons.check,
                                          color: Colors.green),
                                      tooltip: "Complete",
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
