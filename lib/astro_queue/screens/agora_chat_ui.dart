// import 'dart:async';
// import 'package:agora_chat_uikit/chat_uikit.dart';
// import 'package:flutter/material.dart';
// import 'package:permission_handler/permission_handler.dart';

// class AgoraChatScreen extends StatefulWidget {
//   final bool isCustomer;
//   final String currentUserId;
//   final String peerUserId;

//   const AgoraChatScreen({
//     super.key,
//     required this.isCustomer,
//     required this.currentUserId,
//     required this.peerUserId,
//   });

//   @override
//   State<AgoraChatScreen> createState() => _AgoraChatScreenState();
// }

// class _AgoraChatScreenState extends State<AgoraChatScreen> {
//   // CONFIG - Ensure these are correct from your Agora Console
//   static const String chatAppKey = "6110025533#1665686";
//   static const String rtcAppId = "a94a17cb651a4b769c2adb116a2bdc04";

//   bool _isLoading = true;
//   String? _errorMessage;

//   @override
//   void initState() {
//     super.initState();
//     _initializeChat();
//   }

//   Future<void> _initializeChat() async {
//     try {
//       setState(() => _isLoading = true);

//       /// SDK Init
//       await ChatUIKit.instance.init(
//         options: ChatOptions(
//           appKey: "6110025533#1665686",
//           autoLogin: false,
//         ),
//       );

//       await ChatUIKit.instance.loginWithPassword(
//         userId: widget.currentUserId,
//         password: "123456",
//       );

//       print("✅ Chat Login Success");
//     } catch (e) {
//       print("❌ Chat Init Error → $e");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _startAudioCall() async {
//     await Permission.microphone.request();
//     // Your RTC Logic here...
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       // 1. Mandatory for keyboard handling
//       resizeToAvoidBottomInset: true,
//       appBar: AppBar(
//         backgroundColor: const Color(0xFF075E54),
//         title: Text(
//           widget.isCustomer ? "Practitioner" : "Customer",
//           style: TextStyle(color: Colors.white),
//         ),
//         actions: [
//           IconButton(icon: const Icon(Icons.call), onPressed: _startAudioCall),
//         ],
//         iconTheme: IconThemeData(color: Colors.white),
//       ),
//       // 2. Wrap body in a Column + Flexible to stop the RenderFlex Infinity error
//       body: Column(
//         children: [
//           Expanded(
//             child: MessagesView(
//               profile: ChatUIKitProfile.contact(id: widget.peerUserId),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class AgoraChatScreen extends StatefulWidget {
  final bool isCustomer;
  final String currentUserId;
  final String peerUserId;

  const AgoraChatScreen({
    super.key,
    required this.isCustomer,
    required this.currentUserId,
    required this.peerUserId,
  });

  @override
  State<AgoraChatScreen> createState() => _AgoraChatScreenState();
}

class _AgoraChatScreenState extends State<AgoraChatScreen> {
  // CONFIG - Ensure these are correct from your Agora Console
  static const String chatAppKey = "6110025533#1665686";
  static const String rtcAppId = "a94a17cb651a4b769c2adb116a2bdc04";

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);

      /// SDK Init
      await ChatUIKit.instance.init(
        options: ChatOptions(
          appKey: "6110025533#1665686",
          autoLogin: false,
        ),
      );

      await ChatUIKit.instance.loginWithPassword(
        userId: widget.currentUserId,
        password: "123456",
      );

      print("✅ Chat Login Success");
    } catch (e) {
      print("❌ Chat Init Error → $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startAudioCall() async {
    await Permission.microphone.request();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          backgroundColor: const Color(0xFF075E54),
          title: Text(
            widget.isCustomer ? "Practitioner" : "Customer",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
                icon: const Icon(Icons.call), onPressed: _startAudioCall),
          ],
          iconTheme: IconThemeData(color: Colors.white),
        ),
        body: MessagesView(
          profile: ChatUIKitProfile.contact(
            id: widget.peerUserId,
          ),
        ));
  }
}
