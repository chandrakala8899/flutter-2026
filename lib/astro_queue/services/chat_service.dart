import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class ChatService {
  StompClient? _client;
  Function(Map<String, dynamic>) onMessageReceived;

  bool _isConnected = false;
  int? _sessionId;

  ChatService({required this.onMessageReceived});

  void connect(String userId, {required int sessionId}) {
    _sessionId = sessionId;

    _client = StompClient(
      config: StompConfig.sockJS(
        url: 'http://localhost:16679/ws',

        // 🔥 REQUIRED for your backend interceptor
        stompConnectHeaders: {
          'customerId': userId,
        },
        webSocketConnectHeaders: {
          'customerId': userId,
        },

        onConnect: (StompFrame frame) {
          print("✅ WebSocket Connected");
          _isConnected = true;

          _subscribe(sessionId);
        },

        onWebSocketError: (error) {
          print("❌ WebSocket Error: $error");
        },

        onStompError: (frame) {
          print("❌ STOMP Error: ${frame.body}");
        },
      ),
    );

    _client!.activate();
  }

  void _subscribe(int sessionId) {
    print("📡 Subscribing to /topic/chat/$sessionId");

    _client?.subscribe(
      destination: '/topic/chat/$sessionId',
      callback: (frame) {
        print("📩 Received: ${frame.body}");

        if (frame.body != null) {
          final data = json.decode(frame.body!);
          onMessageReceived(data);
        }
      },
    );
  }

  void sendMessage({
    required int sessionId,
    required int senderId,
    required String message,
  }) {
    if (!_isConnected) {
      print("❌ WebSocket not connected yet");
      return;
    }

    print("📤 Sending message");

    _client?.send(
      destination: '/app/chat.send',
      body: json.encode({
        "sessionId": sessionId,
        "senderId": senderId,
        "message": message,
      }),
    );
  }

  

  void disconnect() {
    _client?.deactivate();
    _isConnected = false;
  }
}
