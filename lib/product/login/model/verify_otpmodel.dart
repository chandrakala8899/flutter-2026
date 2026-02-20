class VerifyOtpmodel {
  final String email;
  final String otp;

  VerifyOtpmodel({required this.email, required this.otp});

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "otp": otp,
    };
  }
}
