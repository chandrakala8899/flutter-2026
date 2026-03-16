import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/api_service.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/screens/chat_screen.dart';
import 'package:flutter_learning/astro_queue/screens/session_option_screen.dart';
import 'package:flutter_learning/astro_queue/screens/sessionscreen.dart';
import 'package:flutter_learning/astro_queue/screens/vedio_call_screen.dart';
import 'package:flutter_learning/astro_queue/services/chat_service.dart';

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
  late ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _loadSessions();
    _chatService = ChatService();
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

  void _joinSession(ConsultationSessionResponse session) {
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

  // void _joinSession(ConsultationSessionResponse session) {
  //   Navigator.push(
  //     context,
  //     MaterialPageRoute(
  //       builder: (_) => SessionOptionScreen(
  //         session: session,
  //         isCustomer: true,
  //         // channelName: session.sessionId.toString(),
  //       ),
  //     ),
  //   );
  // }

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
