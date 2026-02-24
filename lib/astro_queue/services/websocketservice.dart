import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  StompClient? _client;

  void connect({
    required int customerId,
    required Function(Map<String, dynamic>) onCustomerUpdate,
    required Function(String) onError,
  }) {
    final String wsUrl = "ws://localhost:16679/ws/websocket";

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: {
          "customerId": customerId.toString(),
        },
        reconnectDelay: const Duration(seconds: 5),
        connectionTimeout: Duration(seconds: 60),
        onConnect: (frame) {
          print("🔥 STOMP Connected");

          _client?.subscribe(
            destination: "/user/queue/session",
            callback: (frame) {
              if (frame.body != null) {
                onCustomerUpdate(jsonDecode(frame.body!));
              }
            },
          );
        },
        onWebSocketError: (error) {
          onError(error.toString());
        },
        onStompError: (frame) {
          onError(frame.body ?? "STOMP Error");
        },
      ),
    );

    _client?.activate();
  }

  void disconnect() {
    _client?.deactivate();
  }
}
