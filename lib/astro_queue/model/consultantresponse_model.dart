import 'package:flutter_learning/astro_queue/model/enumsession.dart';

class ConsultationSessionResponse {
  final int? sessionId;
  final int? sessionNumber;
  final SessionStatus? status;
  final SimpleUser? customer;
  final SimpleUser? consultant;
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  ConsultationSessionResponse({
    this.sessionId,
    this.sessionNumber,
    this.status,
    this.customer,
    this.consultant,
    this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  factory ConsultationSessionResponse.fromJson(Map<String, dynamic> json) {
    return ConsultationSessionResponse(
      sessionId: json['sessionId'] as int?,
      sessionNumber: json['sessionNumber'] as int?,
      status: json['status'] != null 
          ? SessionStatus.values.firstWhere(
              (e) => e.toString().split('.').last == json['status'])
          : null,
      customer: json['customer'] != null 
          ? SimpleUser.fromJson(json['customer']) 
          : null,
      consultant: json['consultant'] != null 
          ? SimpleUser.fromJson(json['consultant']) 
          : null,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : null,
      startedAt: json['startedAt'] != null 
          ? DateTime.parse(json['startedAt']) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionNumber': sessionNumber,
      'status': status?.toString().split('.').last,
      'customer': customer?.toJson(),
      'consultant': consultant?.toJson(),
      'createdAt': createdAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}

class SimpleUser {
  final int? id;
  final String? name;
  final String? email;
  final String? role;

  SimpleUser({
    this.id,
    this.name,
    this.email,
    this.role,
  });

  factory SimpleUser.fromJson(Map<String, dynamic> json) {
    return SimpleUser(
      id: json['id'] as int?,
      name: json['name'] as String?,
      email: json['email'] as String?,
      role: json['role'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
    };
  }
}
