class SessionPack {
  final int minutes;
  final double ratePerMinute;
  final String mode;
  final String practitionerName;

  SessionPack({
    required this.minutes,
    required this.ratePerMinute,
    required this.mode,
    required this.practitionerName,
  });

  double get totalPrice => minutes * ratePerMinute;

  String get packName => "$minutes Min Pack";

  String get description =>
      "$mode • $minutes minutes • ₹$ratePerMinute/min with $practitionerName";
}