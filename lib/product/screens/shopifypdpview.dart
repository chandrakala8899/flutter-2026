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
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          //         onPageFinished: (url) async {
          //           await controller.runJavaScript("""
          //           // Remove header
          //           document.querySelectorAll('header, .header-group')
          //             .forEach(el => el.remove());

          //           // Remove footer
          //           document.querySelectorAll('footer, .footer-group')
          //             .forEach(el => el.remove());

          //             // Remove announcement / top bars
          // document.querySelectorAll(
          //   '.announcement-bar, .announcement, .utility-bar, .top-bar'
          // ).forEach(el => el.remove());
          //         """);
          //         },
          // onPageFinished: (url) async {
          //           await controller.runJavaScript("""
          //   // Inject CSS instantly
          //   const style = document.createElement('style');
          //   style.innerHTML = `
          //     header,
          //     footer,
          //     .header-group,
          //     .footer-group,
          //     .announcement-bar,
          //     .announcement,
          //     .utility-bar,
          //     .top-bar {
          //       display: none !important;
          //     }
          //   `;
          //   document.head.appendChild(style);
          // """);
          //         },
          onPageFinished: (url) async {
            await controller.runJavaScript("""
  const style = document.createElement('style');
  style.innerHTML = `
    header,
    footer,
    .header-group,
    .footer-group,
    .announcement-bar,
    .announcement,
    .utility-bar,
    .top-bar,
    .shopify-section-header,
    .shopify-section-group-header-group,
    .shopify-section-group-overlay-group {
      display: none !important;
    }
 
    body, html {
      padding-top: 0 !important;
      margin-top: 0 !important;
    }
  `;
  document.head.appendChild(style);
""");

            await Future.delayed(const Duration(milliseconds: 10));

            setState(() {
              _isLoaded = true;
            });
          },
        ),
      )
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
      body: Stack(
        children: [
          Opacity(
            opacity: _isLoaded ? 1 : 0,
            child: WebViewWidget(controller: controller),
          ),
          if (!_isLoaded) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
