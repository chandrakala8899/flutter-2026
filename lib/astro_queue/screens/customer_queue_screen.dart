import 'dart:io' as IO;

import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class CustomerQueueScreen extends StatefulWidget {
  final int consultantId;
  final int customerId;

  const CustomerQueueScreen({
    super.key,
    required this.consultantId,
    required this.customerId,
  });

  @override
  State<CustomerQueueScreen> createState() => _CustomerQueueScreenState();
}

class _CustomerQueueScreenState extends State<CustomerQueueScreen> {
  IO.Socket? socket;
  dynamic currentSession;
  int position = -1;
  bool isLoading = false;
  bool showExpiryWarning = false;
  int minutesLeft = 30;

  @override
  void initState() {
    super.initState();
    connectWebSocket();
    // loadSession();
  }

  void connectWebSocket() {
    socket = IO.io('http://localhost:16679',
        IO.OptionBuilder().setTransports(['websocket']).build());

    socket?.onConnect((_) => print('✅ Connected to WebSocket'));

    // ✅ Real-time queue position updates
    socket?.on('queue/${widget.customerId}', (data) {
      setState(() {
        position = data['position'];
      });
    });

    // ✅ Expiry warnings
    socket?.on('queue/expiry', (data) {
      setState(() {
        showExpiryWarning = true;
        minutesLeft = data['minutesLeft'];
      });
    });
  }

  Future<void> createSession() async {
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('http://localhost:16679/api/sessions/create'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'customerId': widget.customerId,
          'consultantId': widget.consultantId,
        }),
      );

      if (response.statusCode == 200) {
        currentSession = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SessionScreen(
              session: currentSession,
              isCustomer: true,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> extendSession() async {
    try {
      await http.post(
        Uri.parse(
            'http://localhost:16679/api/sessions/extend/${currentSession?['sessionId']}'),
      );
      setState(() {
        showExpiryWarning = false;
        minutesLeft = 30;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Session extended 30 mins')),
      );
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎯 Join Consultation"),
        backgroundColor: Colors.orange[600],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Position Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      position > 0 ? "Your Position: #$position" : "Join Queue",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: position > 0 ? Colors.green : Colors.orange[700],
                      ),
                    ),
                    if (position > 0) ...[
                      const SizedBox(height: 10),
                      Text("Session #${currentSession?['sessionNumber']}",
                          style:
                              TextStyle(fontSize: 18, color: Colors.grey[700])),
                    ],
                  ],
                ),
              ),
            ),

            // Expiry Warning
            if (showExpiryWarning)
              Card(
                color: Colors.orange[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange[700], size: 30),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("⚠️ $minutesLeft minutes left!",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange[700])),
                            const Text("Session expires soon!"),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: extendSession,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[600]),
                        child: const Text("Extend"),
                      ),
                    ],
                  ),
                ),
              ),

            const Spacer(),

            // Join Button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: isLoading ? null : createSession,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("🚀 Join Consultation Queue",
                        style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
