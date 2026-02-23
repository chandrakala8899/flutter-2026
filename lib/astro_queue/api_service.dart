// api_service.dart
import 'dart:convert';
import 'package:flutter_learning/astro_queue/model/consultantresponse_model.dart';

import 'package:flutter_learning/astro_queue/model/session_request_model.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = "http://localhost:16679"; // ✅ Android Emulator

  // ✅ 1. Login & Store User
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/login/user"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email.trim(),
          "password": password,
        }),
      );

      print('Login Response: ${response.statusCode}');
      print('Login Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = UserModel.fromLoginJson(data);
        await ApiService.storeUser(user); // ✅ Store automatically
        return data;
      } else if (response.statusCode == 401) {
        throw Exception("Invalid email or password");
      } else {
        throw Exception("Login failed");
      }
    } catch (e) {
      print('Login Error: $e');
      rethrow;
    }
  }

  // ✅ 2. Store User in Session
  static Future<void> storeUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = jsonEncode(user.toStorageJson());
    await prefs.setString('user_json', userJson);
    await prefs.setBool('is_logged_in', true);
    print("✅ User stored: ${user.name} (ID: ${user.userId})");
  }

  // ✅ 3. Get Logged In User
  static Future<UserModel?> getLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('user_json');
    if (userJson != null) {
      return UserModel.fromStorageJson(jsonDecode(userJson));
    }
    return null;
  }

  // ✅ 4. All Users (Customers list)
  static Future<List<UserModel>> getAllUsers() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/login/get-all"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => UserModel.fromLoginJson(json)).toList();
      }
      throw Exception("Failed to load users");
    } catch (e) {
      print("Get Users Error: $e");
      rethrow;
    }
  }

  // ✅ 5. Create Session (Customer)
  static Future<ConsultationSessionResponse?> createSession({
    required ConsultationSessionRequest request,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/sessions/create"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(request.toJson()),
      );

      print("CREATE SESSION: ${response.statusCode} - ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return ConsultationSessionResponse.fromJson(data);
      }
      return null;
    } catch (e) {
      print("Create Session Error: $e");
      return null;
    }
  }

  static Future<List<ConsultationSessionResponse>> getPractionerQueue(
      String consultantId) async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:16679/api/sessions/queue/$consultantId'),
        headers: {'Content-Type': 'application/json'},
      );

      print("Queue Response: ${response.statusCode}");
      print("Queue Body preview: ${response.body.substring(0, 200)}...");

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body);
        print("✅ Raw JSON: ${jsonList.length} sessions found");

        // 🔥 SAFE PARSING - Filter out broken sessions
        final List<ConsultationSessionResponse> parsed = [];
        for (var json in jsonList) {
          try {
            parsed.add(ConsultationSessionResponse.fromJson(json));
          } catch (e) {
            print("⚠️ Skip broken session: $json → $e");
          }
        }

        print(
            "✅ Successfully parsed: ${parsed.length}/${jsonList.length} sessions");
        return parsed;
      }
      return [];
    } catch (e) {
      print("❌ ApiService error: $e");
      return [];
    }
  }

  // ✅ 7. Current Session
  static Future<ConsultationSessionResponse?> getCurrentSession(
      String consultantId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/api/sessions/current/$consultantId"),
      );
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return ConsultationSessionResponse.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print("Current Session Error: $e");
      return null;
    }
  }

  // ✅ 8. Call Next Customer
  static Future<bool> callNextCustomer(String consultantId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/sessions/call-next/$consultantId"),
        headers: {"Content-Type": "application/json"},
      );
      print("Call Next: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("Call Next Error: $e");
      return false;
    }
  }

  // ✅ 9. Start Session
  static Future<ConsultationSessionResponse?> startSession(
      int sessionId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/sessions/$sessionId/start"),
        headers: {"Content-Type": "application/json"},
      );
      print("Start Session: ${response.statusCode}");
      if (response.statusCode == 200) {
        return ConsultationSessionResponse.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      print("Start Session Error: $e");
      return null;
    }
  }

  // ✅ 10. Complete Session
  static Future<bool> completeSession(int sessionId) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/api/sessions/$sessionId/complete"),
      );
      print("Complete Session: ${response.statusCode}");
      return response.statusCode == 200;
    } catch (e) {
      print("Complete Error: $e");
      return false;
    }
  }

  static Future<List<ConsultationSessionResponse>> getCustomerSessions({
    required int customerId,
    List<String>? statuses,
  }) async {
    String query = "";

    if (statuses != null && statuses.isNotEmpty) {
      query = statuses.map((s) => "status=$s").join("&");
    }

    final uri = Uri.parse("$baseUrl/api/sessions/customer/$customerId?$query");

    final response = await http.get(uri);

    print("REQUEST URL: $uri");
    print("RESPONSE: ${response.body}");

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      return data.map((e) => ConsultationSessionResponse.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load sessions");
    }
  }

  // ✅ 11. Logout
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_json');
    await prefs.setBool('is_logged_in', false);
  }
}
