import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_learning/product/model/productmodel.dart';
import 'package:flutter_learning/product/model/cartmmodel.dart';
import 'production_api.dart';

class MultiCheckoutScreen extends StatefulWidget {
  final List<ProductNodeModel> products;

  const MultiCheckoutScreen({Key? key, required this.products}) : super(key: key);

  @override
  State<MultiCheckoutScreen> createState() => _MultiCheckoutScreenState();
}

class _MultiCheckoutScreenState extends State<MultiCheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // ✅ Create cart items for ALL selected products
      final cartItems = widget.products.map((product) {
        final variantEdges = product.variants?.edges;
        final variantId = variantEdges?.isNotEmpty == true
            ? variantEdges!.first.node!.id
            : product.id;
        return CartItemRequest(variantId: variantId, quantity: 1);
      }).toList();

      final request = CartCreateRequest(items: cartItems);
      await ProductApiService.createCart(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${widget.products.length} items added to cart!"),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Order failed: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  double get _totalPrice {
    return widget.products.fold<double>(
      0,
      (sum, product) => sum + double.parse(product.price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("${widget.products.length} Items Checkout"),
        backgroundColor: Colors.deepPurple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Order Summary - Multiple Products
            _buildOrderSummary(),
            const SizedBox(height: 30),
            
            // Form Fields (same as single checkout)
            _buildTextField(_nameController, "Full Name *", Icons.person),
            const SizedBox(height: 20),
            _buildTextField(_phoneController, "Phone Number *", Icons.phone),
            const SizedBox(height: 20),
            _buildTextField(_addressController, "Delivery Address *", 
                          Icons.location_on, maxLines: 4),
            
            const SizedBox(height: 40),
            _buildTotalAndPayButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepPurple.shade50, Colors.white],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "${widget.products.length}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "Selected Items",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...widget.products.map((product) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: product.imageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.title, 
                           style: const TextStyle(fontWeight: FontWeight.w600),
                           maxLines: 1,
                           overflow: TextOverflow.ellipsis),
                      Text("${product.currency} ${product.price}",
                           style: TextStyle(color: Colors.green[700],
                                         fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total:", 
                         style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text("${widget.products[0].currency} ${_totalPrice.toStringAsFixed(2)}",
                   style: TextStyle(fontSize: 24, 
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, 
                        IconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.deepPurple),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildTotalAndPayButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _placeOrder,
        icon: isLoading 
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.payment),
        label: Text(isLoading 
            ? "Processing..." 
            : "Pay ${_totalPrice.toStringAsFixed(2)}"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }
}
