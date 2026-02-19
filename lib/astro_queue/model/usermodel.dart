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

  // ✅ JSON-friendly storage (uses role name as String)
  Map<String, dynamic> toStorageJson() => {
        'userId': userId,
        'id': id,
        'name': name,
        'role': roleEnum.name, // ✅ 'customer' or 'practitioner' (String)
      };

  // ✅ For API responses (if needed)
  Map<String, dynamic> toJson() => toStorageJson();

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
        role = Role.customer;
        break;
      default:
        role = Role.customer;
    }

    return UserModel(
      userId: json['userId'],
      name: json['name'] ?? 'Unknown User',
      roleEnum: role,
    );
  }

  // ✅ From storage JSON
  static UserModel fromStorageJson(Map<String, dynamic> json) {
    return UserModel.fromLoginJson(json);
  }

  factory UserModel.mock({
    required String id,
    required String name,
    required Role role,
  }) {
    return UserModel(id: id, name: name, roleEnum: role);
  }

  Role get role => roleEnum;

  @override
  String toString() =>
      'User(id: $id, userId: $userId, name: $name, role: $roleEnum)';
}
