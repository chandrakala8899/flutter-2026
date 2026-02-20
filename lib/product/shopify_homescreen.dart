import 'package:flutter/material.dart';
import 'package:flutter_learning/colors.dart';
import 'package:flutter_learning/product/screens/category_freesection.dart';
import 'package:flutter_learning/product/production_screen.dart';

class ShopifyHomescreen extends StatefulWidget {
  // ✅ Proper class name
  const ShopifyHomescreen({super.key});

  @override
  State<ShopifyHomescreen> createState() => _ShopifyHomescreenState();
}

class _ShopifyHomescreenState extends State<ShopifyHomescreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          "Shopify",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 125,
              child: CategoryFreesection(),
            ),
          ),

          // Products Grid
          SliverFillRemaining(
            hasScrollBody: false,
            child: ProductsScreen(),
          ),
        ],
      ),
    );
  }
}
