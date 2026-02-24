import 'package:flutter/material.dart';
import 'package:flutter_learning/colors.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ShopifyPdpScreen extends StatefulWidget {
  final String handle;

  const ShopifyPdpScreen({super.key, required this.handle});

  @override
  State<ShopifyPdpScreen> createState() => _ShopifyPdpScreenState();
}

class _ShopifyPdpScreenState extends State<ShopifyPdpScreen> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("aumraa_app_webview")
      ..loadRequest(
        Uri.parse(
          "https://aumraadev.myshopify.com/products/${widget.handle}",
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Details"),
        backgroundColor: primaryColor,
      ),
      body: WebViewWidget(controller: controller),
    );
  }
}
