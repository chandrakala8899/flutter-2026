import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

class ChatScreen extends StatefulWidget {
  final ConsultationSessionResponse session;
  final Map<String, dynamic> joinData;

  const ChatScreen({
    super.key,
    required this.joinData,
    required this.session,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {

  WebSocketChannel? channel;

  final List<String> messages = [];
  final TextEditingController controller = TextEditingController();

  bool connected = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    initWebSocket();
  }

  /// ✅ WebSocket Connect
  void initWebSocket() {
    try {

      final wsUrl = widget.joinData["wsUrl"]
          ?? "ws://localhost:16679/ws/websocket";

      channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      channel!.stream.listen(
        (data) {
          debugPrint("WS Received: $data");

          setState(() {
            messages.add(data.toString());
          });

        },
        onDone: () {
          setState(() {
            connected = false;
          });
        },
        onError: (error) {
          debugPrint("WS Error: $error");
        },
      );

      setState(() {
        connected = true;
        isLoading = false;
      });

    } catch (e) {
      debugPrint("WS Init Error: $e");

      setState(() {
        isLoading = false;
      });
    }
  }

  /// ✅ Send Message
  void sendMessage() {

    if (controller.text.trim().isEmpty || channel == null) return;

    final message = {
      "sessionId": widget.session.sessionId,
      "senderId": widget.joinData["userId"],
      "message": controller.text.trim()
    };

    channel!.sink.add(jsonEncode(message));

    setState(() {
      messages.add("Me: ${controller.text.trim()}");
    });

    controller.clear();
  }

  /// ✅ Cleanup
  @override
  void dispose() {
    channel?.sink.close();
    controller.dispose();
    super.dispose();
  }

  /// ✅ UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(connected ? "Chat Online" : "Connecting..."),
        backgroundColor: connected ? Colors.green : Colors.orange,
        foregroundColor: Colors.white,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())

          : Column(
              children: [

                /// Messages List
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Text("No messages yet 👋"),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: messages.length,
                          itemBuilder: (context, i) {

                            final msg = messages[i];
                            final isMe = msg.startsWith("Me");

                            return Align(
                              alignment: isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(msg),
                              ),
                            );
                          },
                        ),
                ),

                /// Input Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black.withOpacity(0.05),
                        offset: const Offset(0, -2),
                      )
                    ],
                  ),

                  child: Row(
                    children: [

                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: "Type message...",
                          ),
                          onSubmitted: (_) => sendMessage(),
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: sendMessage,
                      )
                    ],
                  ),
                )
              ],
            ),
    );
  }
}