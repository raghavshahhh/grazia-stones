class Order {
  final String id;
  final String? userId;
  final String? orderNumber;
  final List<String> stoneNames;
  final double totalAmount;
  final double subtotal;
  final double? total;
  final String? currency;
  final String status;
  final String? paymentMethod;
  final String? paymentStatus;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? shippingName;
  final String? shippingPhone;
  final String? shippingAddress;
  final String? shippingCity;
  final String? shippingState;
  final String? shippingPincode;
  final bool isSample;
  final String? notes;
  final DateTime createdAt;

  const Order({
    required this.id,
    this.userId,
    this.orderNumber,
    required this.stoneNames,
    required this.totalAmount,
    this.subtotal = 0,
    this.total,
    this.currency,
    required this.status,
    this.paymentMethod,
    this.paymentStatus,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.shippingName,
    this.shippingPhone,
    this.shippingAddress,
    this.shippingCity,
    this.shippingState,
    this.shippingPincode,
    this.isSample = false,
    this.notes,
    required this.createdAt,
  });

  factory Order.fromMap(Map<String, dynamic> map) => Order(
    id: map['id'] ?? '',
    userId: map['user_id'],
    orderNumber: map['order_number'],
    stoneNames: List<String>.from(
      (map['order_items'] as List?)?.map((i) => i['name'] ?? '') ?? map['stoneNames'] ?? [],
    ),
    totalAmount: (map['total'] ?? map['totalAmount'] ?? 0).toDouble(),
    subtotal: (map['subtotal'] ?? 0).toDouble(),
    total: map['total'] != null ? (map['total']).toDouble() : null,
    currency: map['currency'],
    status: map['status'] ?? 'Pending',
    paymentMethod: map['payment_method'],
    paymentStatus: map['payment_status'],
    razorpayPaymentId: map['razorpay_payment_id'],
    razorpaySignature: map['razorpay_signature'],
    shippingName: map['shipping_name'],
    shippingPhone: map['shipping_phone'],
    shippingAddress: map['shipping_address'],
    shippingCity: map['shipping_city'],
    shippingState: map['shipping_state'],
    shippingPincode: map['shipping_pincode'],
    isSample: map['is_sample'] ?? false,
    notes: map['notes'],
    createdAt: DateTime.tryParse(map['created_at'] ?? map['createdAt'] ?? '') ?? DateTime.now(),
  );

  factory Order.fromJson(Map<String, dynamic> json) => Order.fromMap(json);

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'order_number': orderNumber,
    'stoneNames': stoneNames,
    'total': totalAmount,
    'totalAmount': totalAmount,
    'subtotal': subtotal,
    'currency': currency,
    'status': status,
    'payment_method': paymentMethod,
    'payment_status': paymentStatus,
    'is_sample': isSample,
    'notes': notes,
    'created_at': createdAt.toIso8601String(),
  };
}
