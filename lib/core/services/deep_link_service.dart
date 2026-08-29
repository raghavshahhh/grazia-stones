import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Deep link types
enum DeepLinkType {
  product,
  category,
  dealer,
  quote,
  order,
  aiVisualization,
  unknown,
}

/// Deep link data model
class DeepLinkData {
  final DeepLinkType type;
  final String? id;
  final Map<String, String> parameters;
  final String rawUrl;

  DeepLinkData({
    required this.type,
    this.id,
    this.parameters = const {},
    required this.rawUrl,
  });

  @override
  String toString() {
    return 'DeepLinkData(type: $type, id: $id, params: $parameters)';
  }
}

/// Deep link service for handling app links
/// 
/// Features:
/// - Parse deep links
/// - Handle universal links
/// - Route to appropriate screens
/// - Track deep link analytics
class DeepLinkService {
  static DeepLinkService? _instance;
  static DeepLinkService get instance => _instance ??= DeepLinkService._();

  DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('grazia_stones/deep_links');
  
  final _linkController = StreamController<DeepLinkData>.broadcast();
  DeepLinkData? _initialLink;
  bool _initialLinkConsumed = false;

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize deep link service
  Future<void> init() async {
    // Get initial link (if app was opened via deep link)
    try {
      final initialUrl = await _channel.invokeMethod<String>('getInitialLink');
      if (initialUrl != null) {
        _initialLink = _parseDeepLink(initialUrl);
        debugPrint('🔗 Initial deep link: $_initialLink');
      }
    } catch (e) {
      debugPrint('❌ Error getting initial link: $e');
    }

    // Listen for deep links while app is running
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLink') {
        final url = call.arguments as String?;
        if (url != null) {
          final linkData = _parseDeepLink(url);
          _linkController.add(linkData);
          debugPrint('🔗 New deep link: $linkData');
        }
      }
    });

    debugPrint('🔗 Deep link service initialized');
  }

  /// Dispose of resources
  void dispose() {
    _linkController.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DEEP LINK PARSING
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parse a deep link URL
  DeepLinkData _parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      final parameters = Map<String, String>.from(uri.queryParameters);

      // Parse based on URL pattern
      // Example patterns:
      // graziastones://product/123
      // graziastones://category/marble
      // graziastones://dealer/456
      // graziastones://quote/789
      // graziastones://order/101112
      // graziastones://ai-visualization/131415

      final pathSegments = path.split('/').where((s) => s.isNotEmpty).toList();

      if (pathSegments.isEmpty) {
        return DeepLinkData(
          type: DeepLinkType.unknown,
          rawUrl: url,
          parameters: parameters,
        );
      }

      final type = pathSegments[0];
      final id = pathSegments.length > 1 ? pathSegments[1] : null;

      DeepLinkType linkType;
      switch (type.toLowerCase()) {
        case 'product':
        case 'stone':
          linkType = DeepLinkType.product;
          break;
        case 'category':
          linkType = DeepLinkType.category;
          break;
        case 'dealer':
          linkType = DeepLinkType.dealer;
          break;
        case 'quote':
          linkType = DeepLinkType.quote;
          break;
        case 'order':
          linkType = DeepLinkType.order;
          break;
        case 'ai-visualization':
        case 'visualization':
          linkType = DeepLinkType.aiVisualization;
          break;
        default:
          linkType = DeepLinkType.unknown;
      }

      return DeepLinkData(
        type: linkType,
        id: id,
        parameters: parameters,
        rawUrl: url,
      );
    } catch (e) {
      debugPrint('❌ Error parsing deep link: $e');
      return DeepLinkData(
        type: DeepLinkType.unknown,
        rawUrl: url,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get initial deep link (if app was opened via deep link)
  DeepLinkData? getInitialLink() {
    if (!_initialLinkConsumed) {
      _initialLinkConsumed = true;
      return _initialLink;
    }
    return null;
  }

  /// Stream of deep links received while app is running
  Stream<DeepLinkData> get linkStream => _linkController.stream;

  /// Generate a deep link URL
  String generateDeepLink({
    required DeepLinkType type,
    String? id,
    Map<String, String>? parameters,
  }) {
    final buffer = StringBuffer('graziastones://');

    switch (type) {
      case DeepLinkType.product:
        buffer.write('product');
        break;
      case DeepLinkType.category:
        buffer.write('category');
        break;
      case DeepLinkType.dealer:
        buffer.write('dealer');
        break;
      case DeepLinkType.quote:
        buffer.write('quote');
        break;
      case DeepLinkType.order:
        buffer.write('order');
        break;
      case DeepLinkType.aiVisualization:
        buffer.write('ai-visualization');
        break;
      case DeepLinkType.unknown:
        buffer.write('unknown');
        break;
    }

    if (id != null) {
      buffer.write('/$id');
    }

    if (parameters != null && parameters.isNotEmpty) {
      buffer.write('?');
      buffer.write(
        parameters.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&'),
      );
    }

    return buffer.toString();
  }

  /// Generate a shareable web link (for universal links)
  String generateShareLink({
    required DeepLinkType type,
    String? id,
    Map<String, String>? parameters,
  }) {
    // This would be your web domain for universal links
    // Example: https://graziastones.com/product/123
    final buffer = StringBuffer('https://graziastones.com/');

    switch (type) {
      case DeepLinkType.product:
        buffer.write('product');
        break;
      case DeepLinkType.category:
        buffer.write('category');
        break;
      case DeepLinkType.dealer:
        buffer.write('dealer');
        break;
      case DeepLinkType.quote:
        buffer.write('quote');
        break;
      case DeepLinkType.order:
        buffer.write('order');
        break;
      case DeepLinkType.aiVisualization:
        buffer.write('ai-visualization');
        break;
      case DeepLinkType.unknown:
        buffer.write('unknown');
        break;
    }

    if (id != null) {
      buffer.write('/$id');
    }

    if (parameters != null && parameters.isNotEmpty) {
      buffer.write('?');
      buffer.write(
        parameters.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&'),
      );
    }

    return buffer.toString();
  }
}
