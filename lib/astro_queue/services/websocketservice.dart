import 'dart:convert';
import 'package:stomp_dart_client/stomp.dart';
import 'package:stomp_dart_client/stomp_config.dart';

class WebSocketService {
  StompClient? _client;

  bool get isConnected => _client?.connected ?? false;

  void connect({
    required int customerId,
    required Function(Map<String, dynamic>) onCustomerUpdate,
    required Function(String) onError,
  }) {
    _client = StompClient(
      config: StompConfig(
        url: 'ws://192.168.0.227:16679/ws',
        stompConnectHeaders: {
          'customerId': customerId.toString(),
        },
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (frame) {
          print("🔥 STOMP CONNECTED");

          _client!.subscribe(
            destination: '/user/queue/session',
            callback: (frame) {
              print("📩 RECEIVED: ${frame.body}");

              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!);
                  onCustomerUpdate(data);
                } catch (e) {
                  print("JSON Error: $e");
                }
              }
            },
          );
        },
        onWebSocketError: (error) {
          print("❌ WebSocket Error: $error");
          onError(error.toString());
        },
        onStompError: (frame) {
          print("❌ STOMP Error: ${frame.body}");
          onError(frame.body ?? "STOMP Error");
        },
        onDisconnect: (frame) {
          print("🔌 STOMP DISCONNECTED");
        },
      ),
    );

    _client!.activate();
  }

  void disconnect() {
    _client?.deactivate();
  }
}
