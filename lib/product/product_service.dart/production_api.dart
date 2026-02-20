// services/product_api_service.dart - FIXED IMPORT
import 'dart:convert';
import 'package:flutter_learning/product/login/model/cartresponse_model.dart';
import 'package:flutter_learning/product/model/birthdetails_model.dart';
import 'package:flutter_learning/product/model/cartmmodel.dart';
import 'package:flutter_learning/product/model/panchangresponse_model.dart';
import 'package:flutter_learning/product/model/productmodel.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class ProductApiService {
  static const String baseUrl = "https://ebe2-183-82-6-26.ngrok-free.app/api";

  // static const baseUrl = "http://localhost:8080/api/shopify";

  static String? lastCheckoutUrl;

  static Future<List<ProductNodeModel>> fetchProducts() async {
    try {
      final response =
          await http.get(Uri.parse("$baseUrl/shopify/products"), headers: {
        'Content-Type': 'application/json',
      });

      // print('✅ Status: ${response.statusCode}');
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

  static Future<CartresponseModel> createCart(
    CartCreateRequest request,
    String? email,
  ) async {
    try {
      print('🛒 Creating cart with ${request.items.length} items');

      final uri = Uri.parse("$baseUrl/shopify/cart").replace(
        queryParameters: {
          "email": email ?? "",
        },
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(request.toJson()),
      );

      print('✅ Status: ${response.statusCode}');
      print('📦 Raw Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = json.decode(response.body);

        print("🔎 Decoded JSON: $data");

        // ✅ CORRECT extraction (based on YOUR backend)
        final checkoutUrl = data['checkoutUrl'];

        if (checkoutUrl == null || checkoutUrl.toString().isEmpty) {
          throw Exception("Checkout URL not found in response");
        }

        print('🔗 Checkout URL: $checkoutUrl');

        // Save for later use
        lastCheckoutUrl = checkoutUrl;

        return CartresponseModel.fromJson(data);
      }

      throw Exception('Failed to create cart: HTTP ${response.statusCode}');
    } catch (e) {
      print('❌ Cart Error: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> createCartRaw(
      CartCreateRequest request) async {
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

  static Future<PanchangSummaryModel?> getPanchang({
    required BirthDetailsModel birthDetails,
  }) async {
    try {
      final uri = Uri.parse("${baseUrl}/astrology/panchang");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode(birthDetails.toJson()),
      );

      print("PANCHANG STATUS: ${response.statusCode}");
      print("PANCHANG BODY: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return PanchangSummaryModel.fromJson(data);
      } else {
        print("Failed to get panchang");
        return null;
      }
    } catch (e) {
      print("Error getting panchang: $e");
      return null;
    }
  }

  static Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
