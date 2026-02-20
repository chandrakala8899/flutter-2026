class CustomerLoginModel {
  final String email;
  final String phone;
  final String firstName;
  final String lastName;

  CustomerLoginModel(
      {required this.email,
      required this.phone,
      required this.firstName,
      required this.lastName});

  Map<String, dynamic> toJson() {
    return {
      "email": email,
      "phone": phone,
      "firstName": firstName,
      "lastName": lastName,
    };
  }
}
