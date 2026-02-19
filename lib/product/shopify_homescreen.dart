import 'package:flutter/material.dart';
import 'package:flutter_learning/product/category_freesection.dart';
import 'package:flutter_learning/product/production_screen.dart';

class ShopifyHomescreen extends StatefulWidget {
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
        title: Text(
          "Shopify",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
      ),
      body: CustomScrollView(
        // ✅ Single scrollable container
        slivers: [
          // Category Section
          SliverToBoxAdapter(
            child: SizedBox(
              height: 140, // ✅ Fixed height constraint
              child: CategoryFreesection(),
            ),
          ),

          // Products Grid
          SliverFillRemaining(
            hasScrollBody: false, // ✅ Disable nested scrolling
            child: ProductsScreen(),
          ),
        ],
      ),
    );
  }
}
