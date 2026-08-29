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

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isDealer => role.toLowerCase() == 'dealer';

  factory User.fromMap(Map<String, dynamic> map) => User(
    id: map['id']?.toString() ?? '',
    name: map['full_name']?.toString() ?? map['name']?.toString() ?? '',
    email: map['email']?.toString() ?? '',
    phone: map['phone']?.toString(),
    avatarUrl: map['avatar_url']?.toString() ?? map['avatarUrl']?.toString(),
    role: map['role']?.toString() ?? 'customer',
    createdAt: DateTime.tryParse(map['created_at']?.toString() ?? map['createdAt']?.toString() ?? '') ?? DateTime.now(),
  );

  factory User.fromJson(Map<String, dynamic> json) => User.fromMap(json);

  Map<String, dynamic> toMap() => {
    'id': id,
    'full_name': name,
    'name': name,
    'email': email,
    'phone': phone,
    'avatar_url': avatarUrl,
    'avatarUrl': avatarUrl,
    'role': role,
    'created_at': createdAt.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
  };

  Map<String, dynamic> toJson() => toMap();
}

