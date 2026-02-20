class BirthDetailsModel {
  final DateTime dateTime;
  final double latitude;
  final double longitude;

  BirthDetailsModel({
    required this.dateTime,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      // IMPORTANT FIX HERE 👇
      "dateTime": dateTime.toUtc().toIso8601String(),
      "latitude": latitude,
      "longitude": longitude,
    };
  }
}
