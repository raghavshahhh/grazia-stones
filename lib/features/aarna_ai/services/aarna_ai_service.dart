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

  /// Main conversation method: Queries Gemini with catalogue grounding & returns
  /// tailored architectural advice with matching Architectural Collections & Design Suites.
  Future<AarnaChatMessage> askAarna({
    required String userQuery,
    required List<Stone> catalogueStones,
    List<Collection> allCollections = const [],
    List<AarnaChatMessage> history = const [],
  }) async {
    // 1. Only the live catalogue: mock stones have non-uuid ids, so their cards lead to broken pages.
    final pool = catalogueStones;
    final collectionPool = allCollections;

    // 2. Find matching collections & stones based on query semantics (Hindi & English keywords).
    // Small talk ("hey", "thanks", "who are you") gets a plain conversational answer with no cards.
    final wantsProducts = _wantsProducts(userQuery, collectionPool);
    final matchedCollections = wantsProducts ? _filterMatchingCollections(userQuery, collectionPool) : <Collection>[];
    final matchedStones = wantsProducts ? _filterMatchingStones(userQuery, pool) : <Stone>[];

    // 3. Live catalogue facts for grounding (brand knowledge + persona live
    // on the server in api/aarna.js, so the Gemini key never ships in the app).
    final catalogueSummary = _buildCatalogueSummary(
      matchedCollections,
      matchedStones.isNotEmpty ? matchedStones : pool.take(15).toList(),
    );

    // 4. Ask Aarna (Gemini via the Vercel proxy). Failures surface as AarnaUnavailable: a canned
    // "consultation" shown as if Aarna wrote it is worse than an honest "try again".
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
        'catalogue': catalogueSummary,
      });

      final rawText = (data['text'] as String?)?.trim() ?? '';
      if (rawText.isEmpty) throw const AarnaUnavailable('Aarna returned an empty answer. Please ask again.');
      return AarnaChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: sanitizeResponse(rawText, matchedCollections, matchedStones),
        isUser: false,
        timestamp: DateTime.now(),
        recommendedCollections: matchedCollections.take(3).toList(),
        recommendedStones: matchedStones.take(4).toList(),
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

  static final _productIntent = RegExp(
    r'stone|pathar|patthar|wall|deewar|diwar|design|collection|series|panel|brick|ledge|cnc|3d|patina|tile|clad|'
    r'elevation|facade|exterior|interior|living|bedroom|kitchen|bathroom|lobby|hotel|restaurant|office|villa|'
    r'balcony|show me|dikha|recommend|suggest|option|combination|combo|match|texture|finish|colou?r|catalogue|'
    r'sample|quote|price|rate|cost|sqft|sq ft|budget|size|thickness|fluted|travertin|marble|granite|sandstone',
  );

  /// True when the user is actually asking about stones/designs/rooms/prices (English, Hindi, Hinglish).
  @visibleForTesting
  bool wantsProducts(String query, List<Collection> collections) => _wantsProducts(query, collections);

  bool _wantsProducts(String query, List<Collection> collections) {
    final q = query.toLowerCase();
    if (_productIntent.hasMatch(q)) return true;
    return collections.any((c) => c.isListed && q.contains(c.displayName.toLowerCase()));
  }

  /// Filters architectural collections by multilingual keywords
  List<Collection> _filterMatchingCollections(String query, List<Collection> collections) {
    if (collections.isEmpty) return const [];
    final q = query.toLowerCase().trim();

    final isCombo = q.contains('combo') ||
        q.contains('combination') ||
        q.contains('pair') ||
        q.contains('mix') ||
        q.contains('match') ||
        q.contains('finish') ||
        q.contains('together') ||
        q.contains('contrast') ||
        q.contains('interiors') ||
        q.contains('modern');

    final isLivingRoom = q.contains('living') ||
        q.contains('hall') ||
        q.contains('drawing') ||
        q.contains('sofa') ||
        q.contains('tv') ||
        q.contains('lounge');

    final isExterior = q.contains('exterior') ||
        q.contains('bahar') ||
        q.contains('elevation') ||
        q.contains('boundary') ||
        q.contains('facade') ||
        q.contains('outdoor') ||
        q.contains('villa') ||
        q.contains('balcony') ||
        q.contains('patio');

    final is3D = q.contains('3d') ||
        q.contains('fluted') ||
        q.contains('panel') ||
        q.contains('relief') ||
        q.contains('carved') ||
        q.contains('groove') ||
        q.contains('cnc');

    final isPatina = q.contains('patina') ||
        q.contains('metal') ||
        q.contains('metallic') ||
        q.contains('brass') ||
        q.contains('bronze') ||
        q.contains('copper') ||
        q.contains('turquoise') ||
        q.contains('gold');

    final isBrick = q.contains('brick') ||
        q.contains('vintage') ||
        q.contains('rustic') ||
        q.contains('colonial') ||
        q.contains('lakhori');

    final matches = <Collection>[];

    for (final c in collections) {
      if (!c.isListed) continue;
      final name = c.displayName.toLowerCase();
      final desc = c.description.toLowerCase();
      final group = (c.catalogueGroup ?? '').toLowerCase();
      int score = 0;

      if (q.contains(name)) score += 10;
      if (isCombo) {
        if (group.contains('patina') || name.contains('patina')) score += 6;
        if (group.contains('ledge') || name.contains('ledge')) score += 5;
        if (group.contains('3d') || name.contains('3d') || group.contains('cnc')) score += 5;
      }
      if (isPatina && (group.contains('patina') || name.contains('patina') || desc.contains('patina'))) score += 8;
      if (is3D && (group.contains('3d') || group.contains('cnc') || name.contains('3d') || desc.contains('3d'))) score += 8;
      if (isExterior && (group.contains('ledge') || name.contains('ledge') || name.contains('mountain') || name.contains('country'))) score += 7;
      if (isLivingRoom && (group.contains('patina') || group.contains('3d') || name.contains('veines') || name.contains('travertin') || name.contains('grande'))) score += 6;
      if (isBrick && (group.contains('brick') || name.contains('brick') || desc.contains('brick'))) score += 8;

      if (score > 0) {
        matches.add(c);
      }
    }

    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.stoneCount.compareTo(a.stoneCount));
      return matches.take(4).toList();
    }

    // Default curated architectural collections
    final curated = <Collection>[];
    for (final c in collections) {
      final n = c.displayName.toLowerCase();
      if (n.contains('exclusive patina') ||
          n.contains('grande ledge') ||
          n.contains('premium 3d') ||
          n.contains('rustic brick') ||
          n.contains('florentine')) {
        curated.add(c);
      }
    }
    if (curated.isNotEmpty) return curated.take(3).toList();
    return collections.where((c) => c.isListed).take(3).toList();
  }

  /// Filters stones by multilingual keywords (Hindi, Hinglish, English)
  List<Stone> _filterMatchingStones(String query, List<Stone> stones) {
    if (stones.isEmpty) return const [];
    final q = query.toLowerCase().trim();

    final isCombo = q.contains('combo') ||
        q.contains('combination') ||
        q.contains('pair') ||
        q.contains('mix') ||
        q.contains('match') ||
        q.contains('finish') ||
        q.contains('together') ||
        q.contains('contrast') ||
        q.contains('interiors') ||
        q.contains('modern');

    final isLivingRoom = q.contains('living') ||
        q.contains('hall') ||
        q.contains('drawing') ||
        q.contains('sofa') ||
        q.contains('tv') ||
        q.contains('lounge');

    final isExterior = q.contains('exterior') ||
        q.contains('bahar') ||
        q.contains('elevation') ||
        q.contains('boundary') ||
        q.contains('facade') ||
        q.contains('outdoor') ||
        q.contains('villa') ||
        q.contains('balcony') ||
        q.contains('patio');

    final isFireplace = q.contains('fire') || q.contains('hearth') || q.contains('chimney');
    final isBedroom = q.contains('bedroom') ||
        q.contains('bed') ||
        q.contains('kamra') ||
        q.contains('sleep') ||
        q.contains('calm');

    final is3DOrFluted = q.contains('3d') ||
        q.contains('fluted') ||
        q.contains('panel') ||
        q.contains('texture') ||
        q.contains('groove') ||
        q.contains('linear') ||
        q.contains('carved') ||
        q.contains('relief');

    final isRusticOrRugged = q.contains('rustic') ||
        q.contains('rugged') ||
        q.contains('natural') ||
        q.contains('ledge') ||
        q.contains('quarry') ||
        q.contains('stack') ||
        q.contains('brick');

    final isDarkOrBlack = q.contains('black') ||
        q.contains('dark') ||
        q.contains('charcoal') ||
        q.contains('noir') ||
        q.contains('kala');

    final isWhiteOrLight = q.contains('white') ||
        q.contains('light') ||
        q.contains('bianco') ||
        q.contains('cream') ||
        q.contains('beige') ||
        q.contains('safed');

    final isPatinaOrMetal = q.contains('patina') ||
        q.contains('metal') ||
        q.contains('brass') ||
        q.contains('bronze') ||
        q.contains('copper') ||
        q.contains('turquoise') ||
        q.contains('gold');

    final matches = <Stone>[];

    for (final s in stones) {
      final name = s.name.toLowerCase();
      final collection = s.collection.toLowerCase();
      final category = s.category.toLowerCase();
      final desc = s.description.toLowerCase();
      final ideal = s.idealFor.map((e) => e.toLowerCase()).join(' ');

      int score = 0;

      // Exact name or collection hit
      if (q.contains(name)) score += 8;
      if (q.contains(collection)) score += 6;

      if (isCombo) {
        if (collection.contains('patina') || name.contains('turquoise') || name.contains('scallop')) score += 5;
        if (collection.contains('ledge') || name.contains('grande') || name.contains('mountain')) score += 5;
        if (category.contains('3d') || name.contains('athena') || name.contains('verona')) score += 4;
      }

      if (isLivingRoom && (ideal.contains('living') || desc.contains('living') || category.contains('3d') || collection.contains('patina') || name.contains('grande') || name.contains('classic'))) score += 4;
      if (isExterior && (ideal.contains('exterior') || desc.contains('exterior') || collection.contains('ledge') || name.contains('mountain') || name.contains('rockface') || name.contains('country'))) score += 5;
      if (isFireplace && (ideal.contains('fire') || desc.contains('fire') || collection.contains('ledge'))) score += 4;
      if (isBedroom && (ideal.contains('bedroom') || name.contains('athena') || name.contains('verona') || collection.contains('veines') || collection.contains('travertin'))) score += 4;

      if (is3DOrFluted && (category.contains('3d') || name.contains('3d') || name.contains('athena') || name.contains('verona') || name.contains('fluted') || name.contains('toran'))) score += 5;
      if (isRusticOrRugged && (collection.contains('ledge') || collection.contains('brick') || name.contains('ledge') || desc.contains('rugged') || desc.contains('stack'))) score += 4;
      if (isDarkOrBlack && (name.contains('noir') || name.contains('charcoal') || desc.contains('dark') || desc.contains('black') || ideal.contains('dark'))) score += 4;
      if (isWhiteOrLight && (name.contains('bianco') || name.contains('carrara') || desc.contains('white') || desc.contains('light') || desc.contains('cream'))) score += 4;
      if (isPatinaOrMetal && (collection.contains('patina') || name.contains('turquoise') || name.contains('scallop') || desc.contains('metallic') || desc.contains('brass'))) score += 5;

      if (score > 0) {
        matches.add(s);
      }
    }

    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.rating.compareTo(a.rating));
      return matches.take(6).toList();
    }

    // Curated high-impact fallback guaranteed to never be empty
    final curated = <Stone>[];
    for (final s in stones) {
      if (s.name.contains('Turquoise') ||
          s.name.contains('Grande') ||
          s.name.contains('Athena') ||
          s.name.contains('Mountain') ||
          s.name.contains('Rustic') ||
          s.name.contains('Verona') ||
          s.isFeatured ||
          s.isTrending) {
        curated.add(s);
      }
    }
    if (curated.isNotEmpty) {
      return curated.take(4).toList();
    }
    return stones.take(4).toList();
  }

  String _buildCatalogueSummary(List<Collection> collections, List<Stone> stones) {
    final buffer = StringBuffer();
    buffer.writeln('Architectural Collections:');
    for (final c in collections.take(5)) {
      buffer.writeln('- ${c.displayName} (${c.categoryType}): ${c.stoneCount} designs. Dimensions: ${c.dimensionSpec}. ${c.description}');
    }
    buffer.writeln('\nFlagship Stone Surfaces:');
    for (final s in stones.take(8)) {
      buffer.writeln('- ${s.name} (${s.collection}): ₹${s.pricePerSqFt}/sq.ft, Finish: ${s.finish}, Category: ${s.category}, Best for: ${s.idealFor.join(", ")}');
    }
    return buffer.toString();
  }

  /// Ensures AI text finishes sentences cleanly with zero dangling cutoffs.
  @visibleForTesting
  static String sanitizeResponse(String rawText, List<Collection> collections, List<Stone> stones) {
    var t = rawText.trim();
    if (t.isEmpty) return t;
    // A reply that already ends a sentence is complete: "...anything you'd like." must not be rewritten
    // into a canned recommendation just because it ends with the word "like".
    if (RegExp(r'[.!?)*"’]$').hasMatch(t)) return t;

    var cleanBase = t;
    while (cleanBase.endsWith('.') || cleanBase.endsWith(',') || cleanBase.endsWith(':') || cleanBase.endsWith('-')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1).trim();
    }

    final trailingCutoffs = [
      ' of',
      ' like',
      ' such as',
      ' including',
      ' with',
      ' and',
      ' or',
      ' for example',
      ' textures of',
      ' our grazia app\'s',
      ' grazia app\'s',
      ' app\'s',
      ' in our app',
      ' our app',
      ' the app',
    ];

    for (final cutoff in trailingCutoffs) {
      if (cleanBase.toLowerCase().endsWith(cutoff)) {
        final c1 = collections.isNotEmpty ? collections[0].displayName : 'Exclusive Patina Series';
        final c2 = collections.length > 1 ? collections[1].displayName : 'Grande Ledge Series';
        t = '${cleanBase.substring(0, cleanBase.length - cutoff.length)}. I recommend exploring **$c1** and **$c2** curated below for your space!';
        return t;
      }
    }

    if (!t.endsWith('.') && !t.endsWith('!') && !t.endsWith('?')) {
      t = '$t.';
    }
    return t;
  }

  /// High-fidelity sales-architectural generator when offline or fallback
}
