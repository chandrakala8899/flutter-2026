import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:flutter_learning/astro_queue/stompservice.dart';

import 'package:http/http.dart' as http;

class PractitionerQueueScreen extends StatefulWidget {
  final int consultantId;
  const PractitionerQueueScreen({super.key, required this.consultantId});

  @override
  State<PractitionerQueueScreen> createState() =>
      _PractitionerQueueScreenState();
}

class _PractitionerQueueScreenState extends State<PractitionerQueueScreen> {
  List<dynamic> queue = [];
  bool isLoading = false;
  dynamic currentSession;
  StompService? stomp;

  int queueSize = 0;

  static const String baseUrl = 'http://10.0.2.2:8080'; // ✅ Emulator URL

  @override
  void initState() {
    super.initState();
    _initStomp();
    _loadInitialData();
  }

  void _initStomp() {
    stomp = StompService(baseUrl: baseUrl, consultantId: widget.consultantId);

    stomp!.onQueueUpdate = (data) {
      if (mounted) {
        setState(() {
          queue = data['queue'] ?? [];
          queueSize = queue.length;
        });
      }
    };

    stomp!.onSessionUpdate = (data) {
      if (mounted) {
        setState(() {
          currentSession = data;
        });
      }
    };

    stomp!.connect();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([loadQueue(), loadCurrentSession()]);
  }

  @override
  void dispose() {
    stomp?.disconnect();
    super.dispose();
  }

  Future<void> loadQueue() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/sessions/queue/${widget.consultantId}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          queue = data;
          queueSize = data.length;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Queue load error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> loadCurrentSession() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/sessions/current/${widget.consultantId}'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty && mounted) {
        setState(() {
          currentSession = json.decode(response.body);
        });
      }
    } catch (e) {
      print('No current session: $e');
    }
  }

  Future<void> callNext() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/sessions/call-next/${widget.consultantId}'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Called next customer!'),
              backgroundColor: Colors.green),
        );
        await Future.wait([loadQueue(), loadCurrentSession()]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Call failed: $e')));
      }
    }
  }

  Future<void> startSession() async {
    if (currentSession == null) return;
    try {
      final response = await http
          .post(
            Uri.parse(
                '$baseUrl/api/sessions/${currentSession['sessionId']}/start'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                SessionScreen(session: currentSession, isCustomer: false),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Start failed: $e')));
    }
  }

  Future<void> completeSession() async {
    if (currentSession == null) return;
    try {
      await http.post(
        Uri.parse(
            '$baseUrl/api/sessions/${currentSession['sessionId']}/complete'),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Session completed!'),
              backgroundColor: Colors.green),
        );
        await Future.wait([loadQueue(), loadCurrentSession()]);
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Complete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("📋 My Queue ($queueSize)"),
        backgroundColor: Colors.orange.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {}
              //  _loadInitialData,
              ),
          const Icon(Icons.wifi, color: Colors.green),
        ],
      ),
      body: Column(
        children: [
          // Current Session Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: currentSession != null ? Colors.green : Colors.grey[300]!,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
            ),
            child: Row(
              children: [
                Icon(currentSession != null ? Icons.videocam : Icons.schedule,
                    color: Colors.white, size: 40),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentSession?['status'] ?? "No Active Session",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      if (currentSession != null) ...[
                        Text(
                            "Customer: ${currentSession?['customer']?['name']}",
                            style: const TextStyle(color: Colors.white70)),
                        Text("Session: #${currentSession?['sessionNumber']}",
                            style: const TextStyle(color: Colors.white70)),
                      ],
                    ],
                  ),
                ),
                if (currentSession != null) ...[
                  ElevatedButton.icon(
                    onPressed: startSession,
                    icon: const Icon(Icons.videocam, color: Colors.orange),
                    label: const Text("Join Call",
                        style: TextStyle(color: Colors.orange)),
                    style:
                        ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: completeSession,
                    icon: const Icon(Icons.check_circle,
                        color: Colors.white, size: 30),
                    tooltip: "Complete",
                  ),
                ],
              ],
            ),
          ),

          // Call Next Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: queue.isEmpty || isLoading ? null : callNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.call, size: 24),
                  const SizedBox(width: 10),
                  Text(queue.isEmpty
                      ? "No Waiting Customers"
                      : "📞 Call Next Customer"),
                ],
              ),
            ),
          ),

          // Queue List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : queue.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 80, color: Colors.grey),
                            SizedBox(height: 20),
                            Text("No customers waiting",
                                style: TextStyle(
                                    fontSize: 20, color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: queue.length,
                        itemBuilder: (context, index) {
                          final customer = queue[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Text("${index + 1}",
                                    style: TextStyle(
                                        color: Colors.orange.shade800)),
                              ),
                              title: Text(customer['customer']['name']),
                              subtitle:
                                  Text("Session #${customer['sessionNumber']}"),
                              trailing: Text(customer['status'],
                                  style: TextStyle(
                                      color: Colors.orange.shade700,
                                      fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
