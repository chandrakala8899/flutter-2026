class OtpResponseModel {
  final bool success;
  final String message;
  final String shopifyCustomerId;

  OtpResponseModel({
    required this.success,
    required this.message,
    required this.shopifyCustomerId,
  });

  factory OtpResponseModel.fromJson(Map<String, dynamic> json) {
    return OtpResponseModel(
      success: json['success'] ?? false,
      message: json['message']?.toString() ?? 'Success',
      shopifyCustomerId: json['shopifyCustomerId']?.toString() ?? '',
    );
  }
}
