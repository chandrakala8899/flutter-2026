import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum Role { customer, practitioner }

class UserModel {
  final int? userId;
  final String? id;
  final String name;
  final Role roleEnum;

  UserModel({
    this.userId,
    this.id,
    required this.name,
    required this.roleEnum,
  });

  // ─── STORAGE ───────────────────────────────────────────────────────────────
  Map<String, dynamic> toStorageJson() => {
        'userId': userId,
        'id': id ?? userId?.toString(), // ✅ always persist id
        'name': name,
        'role': roleEnum.name,
      };

  Map<String, dynamic> toJson() => toStorageJson();

  // ─── FROM API LOGIN RESPONSE ───────────────────────────────────────────────
  static UserModel fromLoginJson(Map<String, dynamic> json) {
    String roleStr =
        json['role']?.toString().toLowerCase().trim() ?? 'customer';

    Role role;
    switch (roleStr) {
      case 'practitioner':
      case 'practioner':
        role = Role.practitioner;
        break;
      case 'customer':
      default:
        role = Role.customer;
    }

    final userId = json['userId'] is int
        ? json['userId'] as int
        : int.tryParse(json['userId']?.toString() ?? '');

    // id = explicit String id field, fallback to userId as String
    final id = json['id']?.toString()
        ?? userId?.toString();

    return UserModel(
      userId: userId,
      id: id,
      name: json['name'] ?? 'Unknown User',
      roleEnum: role,
    );
  }

  // ─── FROM SHARED PREFERENCES ───────────────────────────────────────────────
  static UserModel fromStorageJson(Map<String, dynamic> json) {
    return fromLoginJson(json); // same parsing, storage uses same keys
  }

  // ─── SAVE TO SHARED PREFERENCES ───────────────────────────────────────────
  Future<void> saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_json', jsonEncode(toStorageJson()));
  }

  // ─── LOAD FROM SHARED PREFERENCES ─────────────────────────────────────────
  /// Returns null if no user is stored.
  static Future<UserModel?> getLoggedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user_json');
      if (userJson == null) return null;
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      final user = fromStorageJson(map);
      return user;
    } catch (e) {
      return null;
    }
  }

  // ─── CLEAR (logout) ────────────────────────────────────────────────────────
  static Future<void> clearLoggedInUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_json');
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────────
  factory UserModel.mock({
    required String id,
    required String name,
    required Role role,
  }) {
    return UserModel(
      id: id,
      userId: int.tryParse(id),
      name: name,
      roleEnum: role,
    );
  }

  Role get role => roleEnum;

  bool get isCustomer     => roleEnum == Role.customer;
  bool get isPractitioner => roleEnum == Role.practitioner;

  /// The single source-of-truth ID string for Agora IM.
  /// Prefers [id] (String), falls back to [userId] as String.
  String get agoraUid => id ?? userId?.toString() ?? '';

  @override
  String toString() =>
      'UserModel(id: $id, userId: $userId, name: $name, role: ${roleEnum.name})';
}