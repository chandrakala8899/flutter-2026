import 'package:flutter_learning/astro_queue/model/enumsession.dart';
import 'package:flutter_learning/astro_queue/model/usermodel.dart';

class ConsultationSessionResponse {
  final int? sessionId;
  final int? sessionNumber;
  final SessionStatus? status;
  final SimpleUser? customer;
  final SimpleUser? consultant;

  // Booked session fields
  final DateTime? scheduledStart;
  final DateTime? scheduledEnd;
  final int? scheduledDurationMinutes;

  // Live session fields (NEW)
  final int? actualDurationMinutes;
  final DateTime? calledAt;

  // Common fields
  final DateTime? createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  // Agora fields (for joining call)
  final String? agoraChannel;
  final String? agoraToken;

  ConsultationSessionResponse({
    this.sessionId,
    this.sessionNumber,
    this.status,
    this.customer,
    this.consultant,
    this.scheduledStart,
    this.scheduledEnd,
    this.scheduledDurationMinutes,
    this.actualDurationMinutes,
    this.calledAt,
    this.createdAt,
    this.startedAt,
    this.completedAt,
    this.agoraChannel,
    this.agoraToken,
  });

  factory ConsultationSessionResponse.fromJson(Map<String, dynamic> json) {
    return ConsultationSessionResponse(
      sessionId: json['sessionId'] as int?,
      sessionNumber: json['sessionNumber'] as int?,
      status: json['status'] != null
          ? SessionStatus.values.firstWhere(
              (e) =>
                  e.name.toLowerCase() ==
                  json['status'].toString().toLowerCase(),
              orElse: () => SessionStatus.waiting,
            )
          : null,
      customer: json['customer'] != null
          ? SimpleUser.fromJson(json['customer'])
          : null,
      consultant: json['consultant'] != null
          ? SimpleUser.fromJson(json['consultant'])
          : null,

      // Scheduled (for bookings)
      scheduledStart: json['scheduledStart'] != null
          ? DateTime.tryParse(json['scheduledStart'])
          : null,
      scheduledEnd: json['scheduledEnd'] != null
          ? DateTime.tryParse(json['scheduledEnd'])
          : null,
      scheduledDurationMinutes: json['scheduledDurationMinutes'] as int?,

      // Actual duration (now always comes for completed sessions)
      actualDurationMinutes: json['actualDurationMinutes'] as int?,

      // Timestamps
      calledAt:
          json['calledAt'] != null ? DateTime.tryParse(json['calledAt']) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'])
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'])
          : null,

      // Agora
      agoraChannel: json['agoraChannel'] as String?,
      agoraToken: json['agoraToken'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionNumber': sessionNumber,
      'status': status?.toString().split('.').last,
      'customer': customer?.toJson(),
      'consultant': consultant?.toJson(),
      'scheduledStart': scheduledStart?.toIso8601String(),
      'scheduledEnd': scheduledEnd?.toIso8601String(),
      'scheduledDurationMinutes': scheduledDurationMinutes,
      'actualDurationMinutes': actualDurationMinutes,
      'calledAt': calledAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'startedAt': startedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'agoraChannel': agoraChannel,
      'agoraToken': agoraToken,
    };
  }

  /// ✅ PERFECT copyWith - copies ALL fields correctly
  ConsultationSessionResponse copyWith({
    int? sessionId,
    int? sessionNumber,
    SessionStatus? status,
    SimpleUser? customer,
    SimpleUser? consultant,
    DateTime? scheduledStart,
    DateTime? scheduledEnd,
    int? scheduledDurationMinutes,
    int? actualDurationMinutes,
    DateTime? calledAt,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? agoraChannel,
    String? agoraToken,
  }) {
    return ConsultationSessionResponse(
      sessionId: sessionId ?? this.sessionId,
      sessionNumber: sessionNumber ?? this.sessionNumber,
      status: status ?? this.status,
      customer: customer ?? this.customer,
      consultant: consultant ?? this.consultant,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      scheduledEnd: scheduledEnd ?? this.scheduledEnd,
      scheduledDurationMinutes:
          scheduledDurationMinutes ?? this.scheduledDurationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      calledAt: calledAt ?? this.calledAt,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      agoraChannel: agoraChannel ?? this.agoraChannel,
      agoraToken: agoraToken ?? this.agoraToken,
    );
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
