class SampleOrder {
  final String id;
  final String stoneId;
  final String stoneName;
  final String name;
  final String phone;
  final String address;
  final String city;
  final String pincode;
  final String status;
  /// Courier AWB typed in by the admin once the kit ships; null until then.
  final String? trackingNumber;
  final DateTime createdAt;

  const SampleOrder({
    required this.id,
    required this.stoneId,
    required this.stoneName,
    required this.name,
    required this.phone,
    required this.address,
    required this.city,
    required this.pincode,
    this.status = 'Pending',
    this.trackingNumber,
    required this.createdAt,
  });

  factory SampleOrder.fromJson(Map<String, dynamic> json) => SampleOrder(
    id: json['id']?.toString() ?? '',
    stoneId: (json['stone_id'] ?? json['stoneId'])?.toString() ?? '',
    stoneName: (json['stone_name'] ?? json['stoneName'])?.toString() ?? 'Architectural Stone Sample',
    name: json['name']?.toString() ?? '',
    phone: json['phone']?.toString() ?? '',
    address: json['address']?.toString() ?? '',
    city: json['city']?.toString() ?? '',
    pincode: json['pincode']?.toString() ?? '',
    status: json['status']?.toString() ?? 'Pending',
    trackingNumber: (json['tracking_number'] ?? json['trackingNumber'])?.toString(),
    createdAt: DateTime.tryParse((json['created_at'] ?? json['createdAt'])?.toString() ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'stoneId': stoneId,
    'stoneName': stoneName,
    'name': name,
    'phone': phone,
    'address': address,
    'city': city,
    'pincode': pincode,
    'status': status,
    'trackingNumber': trackingNumber,
    'createdAt': createdAt.toIso8601String(),
  };
}
