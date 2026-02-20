// lib/services/stomp_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class StompService {
  
  WebSocketChannel? _channel;
  final String baseUrl;
  final int consultantId;

  Function(Map<String, dynamic>)? onQueueUpdate;
  Function(Map<String, dynamic>)? onSessionUpdate;
  bool _connected = false;

  StompService({required this.baseUrl, required this.consultantId});

  void connect() {
    try {
      final wsUrl = baseUrl.replaceAll('http', 'ws') + '/ws/websocket';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _channel!.stream.listen(
        (data) => _handleMessage(data),
        onError: (error) => print('STOMP Error: $error'),
        onDone: () {
          print('STOMP Disconnected');
          _connected = false;
        },
      );

      // Send STOMP CONNECT
      _sendStompFrame('CONNECT',
          {'accept-version': '1.1,1.0', 'heart-beat': '10000,10000'});
    } catch (e) {
      print('STOMP Connect Error: $e');
    }
  }

  // ✅ FIXED: Proper method signature
  void _sendStompFrame(String command, Map<String, String> headers,
      [String? body]) {
    final buffer = StringBuffer();
    buffer.writeln(command);

    headers.forEach((key, value) {
      buffer.writeln('$key:$value');
    });

    buffer.writeln('');
    if (body != null) buffer.writeln(body);
    buffer.writeln('\0'); // STOMP NULL terminator

    final frame = utf8.encode(buffer.toString());
    _channel?.sink.add(frame);
  }

  void _handleMessage(dynamic data) {
    final message = utf8.decode(data is Uint8List ? data : [data]);
    print('STOMP Raw: $message');

    if (message.contains('CONNECTED')) {
      print('✅ STOMP Connected!');
      _connected = true;
      _subscribeQueue();
      _subscribeSession();
      return;
    }

    // Parse MESSAGE frames
    if (message.startsWith('MESSAGE')) {
      final jsonStr = message
          .split('\n')
          .lastWhere((line) => line.isNotEmpty && !line.startsWith(':'));
      try {
        final data = json.decode(jsonStr);
        _dispatchMessage(data);
      } catch (e) {
        print('JSON Parse Error: $e');
      }
    }
  }

  void _dispatchMessage(Map<String, dynamic> data) {
    final destination = data['destination'] ?? '';
    if (destination.contains('queue-update-$consultantId')) {
      onQueueUpdate?.call(data);
    } else if (destination.contains('session-update-$consultantId')) {
      onSessionUpdate?.call(data);
    }
  }

  void _subscribeQueue() {
    _sendStompFrame('SUBSCRIBE', {
      'id': 'sub-queue-$consultantId',
      'destination': '/topic/queue/$consultantId',
    });
  }

  void _subscribeSession() {
    _sendStompFrame('SUBSCRIBE', {
      'id': 'sub-session-$consultantId',
      'destination': '/topic/session/$consultantId',
    });
  }

  // ✅ FIXED: Disconnect only needs command (empty headers)
  void disconnect() {
    if (_connected) {
      _sendStompFrame('DISCONNECT', {});
    }
    _channel?.sink.close(status.goingAway);
    _connected = false;
  }
}
