import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:grazia_stones/core/models/stone.dart';

/// Longest side sent for the room photo. Gemini's flash image models return ~1024 px, so more
/// input pixels only cost upload time on mobile data.
const roomMaxSide = 1280;

/// The stone photo is only a material reference; it ends up smaller than this on the wall.
const designMaxSide = 1024;

/// JPEG data URL (longest side <= maxSide, q80) for the AI proxy. Top level so it runs off the
/// UI thread with `compute`: decoding a photo in pure Dart froze the Generate tap for seconds.
String renderJpegDataUrl((Uint8List, int) args) {
  final (bytes, maxSide) = args;
  try {
    var decoded = img.decodeImage(bytes);
    if (decoded != null) {
      if (decoded.width > maxSide || decoded.height > maxSide) {
        decoded = decoded.width >= decoded.height
            ? img.copyResize(decoded, width: maxSide, interpolation: img.Interpolation.average)
            : img.copyResize(decoded, height: maxSide, interpolation: img.Interpolation.average);
      }
      return 'data:image/jpeg;base64,${base64Encode(img.encodeJpg(decoded, quality: 80))}';
    }
  } catch (_) {
    // Undecodable: send the original bytes, the server decides.
  }
  return 'data:image/jpeg;base64,${base64Encode(bytes)}';
}

/// How long a render takes, from this user's own last few renders.
class RenderEta {
  static const prefsKey = 'ai_studio_render_ms';
  static const defaultMs = 16000;
  static const _keep = 5;

  static int averageMs(List<String> stored) {
    final values = stored.map(int.tryParse).whereType<int>().toList();
    if (values.isEmpty) return defaultMs;
    return (values.reduce((a, b) => a + b) / values.length).round().clamp(8000, 45000);
  }

  static Future<int> estimateMs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return averageMs(prefs.getStringList(prefsKey) ?? const []);
    } catch (_) {
      return defaultMs;
    }
  }

  static Future<void> record(int ms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = [...?prefs.getStringList(prefsKey), '$ms'];
      await prefs.setStringList(prefsKey, list.sublist(math.max(0, list.length - _keep)));
    } catch (_) {
      // Only the next estimate gets less accurate.
    }
  }

  /// 0..1: linear to 90% at the estimate, then creeps toward 97% while still waiting.
  static double progress(int elapsedMs, int estimateMs) {
    final p = elapsedMs / estimateMs;
    if (p <= 1) return 0.9 * p;
    return 0.9 + 0.07 * (1 - math.exp(-(p - 1) * 2));
  }

  /// Seconds left, or null once the estimate is (nearly) used up, so the UI never shows 0 s.
  static int? secondsLeft(int elapsedMs, int estimateMs) {
    final left = ((estimateMs - elapsedMs) / 1000).ceil();
    return left >= 2 ? left : null;
  }
}

/// One colour of a catalogue stone: each catalogue image is one colour variant (same rule as
/// the stone detail page's swatches).
typedef StoneColour = ({String label, String imageUrl});

List<StoneColour> stoneColours(Stone stone) {
  if (stone.images.length < 2) return const [];
  final labels = stone.colourLabels(stone.images.length);
  return [
    for (var i = 0; i < stone.images.length; i++)
      if (stone.images[i].isNotEmpty) (label: labels[i], imageUrl: stone.images[i]),
  ];
}

/// Up to [limit] other stones: same collection first, then same category.
List<Stone> relatedStones(Stone stone, List<Stone> all, {int limit = 6}) {
  bool other(Stone s) => s.id != stone.id && s.isActive;
  final sameCollection = stone.collection.isEmpty
      ? const <Stone>[]
      : all.where((s) => other(s) && s.collection == stone.collection);
  final sameCategory = stone.category.isEmpty
      ? const <Stone>[]
      : all.where((s) => other(s) && s.category == stone.category);
  final seen = <String>{};
  return sameCollection.followedBy(sameCategory).where((s) => seen.add(s.id)).take(limit).toList();
}
