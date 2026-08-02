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
    required this.createdAt,
  });

  factory SampleOrder.fromJson(Map<String, dynamic> json) => SampleOrder(
    id: json['id'] ?? '',
    stoneId: json['stoneId'] ?? '',
    stoneName: json['stoneName'] ?? '',
    name: json['name'] ?? '',
    phone: json['phone'] ?? '',
    address: json['address'] ?? '',
    city: json['city'] ?? '',
    pincode: json['pincode'] ?? '',
    status: json['status'] ?? 'Pending',
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
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
    'createdAt': createdAt.toIso8601String(),
  };
}
