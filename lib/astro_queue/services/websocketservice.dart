// import 'dart:convert';
// import 'package:stomp_dart_client/stomp_dart_client.dart';

// class WebSocketService {
//   StompClient? _client;

//   void connect({
//     required int userId, // customerId or consultantId
//     required Function(Map<String, dynamic>) onSessionUpdate, // personal session messages
//     Function(Map<String, dynamic>)? onQueueUpdate,          // optional - queue updates (practitioner)
//     required Function(String) onError,
//   }) {
//     final String wsUrl = "ws://localhost:16679/ws/websocket";

//     _client = StompClient(
//       config: StompConfig(
//         url: wsUrl,
//         stompConnectHeaders: {
//           "customerId": userId.toString(), // backend uses this header
//         },
//         reconnectDelay: const Duration(seconds: 5),
//         connectionTimeout: Duration(seconds: 60),
//         onConnect: (frame) {
//           print("STOMP Connected - User ID: $userId");

//           // Personal session updates (/user/queue/session) - both customer & practitioner use this
//           _client?.subscribe(
//             destination: "/user/queue/session",
//             callback: (frame) {
//               if (frame.body != null) {
//                 try {
//                   final data = jsonDecode(frame.body!);
//                   onSessionUpdate(data);
//                 } catch (e) {
//                   print("Session parse error: $e - Body: ${frame.body}");
//                 }
//               }
//             },
//           );

//           // Queue updates (/topic/queue/{id}) - mainly for practitioner
//           if (onQueueUpdate != null) {
//             _client?.subscribe(
//               destination: "/topic/queue/$userId",
//               callback: (frame) {
//                 if (frame.body != null) {
//                   try {
//                     final data = jsonDecode(frame.body!);
//                     onQueueUpdate(data);
//                   } catch (e) {
//                     print("Queue parse error: $e - Body: ${frame.body}");
//                   }
//                 }
//               },
//             );
//           }
//         },
//         onWebSocketError: (error) {
//           onError(error.toString());
//         },
//         onStompError: (frame) {
//           onError(frame.body ?? "STOMP protocol error");
//         },
//       ),
//     );

//     _client?.activate();
//   }

//   void disconnect() {
//     _client?.deactivate();
//     _client = null;
//   }
// }

import 'dart:convert';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class WebSocketService {
  StompClient? _client;

  void connect({
    required int userId,
    required Function(Map<String, dynamic>) onSessionUpdate,
    Function(Map<String, dynamic>)? onIncomingCall, // ← NEW for ringing
    Function(Map<String, dynamic>)? onQueueUpdate,
    required Function(String) onError,
  }) {
    final String wsUrl = "ws://localhost:16679/ws/websocket";

    _client = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: {"customerId": userId.toString()},
        reconnectDelay: const Duration(seconds: 5),
        onConnect: (frame) {
          print("✅ STOMP Connected - User ID: $userId");

          // Personal session updates (includes incoming_call)
          _client?.subscribe(
            destination: "/user/queue/session",
            callback: (frame) {
              if (frame.body != null) {
                try {
                  final data = jsonDecode(frame.body!);

                  // 🔥 AUTO DETECT INCOMING CALL
                  if (data['type'] == 'incoming_call' &&
                      onIncomingCall != null) {
                    print("📲 Incoming call detected!");
                    onIncomingCall(data);
                    return;
                  }

                  onSessionUpdate(data);
                } catch (e) {
                  print("Parse error: $e");
                }
              }
            },
          );

          // Queue updates (your old code)
          if (onQueueUpdate != null) {
            _client?.subscribe(
              destination: "/topic/queue/$userId",
              callback: (frame) {
                if (frame.body != null) {
                  try {
                    onQueueUpdate(jsonDecode(frame.body!));
                  } catch (_) {}
                }
              },
            );
          }
        },
        onWebSocketError: (error) => onError(error.toString()),
        onStompError: (frame) => onError(frame.body ?? "STOMP error"),
      ),
    );

    _client?.activate();
  }

  void disconnect() {
    _client?.deactivate();
    _client = null;
  }
}
