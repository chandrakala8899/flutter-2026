import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';

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
  bool isLoading = true;
  List<ConsultationSessionResponse> waitingSessions = [];

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    try {
      final sessions = await ApiService.getCustomerSessions(
        customerId: widget.customerId,
        statuses: ["WAITING"],
      );

      setState(() {
        waitingSessions = sessions
            .where((s) => s.consultant!.id == widget.consultantId)
            .toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

Future<void> _joinSession(ConsultationSessionResponse session) async {
  try {
    final joinData = await ApiService.joinSession(
      sessionId: session.sessionId!,
      userId: widget.customerId,
      context: context,
    );

    if (joinData == null || !mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          session: session,
          joinData: joinData,
        ),
      ),
    );
  } catch (e) {
    print("Queue join failed: $e");
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Waiting Queue"),
        backgroundColor: Colors.orange,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : waitingSessions.isEmpty
              ? const Center(child: Text("No waiting sessions"))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: waitingSessions.length,
                  itemBuilder: (context, index) {
                    final session = waitingSessions[index];

                    return Card(
                      child: ListTile(
                        leading:
                            const Icon(Icons.schedule, color: Colors.orange),
                        title: Text("Session #${session.sessionNumber}"),
                        subtitle: const Text("Waiting for consultant"),
                        trailing: ElevatedButton(
                          onPressed: () => _joinSession(session),
                          child: const Text("Join"),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
