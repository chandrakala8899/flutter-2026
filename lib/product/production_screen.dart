import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/product/cartscreen.dart';
import 'package:flutter_learning/product/model/cartmmodel.dart';
import 'package:flutter_learning/product/model/productmodel.dart';
import 'product_details.dart';
import 'production_api.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<ProductNodeModel> products = [];
  List<ProductNodeModel> selectedProducts = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    setState(() => isLoading = true);
    try {
      final fetchedProducts = await ProductApiService.fetchProducts();
      setState(() {
        products = fetchedProducts;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _toggleProduct(ProductNodeModel product) {
    setState(() {
      if (selectedProducts.contains(product)) {
        selectedProducts.remove(product);
      } else {
        selectedProducts.add(product);
      }
    });
  }

  Future<void> _addSelectedToCart() async {
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select products first!")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Adding ${selectedProducts.length} items...")),
    );

    try {
      final cartItems = selectedProducts.map((product) {
        final variantEdges = product.variants?.edges;
        final variantId = variantEdges?.isNotEmpty == true
            ? variantEdges!.first.node!.id
            : product.id;
        return CartItemRequest(variantId: variantId, quantity: 1);
      }).toList();

      final request = CartCreateRequest(items: cartItems);
      await ProductApiService.createCart(request);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("✅ Added ${selectedProducts.length} items to cart!"),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => selectedProducts.clear());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Spiritual Products",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: fetchProducts,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchProducts,
        color: Colors.deepPurple,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.deepPurple))
            : error != null
                ? SingleChildScrollView(child: _buildErrorWidget())
                : products.isEmpty
                    ? SingleChildScrollView(child: _buildEmptyWidget())
                    : _buildProductsGrid(),
      ),
      floatingActionButton:
          selectedProducts.isNotEmpty ? _buildCartFAB() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // All other methods unchanged...
  Widget _buildCartFAB() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade400],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Cart (${selectedProducts.length})",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: selectedProducts.isNotEmpty ? _showCartScreen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                minimumSize: const Size(60, 30),
              ),
              child: const Text(
                "VIEW",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCartScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CartScreen(
          selectedProducts: selectedProducts,
          onClose: () => setState(() {}),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  Widget _buildErrorWidget() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            "Failed to load products",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            error ?? "Unknown error",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: fetchProducts,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            "No spiritual products found",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            "Pull down to refresh or check back later",
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ✅ PERFECT NO-OVERFLOW GRID
  Widget _buildProductsGrid() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.78, // ✅ PERFECT RATIO - NO OVERFLOW
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          final isSelected = selectedProducts.contains(product);
          return _buildProductCard(product, isSelected);
        },
      ),
    );
  }

  Widget _buildProductCard(ProductNodeModel product, bool isSelected) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(
              product: product,
              onAddToCart: () => _toggleProduct(product),
            ),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple.shade400 : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🖼️ IMAGE - FIXED HEIGHT
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl:
                        product.imageUrl.isNotEmpty ? product.imageUrl : '',
                    height: 120, // ← REDUCED to 120px (FIX #1)
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 120,
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 120,
                      color: Colors.grey.shade200,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 35,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4), // ← SMALLER badge
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.shade600,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14, // ← SMALLER icon
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // 📱 CONTENT - BULLETPROOF LAYOUT
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    10, 8, 10, 6), // ← EVEN TIGHTER (FIX #2)
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title - SINGLE LINE ONLY
                    SizedBox(
                      height: 18, // ← FIXED HEIGHT (FIX #3)
                      child: Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5, // ← SMALLER font
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3), // ← MINIMAL spacing

                    // Price + Rating - ULTRA COMPACT
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${product.currency} ${product.price}",
                            style: const TextStyle(
                              fontSize: 13.5, // ← SMALLER
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7B1FA2),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5, // ← TIGHTER
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade400,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 11),
                              SizedBox(width: 1),
                              Text(
                                "4.8",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Button - SMALLEST POSSIBLE
                    SizedBox(
                      width: double.infinity,
                      height: 24, // ← REDUCED to 32px (FIX #4)
                      child: ElevatedButton(
                        onPressed: () => _toggleProduct(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.green.shade600
                              : const Color(0xFF7B1FA2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        child: Text(
                          isSelected ? "SELECTED" : "ADD",
                          style: const TextStyle(
                            fontSize: 11.5, // ← SMALLEST font
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
