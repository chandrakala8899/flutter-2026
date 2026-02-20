import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_learning/colors.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

class CheckoutWebView extends StatefulWidget {
  final String checkoutUrl;

  const CheckoutWebView({super.key, required this.checkoutUrl});

  @override
  State<CheckoutWebView> createState() => _CheckoutWebViewState();
}

class _CheckoutWebViewState extends State<CheckoutWebView> {
  late final WebViewController controller;
  bool isPageLoading = true;

  @override
  void initState() {
    super.initState();

    // 🔥 IMPORTANT FOR ANDROID
    if (Platform.isAndroid) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
    }

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print("Started: $url");
            setState(() => isPageLoading = true);
          },
          onPageFinished: (url) {
            print("Finished: $url");
            setState(() => isPageLoading = false);
          },
          onWebResourceError: (error) {
            print("WebView Error: ${error.description}");
          },
          onNavigationRequest: (request) {
            print("Navigating to: ${request.url}");
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Checkout"),
        backgroundColor: primaryColor,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (isPageLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
