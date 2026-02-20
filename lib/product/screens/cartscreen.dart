import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_learning/colors.dart';
import 'package:flutter_learning/product/model/productmodel.dart';
import 'package:flutter_learning/product/model/cartmmodel.dart';
import 'package:flutter_learning/product/web_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../product_service.dart/production_api.dart';

class CartScreen extends StatefulWidget {
  final List<ProductNodeModel> selectedProducts;
  final VoidCallback? onClose;

  const CartScreen({
    Key? key,
    required this.selectedProducts,
    this.onClose,
  }) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final totalPrice = widget.selectedProducts.fold<double>(
      0.0,
      (sum, p) => sum + (double.tryParse(p.price) ?? 0.0),
    );
    final currency = widget.selectedProducts.isNotEmpty
        ? widget.selectedProducts[0].currency
        : "₹";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("${widget.selectedProducts.length} Items"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              widget.onClose?.call();
            },
          ),
        ],
      ),
      body: widget.selectedProducts.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                // ✅ Products List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.selectedProducts.length,
                    itemBuilder: (context, index) {
                      return _buildCartItem(widget.selectedProducts[index]);
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: primaryColor)),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${widget.selectedProducts.length} items",
                            style: TextStyle(fontSize: 18, color: Colors.black),
                          ),
                          Text(
                            "$currency${totalPrice.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : _proceedToCheckout,
                          icon: isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white),
                                  ),
                                )
                              : const Icon(Icons.payment, size: 28),
                          label: Text(
                            isLoading
                                ? "Creating Cart..."
                                : "Proceed to Checkout",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildEmptyCart() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined,
                  size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text("No items in cart",
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text("Continue Shopping"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildCartItem(ProductNodeModel product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: primaryColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: product.imageUrl,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.image_not_supported),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  "${widget.selectedProducts[0].currency}${product.price}",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: Colors.green, size: 28),
        ],
      ),
    );
  }

  Future<void> _proceedToCheckout() async {
    setState(() => isLoading = true);

    try {
      final cartItems = widget.selectedProducts.map((product) {
        final variantEdges = product.variants?.edges;
        if (variantEdges?.isNotEmpty == true) {
          return CartItemRequest(
            variantId: variantEdges!.first.node!.id, // <-- REQUIRED
            quantity: 1,
          );
        } else {
          // Instead of fallback to product.id, throw
          throw Exception("Product '${product.title}' has no variant ID!");
        }
      }).toList();

      final prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString("email");
      final request = CartCreateRequest(items: cartItems);

      await ProductApiService.createCart(request, email!);

      final checkoutUrl = ProductApiService.lastCheckoutUrl;

      if (checkoutUrl != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutWebView(checkoutUrl: checkoutUrl),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
}
