// services/product_api_service.dart - FIXED IMPORT
import 'dart:convert';
import 'package:flutter_learning/product/model/cartmmodel.dart';
import 'package:flutter_learning/product/model/productmodel.dart';
import 'package:http/http.dart' as http;

class ProductApiService {
  static const String baseUrl = "http://localhost:8080/api/shopify";

  static String? lastCheckoutUrl;

  static Future<List<ProductNodeModel>> fetchProducts() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/products"),
        headers: {'Content-Type': 'application/json'},
      );

      print('✅ Status: ${response.statusCode}');
      print('📦 Response length: ${response.body.length}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        // Direct parsing for your exact JSON structure
        final productsData =
            data['data']['products']['edges'] as List<dynamic>? ?? [];

        final List<ProductNodeModel> products = [];
        for (var edge in productsData) {
          if (edge['node'] != null) {
            final product = ProductNodeModel.fromJson(edge['node']);
            products.add(product);
            print('✅ Product: ${product.title} - ₹${product.price}');
          }
        }

        print('🎉 TOTAL PRODUCTS: ${products.length}');
        return products;
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      print('❌ ERROR: $e');
      rethrow;
    }
  }

  static Future<List<ProductNodeModel>> createCart(
      CartCreateRequest request) async {
    try {
      print('🛒 Creating cart with ${request.items.length} items');

      final response = await http.post(
        Uri.parse("$baseUrl/cart"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      print('✅ Status: ${response.statusCode}');
      print('📦 Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);

        // ✅ EXTRACT CHECKOUT URL FIRST (your Shopify structure)
        lastCheckoutUrl = data['data']?['cartCreate']?['cart']?['checkoutUrl'];
        print('🔗 Checkout URL: $lastCheckoutUrl');

        // ✅ Handle different response structures for products
        List<ProductNodeModel> products = [];

        // Case 1: Shopify-style products.edges response
        if (data['data']?['products']?['edges'] != null) {
          final productsData =
              data['data']['products']['edges'] as List<dynamic>;
          products = productsData
              .where((edge) => edge['node'] != null)
              .map((edge) => ProductNodeModel.fromJson(edge['node']))
              .toList();
        }
        // Case 2: Direct cart items array
        else if (data['cart']?['lines'] != null) {
          final cartLines = data['cart']['lines'] as List<dynamic>;
          products = cartLines
              .where((line) => line['merchandise'] != null)
              .map((line) => ProductNodeModel.fromJson(line['merchandise']))
              .toList();
        }
        // Case 3: Simple array response
        else if (data['items'] != null) {
          final items = data['items'] as List<dynamic>;
          products =
              items.map((item) => ProductNodeModel.fromJson(item)).toList();
        }

        print('🎉 Cart created with ${products.length} products');
        print('✅ Products: ${products.map((p) => p.title).toList()}');
        return products;
      }

      throw Exception('Failed to create cart: HTTP ${response.statusCode}');
    } catch (e) {
      print('❌ Cart Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createCartRaw(CartCreateRequest request) async {
  try {
    print('🛒 Creating RAW cart with ${request.items.length} items');

    final response = await http.post(
      Uri.parse("$baseUrl/cart"),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(request.toJson()),
    );
    
    print('✅ Status: ${response.statusCode}');
    print('📦 Raw Response: ${response.body}');

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> data = json.decode(response.body);
      
      // ✅ Store checkout URL even in raw method
      lastCheckoutUrl = data['data']?['cartCreate']?['cart']?['checkoutUrl'];
      print('🔗 Checkout URL saved: $lastCheckoutUrl');
      
      return data;
    }

    throw Exception('Failed to create cart: HTTP ${response.statusCode}');
  } catch (e) {
    print('❌ Raw Cart Error: $e');
    rethrow;
  }
}

}
