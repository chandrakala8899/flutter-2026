// lib/astro_queue/model/practioner_profile_response.dart

class PractionerProfileResponse {
  final int id;
  final String? userId;
  final String userName;
  final double audioRatePerMin;
  final double videoRatePerMin;
  final double chatRatePerMin;
  final String specialization;
  final String bio;
  final double rating;
  final int totalSessions;
  final bool isAvailable;

  PractionerProfileResponse({
    required this.id,
    this.userId,
    required this.userName,
    required this.audioRatePerMin,
    required this.videoRatePerMin,
    required this.chatRatePerMin,
    required this.specialization,
    required this.bio,
    required this.rating,
    required this.totalSessions,
    required this.isAvailable,
  });

  factory PractionerProfileResponse.fromJson(Map<String, dynamic> json) {
    return PractionerProfileResponse(
      id: json['id'],
      // userId can be null from the API
      userId: json['userId']?.toString(),
      userName: json['userName'] ?? "",
      audioRatePerMin: (json['audioRatePerMin'] ?? 0).toDouble(),
      videoRatePerMin: (json['videoRatePerMin'] ?? 0).toDouble(),
      chatRatePerMin: (json['chatRatePerMin'] ?? 0).toDouble(),
      specialization: json['specialization'] ?? "",
      bio: json['bio'] ?? "",
      rating: (json['rating'] ?? 0).toDouble(),
      totalSessions: json['totalSessions'] ?? 0,
      // FIX: backend sends "available" (not "isAvailable") — check both keys
      isAvailable: json['isAvailable'] ?? json['available'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "userId": userId,
      "userName": userName,
      "audioRatePerMin": audioRatePerMin,
      "videoRatePerMin": videoRatePerMin,
      "chatRatePerMin": chatRatePerMin,
      "specialization": specialization,
      "bio": bio,
      "rating": rating,
      "totalSessions": totalSessions,
      "isAvailable": isAvailable,
    };
  }
}
