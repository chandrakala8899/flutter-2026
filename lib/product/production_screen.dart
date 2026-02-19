import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_learning/product/cartscreen.dart';
import 'package:flutter_learning/product/model/cartmmodel.dart';
import 'package:flutter_learning/product/model/productmodel.dart';
import 'product_details.dart';
import 'checkout.dart';
import 'production_api.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({Key? key}) : super(key: key);

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ Added ${selectedProducts.length} items to cart!"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => selectedProducts.clear());
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          "Spiritual Products (${selectedProducts.length})",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.deepPurple,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
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
    );
  }

  // In ProductsScreen - UPDATE the FAB button in _buildCartFAB()
  Widget _buildCartFAB() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade600, Colors.green.shade400],
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_cart, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Cart (${selectedProducts.length})",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: selectedProducts.isNotEmpty ? _showCartScreen : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green.shade700,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                minimumSize: const Size(40, 32),
              ),
              child: const Text("GO",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
          onClose: () => setState(() {}), // Refresh selection
        ),
      ),
    );
  }

  // ✅ FIXED: Wrapped in SingleChildScrollView
  Widget _buildErrorWidget() => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text("Failed to load products",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: fetchProducts,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      );

  // ✅ FIXED: Wrapped in SingleChildScrollView
  Widget _buildEmptyWidget() => Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 24),
            Text("No spiritual products available",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            Text("Pull to refresh for latest collection",
                style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );

  Widget _buildProductsGrid() => Padding(
        padding: const EdgeInsets.all(16.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72, // ✅ Perfect ratio
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

  // ✅ PERFECT ProductCard - ZERO OVERFLOWS!
  Widget _buildProductCard(ProductNodeModel product, bool isSelected) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProductDetailScreen(
            product: product,
            onAddToCart: () => _toggleProduct(product),
          ),
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.transparent,
            width: isSelected ? 2 : 0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image - Fixed height
            Container(
              height: 140, // ✅ Fixed exact height
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    child: CachedNetworkImage(
                      imageUrl:
                          product.imageUrl.isNotEmpty ? product.imageUrl : '',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, size: 40),
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.deepPurple,
                              Colors.deepPurple.shade700
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ✅ FIXED Content - PERFECT spacing (3.4px saved!)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    12, 10, 12, 12), // ✅ Tighter top padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min, // ✅ CRITICAL
                  children: [
                    // Title - Constrained
                    SizedBox(
                      height: 32, // ✅ Fixed height = no overflow
                      child: Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4), // ✅ Reduced from 6px

                    // Price & Rating Row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "${product.currency} ${product.price}",
                            style: TextStyle(
                              fontSize: 15, // ✅ Slightly smaller
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple[800],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2, // ✅ Reduced from 3px
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[100],
                            borderRadius: BorderRadius.circular(8), // ✅ Smaller
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star,
                                  color: Colors.amber[700],
                                  size: 11), // ✅ Smaller icon
                              const SizedBox(width: 1),
                              Text("4.8",
                                  style: TextStyle(
                                    fontSize: 10, // ✅ Smaller text
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                  )),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(), // ✅ Takes remaining space

                    // Button - Fixed size
                    SizedBox(
                      height: 32, // ✅ Perfect fit
                      child: ElevatedButton(
                        onPressed: () => _toggleProduct(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.green.shade600
                              : Colors.deepPurple,
                          foregroundColor: Colors.white,
                          elevation: isSelected ? 0 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          isSelected ? "SELECTED ✓" : "SELECT",
                          style: const TextStyle(
                            fontSize: 11, // ✅ Smaller
                            fontWeight: FontWeight.bold,
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
