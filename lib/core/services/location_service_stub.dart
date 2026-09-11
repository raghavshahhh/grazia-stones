import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/detected_location.dart';

Future<DetectedLocation?> detectCurrentLocation() async {
  try {
    final res = await http.get(Uri.parse('https://ipwho.is/')).timeout(const Duration(seconds: 4));
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        return DetectedLocation(
          city: data['city'] as String?,
          state: data['region'] as String?,
          pincode: data['postal'] as String?,
          country: data['country'] as String?,
          latitude: (data['latitude'] as num?)?.toDouble(),
          longitude: (data['longitude'] as num?)?.toDouble(),
          source: 'ip',
        );
      }
    }
  } catch (_) {}
  return null;
}
