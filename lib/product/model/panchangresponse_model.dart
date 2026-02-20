class PanchangSummaryModel {
  final String tithi;
  final String nakshatra;
  final String rahuKaal;
  final String festival;
  final String sunrise;
  final String sunset;
  final String moonrise;
  final String moonset;

  PanchangSummaryModel({
    required this.tithi,
    required this.nakshatra,
    required this.rahuKaal,
    required this.festival,
    required this.sunrise,
    required this.sunset,
    required this.moonrise,
    required this.moonset,
  });

  factory PanchangSummaryModel.fromJson(Map<String, dynamic> json) {
    return PanchangSummaryModel(
      tithi: json['tithi'] ?? "",
      nakshatra: json['nakshatra'] ?? "",
      rahuKaal: json['rahuKaal'] ?? "",
      festival: json['festival'] ?? "",
      sunrise: json['sunrise'] ?? "",
      sunset: json['sunset'] ?? "",
      moonrise: json['moonrise'] ?? "",
      moonset: json['moonset'] ?? "",
    );
  }
}
