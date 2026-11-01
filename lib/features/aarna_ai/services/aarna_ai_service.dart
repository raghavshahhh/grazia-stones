import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';

class AarnaChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Stone> recommendedStones;
  final List<Collection> recommendedCollections;
  final bool isLoading;

  const AarnaChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.recommendedStones = const [],
    this.recommendedCollections = const [],
    this.isLoading = false,
  });

  AarnaChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<Stone>? recommendedStones,
    List<Collection>? recommendedCollections,
    bool? isLoading,
  }) {
    return AarnaChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      recommendedStones: recommendedStones ?? this.recommendedStones,
      recommendedCollections: recommendedCollections ?? this.recommendedCollections,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Aarna could not answer; [message] is safe to show the user and names the real reason.
class AarnaUnavailable implements Exception {
  final String message;
  const AarnaUnavailable(this.message);
  @override
  String toString() => message;
}

class AarnaAIService {
  static final AarnaAIService instance = AarnaAIService._();
  AarnaAIService._();

  /// Asks Aarna (Gemini via the Vercel proxy, api/aarna.js). The server holds the brand knowledge and the
  /// live catalogue and decides whether the reply needs design cards: it returns `designs` only when the
  /// user asked for designs, picked to match the request. Cards are those designs resolved against
  /// [catalogueStones]; there is no local keyword guessing, which used to put cards under every reply.
  Future<AarnaChatMessage> askAarna({
    required String userQuery,
    required List<Stone> catalogueStones,
    List<AarnaChatMessage> history = const [],
  }) async {
    // Failures surface as AarnaUnavailable: a canned "consultation" shown as if Aarna wrote it is worse
    // than an honest "try again".
    try {
      final recentHistory = history.where((m) => !m.isLoading).toList();
      if (recentHistory.isNotEmpty &&
          recentHistory.last.isUser &&
          recentHistory.last.text.trim() == userQuery.trim()) {
        recentHistory.removeLast();
      }
      final tail = recentHistory.length > 6
          ? recentHistory.sublist(recentHistory.length - 6)
          : recentHistory;

      final data = await AIEndpointClient.post('/api/aarna', {
        'message': userQuery,
        'history': [
          for (final m in tail) {'role': m.isUser ? 'user' : 'model', 'text': m.text},
        ],
      });

      final rawText = (data['text'] as String?)?.trim() ?? '';
      if (rawText.isEmpty) throw const AarnaUnavailable('Aarna returned an empty answer. Please ask again.');
      return AarnaChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: sanitizeResponse(rawText),
        isUser: false,
        timestamp: DateTime.now(),
        recommendedStones: resolveDesigns(data['designs'], catalogueStones),
      );
    } on AarnaUnavailable {
      rethrow;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final body = e.response?.data;
      final serverMessage = body is Map && body['error'] is String ? body['error'] as String : null;
      debugPrint('⚠️ [AarnaAIService] proxy error ($code): $e');
      throw AarnaUnavailable(switch (code) {
        429 => serverMessage ?? 'Aarna is busy right now. Please try again in a minute.',
        401 => 'Please sign in again to chat with Aarna.',
        503 => 'Aarna is not set up on the server yet.',
        _ => serverMessage ??
            (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout
                ? 'Aarna took too long to answer. Please try again.'
                : 'Could not reach Aarna. Check your connection and try again.'),
      });
    } catch (e) {
      debugPrint('⚠️ [AarnaAIService] unexpected error: $e');
      throw const AarnaUnavailable('Aarna could not answer just now. Please try again.');
    }
  }

  /// Server `designs` ([{id, name}]) -> loaded catalogue stones, in the server's order. Matches by id,
  /// then by name; unknown entries are dropped so a card never opens a missing product.
  @visibleForTesting
  static List<Stone> resolveDesigns(Object? designs, List<Stone> catalogue) {
    if (designs is! List) return const [];
    final out = <Stone>[];
    for (final d in designs) {
      if (d is! Map) continue;
      final id = d['id']?.toString();
      final name = d['name']?.toString().toLowerCase().trim();
      final stone = catalogue.where((s) => s.id == id).firstOrNull ??
          catalogue.where((s) => s.name.toLowerCase().trim() == name).firstOrNull;
      if (stone != null && !out.contains(stone)) out.add(stone);
    }
    return out.take(6).toList();
  }

  /// Closes a reply that was cut off mid-sentence; complete replies are returned untouched.
  @visibleForTesting
  static String sanitizeResponse(String rawText) {
    var t = rawText.trim();
    // A reply that already ends a sentence is complete: "...anything you'd like." stays as is.
    if (t.isEmpty || RegExp(r'[.!?)*"’]$').hasMatch(t)) return t;
    t = t.replaceFirst(RegExp(r'[\s.,:;-]+$'), '');
    // Drop a dangling connector ("pair well with") so the sentence does not end on it.
    t = t.replaceFirst(
        RegExp(r"\s+(of|like|such as|including|with|and|or|for example|the app|our app|in our app|app's)$",
            caseSensitive: false),
        '');
    return '$t.';
  }
}
