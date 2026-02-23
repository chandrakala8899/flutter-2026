class ConsultationSession {
  final int sessionId;
  final int sessionNumber;
  final String status;

  ConsultationSession({
    required this.sessionId,
    required this.sessionNumber,
    required this.status,
  });

  factory ConsultationSession.fromJson(Map<String, dynamic> json) {
    return ConsultationSession(
      sessionId: json['sessionId'],
      sessionNumber: json['sessionNumber'],
      status: json['status'],
    );
  }
}