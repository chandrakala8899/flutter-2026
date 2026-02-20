

class ConsultationSessionRequest {
  final int customerId;
  final int consultantId;
  final DateTime startDate;
  final DateTime endDate;

  ConsultationSessionRequest({
    required this.customerId,
    required this.consultantId,
    required this.startDate,
    required this.endDate,
  });

  // Convert Dart object to JSON
  Map<String, dynamic> toJson() {
    return {
      "customerId": customerId,
      "consultantId": consultantId,
      "startDate": startDate.toIso8601String(),
      "endDate": endDate.toIso8601String(),
    };
  }

  // Create Dart object from JSON
  factory ConsultationSessionRequest.fromJson(Map<String, dynamic> json) {
    return ConsultationSessionRequest(
      customerId: json['customerId'],
      consultantId: json['consultantId'],
      startDate: DateTime.parse(json['startDate']),
      endDate: DateTime.parse(json['endDate']),
    );
  }
}