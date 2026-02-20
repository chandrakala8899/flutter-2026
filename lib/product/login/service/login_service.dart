import 'dart:convert';

import 'package:flutter_learning/product/login/model/customer_login_model.dart';
import 'package:flutter_learning/product/login/model/login_request.dart';
import 'package:flutter_learning/product/login/model/otp_response_model.dart';
import 'package:flutter_learning/product/login/model/verify_otpmodel.dart';
import 'package:http/http.dart' as http;

class LoginService {
  static const String baseUrl = "https://ebe2-183-82-6-26.ngrok-free.app/api";

  Future<String> customerSignUp(CustomerLoginModel request) async {
    final url = Uri.parse("$baseUrl/customers/create");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(request.toJson()), // 👈 full request object
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Failed: ${response.body}");
    }
  }

  Future<String> customerLogin(LoginRequest request) async {
    final url = Uri.parse("$baseUrl/customers/login/send-otp");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode(request.toJson()), // 👈 full request object
    );

    if (response.statusCode == 200) {
      return response.body;
    } else {
      throw Exception("Failed: ${response.body}");
    }
  }

  Future<OtpResponseModel> verifyLoginOtp(VerifyOtpmodel request) async {
    final url = Uri.parse("$baseUrl/customers/login/verify");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(request.toJson()),
      );

      // ✅ CLEAN RESPONSE - Remove newlines & extra whitespace
      String cleanedBody = response.body
          .replaceAll(RegExp(r'[\n\r\t]'), '') // Remove newlines, tabs
          .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
          .trim();

      print("🔍 RAW RESPONSE: ${response.body}"); // Debug
      print("🧹 CLEANED: $cleanedBody"); // Debug

      if (response.statusCode == 200) {
        final data = jsonDecode(cleanedBody);
        return OtpResponseModel.fromJson(data);
      } else {
        // ✅ Parse error response safely
        try {
          final errorData = jsonDecode(cleanedBody);
          throw Exception(errorData['message'] ?? "Login verification failed");
        } catch (_) {
          throw Exception("Login failed: ${response.statusCode}");
        }
      }
    } catch (e) {
      print("❌ API ERROR: $e");
      rethrow;
    }
  }

  Future<OtpResponseModel> verifyOtp(VerifyOtpmodel request) async {
    final url = Uri.parse("$baseUrl/customers/verify");

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(request.toJson()),
      );

      // ✅ SAME CLEANING LOGIC
      String cleanedBody = response.body
          .replaceAll(RegExp(r'[\n\r\t]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (response.statusCode == 200) {
        final data = jsonDecode(cleanedBody);
        return OtpResponseModel.fromJson(data);
      } else {
        try {
          final errorData = jsonDecode(cleanedBody);
          throw Exception(errorData['message'] ?? "OTP Verification Failed");
        } catch (_) {
          throw Exception("Verification failed: ${response.statusCode}");
        }
      }
    } catch (e) {
      print("❌ API ERROR: $e");
      rethrow;
    }
  }
}
