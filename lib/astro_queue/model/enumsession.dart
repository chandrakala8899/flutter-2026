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
}
