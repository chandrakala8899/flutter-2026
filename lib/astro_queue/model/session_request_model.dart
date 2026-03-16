class ConsultationSessionRequest {
  final int customerId;
  final int consultantId;
  final DateTime startDate;
  final DateTime endDate;
  final String sessionType;

  ConsultationSessionRequest({
    required this.customerId,
    required this.consultantId,
    required this.startDate,
    required this.endDate,
    required this.sessionType,
  });

  // Convert Dart object to JSON
  Map<String, dynamic> toJson() {
    return {
      "customerId": customerId,
      "consultantId": consultantId,
      "scheduledStartTime": startDate.toIso8601String(),
      "scheduledEndTime": endDate.toIso8601String(),
      "sessionType": sessionType,
    };
  }

  // Create Dart object from JSON
  factory ConsultationSessionRequest.fromJson(Map<String, dynamic> json) {
    return ConsultationSessionRequest(
      customerId: json['customerId'],
      consultantId: json['consultantId'],
      startDate: DateTime.parse(json['scheduledStartTime']),
      endDate: DateTime.parse(json['scheduledEndTime']),
      sessionType: json['sessionType'],
    );
  }
}
