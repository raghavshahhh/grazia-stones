class DetectedLocation {
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? pincode;
  final String? country;
  final double? latitude;
  final double? longitude;
  final String source; // 'gps' | 'ip'

  const DetectedLocation({
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.pincode,
    this.country,
    this.latitude,
    this.longitude,
    this.source = 'gps',
  });
}
