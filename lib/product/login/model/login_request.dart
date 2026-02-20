class LoginRequest {
  final String email;

  LoginRequest({required this.email});

  Map<String, dynamic> toJson() {
    return {
      "email": email,
    };
  }
}

class VerifyOtpLoginRequest {
  final String email;
  final String otp;

  VerifyOtpLoginRequest({
    required this.email,
    required this.otp,
  });

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "otp": otp,
    };
  }
}
