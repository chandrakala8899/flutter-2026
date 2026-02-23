// import 'dart:async';
// import 'dart:convert';
// import 'dart:typed_data';
// import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:web_socket_channel/status.dart' as status;

// class StompClient {
//   WebSocketChannel? _channel;

//   final int customerId;
//   final int consultantId;

//   Function()? onConnect;
//   Function()? onDisconnect;
//   Function(Map<String, dynamic>)? onCustomerUpdate;
//   Function(Map<String, dynamic>)? onQueueUpdate;
//   Function(String)? onError;

//   bool _connected = false;
//   Timer? _heartbeatTimer;

//   StompClient({
//     required this.customerId,
//     required this.consultantId,
//   });

//   bool get isConnected => _connected;

//   void connect() {
//     if (_connected) return;

//     try {
//       // 🔥 CHANGE THIS BASED ON DEVICE
//       final wsUrl = 'ws://10.0.2.2:16679/ws'; 
//       print("🔌 Connecting to $wsUrl");

//       _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

//       _channel!.stream.listen(
//         (data) => _handleMessage(data),
//         onError: (error) {
//           _connected = false;
//           onError?.call(error.toString());
//           _stopHeartbeat();
//         },
//         onDone: () {
//           _connected = false;
//           onDisconnect?.call();
//           _stopHeartbeat();
//         },
//       );

//       _sendFrame('CONNECT', {
//         'accept-version': '1.1,1.0',
//         'heart-beat': '10000,10000',
//       });
//     } catch (e) {
//       onError?.call(e.toString());
//     }
//   }

//   void _handleMessage(dynamic raw) {
//     final bytes = raw is Uint8List ? raw : Uint8List.fromList(raw);
//     final message = utf8.decode(bytes).trimRight();

//     final lines = message.split('\n');
//     if (lines.isEmpty) return;

//     final command = lines.first.trim();

//     if (command == 'CONNECTED') {
//       _connected = true;
//       onConnect?.call();
//       _subscribe();
//       _startHeartbeat();
//       return;
//     }

//     if (command != 'MESSAGE') return;

//     int i = 1;
//     while (i < lines.length && lines[i].trim().isNotEmpty) i++;

//     final headers = <String, String>{};
//     for (int j = 1; j < i; j++) {
//       final line = lines[j];
//       final idx = line.indexOf(':');
//       if (idx > 0) {
//         headers[line.substring(0, idx)] = line.substring(idx + 1);
//       }
//     }

//     final body =
//         lines.skip(i + 1).join('\n').replaceAll('\0', '').trim();

//     if (body.isEmpty) return;

//     final destination = headers['destination'] ?? '';
//     final payload = jsonDecode(body);

//     print("📨 DEST: $destination | DATA: $payload");

//     if (destination.startsWith('/topic/customer/$customerId')) {
//       onCustomerUpdate?.call(payload);
//     } else if (destination.startsWith('/topic/queue/$consultantId')) {
//       onQueueUpdate?.call(payload);
//     }
//   }

//   void _subscribe() {
//     // 🔥 Subscribe to customer updates
//     _sendFrame('SUBSCRIBE', {
//       'id': 'customer-$customerId',
//       'destination': '/topic/customer/$customerId',
//     });

//     // 🔥 Subscribe to queue updates
//     _sendFrame('SUBSCRIBE', {
//       'id': 'queue-$consultantId',
//       'destination': '/topic/queue/$consultantId',
//     });
//   }

//   void _startHeartbeat() {
//     _heartbeatTimer?.cancel();
//     _heartbeatTimer =
//         Timer.periodic(const Duration(seconds: 10), (_) {
//       if (_connected) {
//         _channel?.sink.add('\n');
//       }
//     });
//   }

//   void _stopHeartbeat() {
//     _heartbeatTimer?.cancel();
//   }

//   void _sendFrame(String command, Map<String, String> headers,
//       [String? body]) {
//     final buffer = StringBuffer();
//     buffer.writeln(command);

//     headers.forEach((key, value) {
//       buffer.writeln('$key:$value');
//     });

//     buffer.writeln('');

//     if (body != null) buffer.writeln(body);

//     buffer.write('\0');

//     _channel?.sink.add(buffer.toString());
//   }

//   void disconnect() {
//     if (_connected) {
//       _sendFrame('DISCONNECT', {});
//     }
//     _channel?.sink.close(status.goingAway);
//     _stopHeartbeat();
//     _connected = false;
//   }
// }