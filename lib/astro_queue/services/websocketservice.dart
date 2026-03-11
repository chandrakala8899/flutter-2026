import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  StompClient? _client;

  void connect({
    required int userId,
    required Function(Map<String, dynamic>) onSessionUpdate,
    Function(Map<String, dynamic>)? onQueueUpdate,
    // OLD (still supported for now)
    Function(Map<String, dynamic>)? onExpiryNotification,
    // 🔥 NEW - Recommended (receives all 3 session events)
    Function(Map<String, dynamic>)? onSessionEvent,
    required Function(String) onError,
    bool isPractitioner = false,
  }) {
    final String wsUrl = "ws://localhost:16679/ws/websocket";

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: {"userId": userId.toString()},
        reconnectDelay: const Duration(seconds: 5),
        // 🔥 HEARTBEAT ADDED - This fixes "STOMP Disconnected" issue
        heartbeatOutgoing: const Duration(seconds: 10),
        heartbeatIncoming: const Duration(seconds: 10),
        onConnect: (frame) {
          print(
              "✅ STOMP Connected - User ID: $userId | Role: ${isPractitioner ? 'Practitioner' : 'Customer'}");

          // PERSONAL SESSION UPDATES (status changes, incoming_call, live session_extended, etc.)
          _client?.subscribe(
            destination: "/user/queue/session",
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;

                  if (data['type'] == 'incoming_call' ||
                      data['type'] == 'session_extended') {
                    print("📨 Received ${data['type']} on /user/queue/session");
                    onSessionUpdate(data);
                    return;
                  }

                  onSessionUpdate(data);
                } catch (e) {
                  print("❌ Parse error on /user/queue/session: $e");
                }
              }
            },
          );

          // QUEUE UPDATES (practitioner only)
          if (onQueueUpdate != null) {
            _client?.subscribe(
              destination: "/topic/queue/$userId",
              callback: (frame) {
                if (frame.body != null) {
                  try {
                    onQueueUpdate(jsonDecode(frame.body!));
                  } catch (e) {
                    print("❌ Queue parse error: $e");
                  }
                }
              },
            );
          }
          // EXPIRY_WARNING, SESSION_EXPIRED, SESSION_EXTENDED
          _client?.subscribe(
            destination: "/user/queue/session-events",
            callback: (frame) {
              print("🔴 RAW session-events: ${frame.body}");
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  final eventType = data['eventType'];

                  print("⏳ SESSION EVENT RECEIVED → $eventType");
                  onSessionEvent?.call(data);
                  if (onExpiryNotification != null &&
                      (eventType == 'EXPIRY_WARNING' ||
                          eventType == 'SESSION_EXPIRED')) {
                    onExpiryNotification(data);
                  }
                } catch (e) {
                  print("❌ Session event parse error: $e");
                }
              }
            },
          );

          // General session topic updates (keep this)
          _client?.subscribe(
            destination: "/topic/session/*",
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!) as Map<String, dynamic>;
                  onSessionUpdate(data);
                } catch (_) {}
              }
            },
          );
        },
        onWebSocketError: (error) => onError(error.toString()),
        onStompError: (frame) => onError(frame.body ?? "STOMP error"),
        onDisconnect: (frame) =>
            print("❌ STOMP Disconnected - Auto-reconnect in 5 seconds..."),
      ),
    );

    _client?.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}
