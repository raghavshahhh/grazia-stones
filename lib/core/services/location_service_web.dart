import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import '../models/detected_location.dart';

Future<DetectedLocation?> detectCurrentLocation() async {
  try {
    final completer = Completer<(double, double)?>();
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition pos) {
        final lat = pos.coords.latitude;
        final lon = pos.coords.longitude;
        if (!completer.isCompleted) completer.complete((lat, lon));
      }).toJS,
      ((web.GeolocationPositionError _) {
        if (!completer.isCompleted) completer.complete(null);
      }).toJS,
    );

    final coords = await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );

    if (coords != null) {
      final res = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.$1}&lon=${coords.$2}&addressdetails=1'),
        headers: {'User-Agent': 'GraziaStonesApp/1.0 (contact@graziastones.com)'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>? ?? {};
        return DetectedLocation(
          addressLine1: addr['road'] as String? ?? addr['neighbourhood'] as String? ?? addr['suburb'] as String?,
          addressLine2: addr['suburb'] as String? ?? addr['city_district'] as String?,
          city: addr['city'] as String? ?? addr['town'] as String? ?? addr['village'] as String? ?? addr['county'] as String?,
          state: addr['state'] as String?,
          pincode: addr['postcode'] as String?,
          country: addr['country'] as String?,
          latitude: coords.$1,
          longitude: coords.$2,
          source: 'gps',
        );
      }
    }
  } catch (_) {}

  // Fallback to IP geolocation
  return _fetchIpLocation();
}

Future<DetectedLocation?> _fetchIpLocation() async {
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
