class Dealer {
  final String id;
  final String name;
  final String address;
  final String phone;
  final String distance;
  final double rating;
  final bool isAuthorized;

  const Dealer({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.distance = '',
    this.rating = 0.0,
    this.isAuthorized = false,
  });

  factory Dealer.fromJson(Map<String, dynamic> json) => Dealer.fromMap(json);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'phone': phone,
    'distance': distance,
    'rating': rating,
    'isAuthorized': isAuthorized,
  };

  factory Dealer.fromMap(Map<String, dynamic> map) => Dealer(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    address: map['address'] ?? '',
    phone: map['phone'] ?? '',
    distance: map['distance'] ?? '',
    rating: (map['rating'] ?? 0).toDouble(),
    isAuthorized: map['isAuthorized'] ?? false,
  );
}
