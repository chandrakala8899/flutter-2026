import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_learning/product/model/productmodel.dart';
import 'package:flutter_learning/product/model/cartmmodel.dart';
import 'package:flutter_learning/product/web_view.dart';
import 'package:url_launcher/url_launcher.dart';
import 'production_api.dart';

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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("${widget.selectedProducts.length} Items"),
        backgroundColor: Colors.deepPurple,
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

                // ✅ ONLY Proceed Button + Total
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "${widget.selectedProducts.length} items",
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey[600]),
                          ),
                          Text(
                            "$currency${totalPrice.toStringAsFixed(0)}",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
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
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 12,
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
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
        final variantId = variantEdges?.isNotEmpty == true
            ? variantEdges!.first.node!.id
            : product.id;
        return CartItemRequest(variantId: variantId, quantity: 1);
      }).toList();

      final request = CartCreateRequest(items: cartItems);

      // ✅ This works perfectly - stores checkout URL
      await ProductApiService.createCart(request);

      final checkoutUrl = ProductApiService.lastCheckoutUrl;

      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl!);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CheckoutWebView(
              checkoutUrl: checkoutUrl!,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Checkout opened!")),
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
