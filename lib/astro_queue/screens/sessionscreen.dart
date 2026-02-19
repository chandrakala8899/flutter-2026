import 'package:flutter/material.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';

class SessionScreen extends StatefulWidget {
  final SessionModel session;
  final bool isCustomer;

  const SessionScreen(
      {super.key, required this.session, required this.isCustomer});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final List<String> messages = [];

  void nextStatus() {
    setState(() {
      switch (widget.session.status) {
        case SessionStatus.created:
          widget.session.status = SessionStatus.waiting;
          break;
        case SessionStatus.waiting:
          widget.session.status = SessionStatus.called;
          break;
        case SessionStatus.called:
          widget.session.status = SessionStatus.inProgress;
          break;
        case SessionStatus.inProgress:
          widget.session.status = SessionStatus.completed;
          break;
        case SessionStatus.completed:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          AppBar(title: Text("Session - ${widget.session.status.name}")),
      body: Column(
        children: [
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: nextStatus,
            child: const Text("Next Status"),
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: messages
                  .map((m) => ListTile(title: Text(m)))
                  .toList(),
            ),
          ),
          if (widget.session.status == SessionStatus.inProgress)
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                onSubmitted: (value) {
                  setState(() {
                    messages.add(value);
                  });
                },
                decoration:
                    const InputDecoration(labelText: "Type message"),
              ),
            )
        ],
      ),
    );
  }
}
