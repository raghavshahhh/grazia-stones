class Dealer {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String phone;
  final String email;
  final String distance;
  final double rating;
  final bool isAuthorized;
  final bool isExclusive;

  const Dealer({
    required this.id,
    required this.name,
    required this.address,
    this.city = '',
    this.state = '',
    this.pincode = '',
    required this.phone,
    this.email = '',
    this.distance = '',
    this.rating = 0.0,
    this.isAuthorized = false,
    this.isExclusive = false,
  });

  factory Dealer.fromJson(Map<String, dynamic> json) => Dealer.fromMap(json);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'city': city,
    'state': state,
    'pincode': pincode,
    'phone': phone,
    'email': email,
    'distance': distance,
    'rating': rating,
    'isAuthorized': isAuthorized,
    'isExclusive': isExclusive,
  };

  factory Dealer.fromMap(Map<String, dynamic> map) => Dealer(
    id: map['id']?.toString() ?? '',
    name: map['name'] ?? '',
    address: map['address'] ?? (map['city'] != null ? '${map['city']}, ${map['state'] ?? ""}' : ''),
    city: map['city'] ?? '',
    state: map['state'] ?? '',
    pincode: map['pincode']?.toString() ?? '',
    phone: map['phone'] ?? '',
    email: map['email'] ?? '',
    distance: map['distance'] ?? '',
    rating: (map['rating'] ?? 0).toDouble(),
    isAuthorized: (map['verified'] == true) || (map['isAuthorized'] == true) || (map['is_exclusive'] == true),
    isExclusive: (map['is_exclusive'] == true) || (map['isExclusive'] == true) || (map['verified'] == true),
  );
}

