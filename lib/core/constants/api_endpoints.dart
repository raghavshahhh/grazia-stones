class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://api.graziastones.com/v1';

  // ── Auth ──
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String socialLogin = '/auth/social';
  static const String refreshToken = '/auth/refresh';
  static const String profile = '/auth/profile';

  // ── Collections ──
  static const String collections = '/collections';
  static String collectionById(String id) => '/collections/$id';
  static String collectionStones(String id) => '/collections/$id/stones';

  // ── Stones ──
  static const String stones = '/stones';
  static String stoneById(String id) => '/stones/$id';
  static String stoneReviews(String id) => '/stones/$id/reviews';

  // ── AI Visualization ──
  static const String aiVisualize = '/ai/visualize';
  static const String aiHistory = '/ai/history';

  // ── AR ──
  static const String arAnchors = '/ar/anchors';

  // ── Dealers ──
  static const String dealers = '/dealers';
  static String dealerById(String id) => '/dealers/$id';
  static const String dealerNearby = '/dealers/nearby';

  // ── Quotes ──
  static const String quotes = '/quotes';
  static String quoteById(String id) => '/quotes/$id';

  // ── Orders ──
  static const String orders = '/orders';
  static String orderById(String id) => '/orders/$id';

  // ── Cart ──
  static const String cart = '/cart';
  static const String cartItems = '/cart/items';

  // ── Wishlist ──
  static const String wishlist = '/wishlist';

  // ── Search ──
  static const String search = '/search';

  // ── Upload ──
  static const String upload = '/upload';

  // ── Payments ──
  static const String paymentCreate = '/payments/create';
  static const String paymentVerify = '/payments/verify';
}
