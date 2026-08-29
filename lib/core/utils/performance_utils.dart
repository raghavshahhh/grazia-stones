import 'package:flutter/material.dart';

/// Performance optimization utilities
class PerformanceUtils {
  /// Debounce function calls
  /// 
  /// Delays execution until after a specified time has elapsed since the last call
  static void Function() debounce(
    VoidCallback callback, {
    Duration delay = const Duration(milliseconds: 500),
  }) {
    DateTime? lastCallTime;

    return () {
      final now = DateTime.now();
      if (lastCallTime == null ||
          now.difference(lastCallTime!) > delay) {
        lastCallTime = now;
        callback();
      }
    };
  }

  /// Throttle function calls
  /// 
  /// Limits execution to once per specified duration
  static void Function() throttle(
    VoidCallback callback, {
    Duration duration = const Duration(milliseconds: 500),
  }) {
    bool isThrottled = false;

    return () {
      if (!isThrottled) {
        callback();
        isThrottled = true;
        Future.delayed(duration, () {
          isThrottled = false;
        });
      }
    };
  }

  /// Measure widget build time
  static void measureBuildTime(String label, VoidCallback build) {
    final stopwatch = Stopwatch()..start();
    build();
    stopwatch.stop();
    debugPrint('⏱️ Build time for $label: ${stopwatch.elapsedMilliseconds}ms');
  }

  /// Reduce unnecessary rebuilds with const constructors
  /// This is a reminder function - use const constructors where possible
  static const optimizationTips = [
    'Use const constructors wherever possible',
    'Avoid creating new objects in build methods',
    'Use ListView.builder for long lists',
    'Use cached_network_image for network images',
    'Split large widgets into smaller const widgets',
    'Use keys to preserve widget state',
    'Avoid setState in deeply nested widgets',
    'Use RepaintBoundary for complex animations',
  ];
}

/// Mixin for widget performance monitoring
mixin PerformanceMonitorMixin<T extends StatefulWidget> on State<T> {
  Stopwatch? _buildStopwatch;

  @override
  void initState() {
    super.initState();
    _buildStopwatch = Stopwatch();
  }

  @override
  Widget build(BuildContext context) {
    _buildStopwatch!.start();
    final widget = buildWidget(context);
    _buildStopwatch!.stop();
    
    if (_buildStopwatch!.elapsedMilliseconds > 16) {
      debugPrint(
        '⚠️ Slow build detected in ${T.toString()}: '
        '${_buildStopwatch!.elapsedMilliseconds}ms',
      );
    }
    
    _buildStopwatch!.reset();
    return widget;
  }

  Widget buildWidget(BuildContext context);
}

/// Optimized scroll physics
class OptimizedScrollPhysics extends BouncingScrollPhysics {
  const OptimizedScrollPhysics({super.parent});

  @override
  OptimizedScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return OptimizedScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double get minFlingVelocity => 50.0;

  @override
  double get maxFlingVelocity => 8000.0;
}

/// Memory-efficient list separator
/// 
/// Uses a single const widget instead of creating new instances
class MemoryEfficientDivider extends StatelessWidget {
  const MemoryEfficientDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1);
  }
}

/// Optimized image precaching
class ImagePrecacher {
  static Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      try {
        await precacheImage(
          NetworkImage(url),
          context,
        );
      } catch (e) {
        debugPrint('Failed to precache image: $url');
      }
    }
  }

  static Future<void> precacheAssets(
    BuildContext context,
    List<String> assetPaths,
  ) async {
    for (final path in assetPaths) {
      try {
        await precacheImage(
          AssetImage(path),
          context,
        );
      } catch (e) {
        debugPrint('Failed to precache asset: $path');
      }
    }
  }
}
