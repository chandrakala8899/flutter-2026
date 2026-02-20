// queue/api_service.dart
import 'dart:convert';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';
import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/session_request_model.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://localhost:16679"; // ✅ Emulator IP

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login/user"), // ✅ Fixed path
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "password": password,
        }),
      );

      print('Login Response: ${response.statusCode}');
      print('Login Body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 401) {
        throw Exception("Invalid email or password");
      } else if (response.statusCode == 400) {
        throw Exception("Please check your credentials");
      } else {
        throw Exception("Login failed. Please try again.");
      }
    } catch (e) {
      print('Login Error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Connection')) {
        throw Exception("No internet connection");
      }
      rethrow;
    }
  }

// ✅ In ApiService class
  static Future<void> storeUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();

    // ✅ Use toStorageJson() - converts Role enum to String
    final userJson = jsonEncode(user.toStorageJson());
    await prefs.setString('user_json', userJson);
    await prefs.setBool('is_logged_in', true);

    print("✅ User stored: ${user.name}");
  }

  static Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/login/get-all"),
        headers: {
          "Content-Type": "application/json",
        },
      );

      print("Status Code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        return data.map((json) => UserModel.fromLoginJson(json)).toList();
      } else {
        throw Exception("Failed to load users");
      }
    } catch (e) {
      print("API ERROR: $e");
      rethrow;
    }
  }

  // ✅ Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_json');
    await prefs.setBool('is_logged_in', false);
  }

  Future<List<UserModel>> getUsers() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/login/get-all"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        return data.map((json) => UserModel.fromLoginJson(json)).toList();
      } else {
        throw Exception("Failed to fetch users");
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<UserModel?> getLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_json');

    if (userJson != null) {
      return UserModel.fromStorageJson(jsonDecode(userJson));
    }
    return null;
  }

  static Future<ConsultationSessionResponse?> createSession({
    required ConsultationSessionRequest request,
  }) async {
    try {
      final uri = Uri.parse("${baseUrl}/api/sessions/create");

      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(request.toJson()),
      );

      print("CREATE SESSION STATUS: ${response.statusCode}");
      print("CREATE SESSION BODY: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (response.body == "Request has been sent") {
          // Fallback for plain text response
          print("✅ Plain text success response");
          return null; // No session data, but success
        }

        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          print("✅ Full session response received");
          return ConsultationSessionResponse.fromJson(data);
        }
        return null;
      } else {
        print("Failed to create session: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error creating session: $e");
      return null;
    }
  }
}
