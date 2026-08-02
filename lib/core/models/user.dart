class User {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role = 'customer',
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
    id: json['id'] ?? '',
    name: json['name'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'],
    avatarUrl: json['avatarUrl'],
    role: json['role'] ?? 'customer',
    createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'avatarUrl': avatarUrl,
    'role': role,
    'createdAt': createdAt.toIso8601String(),
  };
}
