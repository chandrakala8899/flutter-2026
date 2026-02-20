import 'package:flutter_learning/astro_queue/model/usermodel.dart';

enum SessionStatus { created, waiting, called, inProgress, completed }

class SessionModel {
  final String id;
  final UserModel customer;
  final UserModel practitioner;
  SessionStatus status;

  SessionModel({
    required this.id,
    required this.customer,
    required this.practitioner,
    required this.status,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'].toString(),
      customer: UserModel.fromLoginJson(json['customer']),
      practitioner: UserModel.fromLoginJson(json['Practioner']),
      status: _mapStatus(json['status']),
    );
  }

  static SessionStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'waiting':
        return SessionStatus.waiting;
      case 'called':
        return SessionStatus.called;
      case 'inprogress':
        return SessionStatus.inProgress;
      case 'completed':
        return SessionStatus.completed;
      default:
        return SessionStatus.created;
    }
  }
}
