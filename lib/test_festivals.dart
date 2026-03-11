import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = Uri.parse('https://astroapi-3.divineapi.com/indian-api/v2/yearly-festivals');

  final response = await http.post(
    url,
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "api_key":"8f298eca1f390265c0d19ae8b85cdb4c",
      "year": 2026,
      "place": "Hyderabad",
      "lat": 17.3850,
      "lon": 78.4867,
      "tzone": 5.5
    }),
  );

  if (response.statusCode == 200) {
    print(jsonEncode(jsonDecode(response.body))); // pretty print
  } else {
    print('Error: ${response.statusCode} ${response.body}');
  }
}