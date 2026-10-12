import 'package:flutter/foundation.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';

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
    // 1. Ensure stones & collections available (fallback to authentic offline catalogue if empty)
    final pool = catalogueStones.isNotEmpty ? catalogueStones : MockDataService.stones;
    final collectionPool = allCollections.isNotEmpty ? allCollections : MockDataService.collections;

    // 2. Find matching collections & stones based on query semantics (Hindi & English keywords)
    final matchedCollections = _filterMatchingCollections(userQuery, collectionPool);
    final matchedStones = _filterMatchingStones(userQuery, pool);

    // 3. Live catalogue facts for grounding (brand knowledge + persona live
    // on the server in api/aarna.js, so the Gemini key never ships in the app).
    final catalogueSummary = _buildCatalogueSummary(
      matchedCollections,
      matchedStones.isNotEmpty ? matchedStones : pool.take(15).toList(),
    );

    // 4. Ask Aarna (Gemini via the Vercel proxy)
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
      if (rawText.isNotEmpty) {
        final sanitizedText = _sanitizeResponse(rawText, matchedCollections, matchedStones);
        return AarnaChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: sanitizedText,
          isUser: false,
          timestamp: DateTime.now(),
          recommendedCollections: matchedCollections.take(3).toList(),
          recommendedStones: matchedStones.take(4).toList(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [AarnaAIService] Aarna proxy error, using local fallback: $e');
    }

    // 5. Intelligent Offline/Local Architectural Engine Fallback
    // Guaranteed instant, high-quality consultation in English or Hindi!
    final fallbackResponse = _generateLocalArchitecturalAdvice(userQuery, matchedCollections, matchedStones);

    return AarnaChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: fallbackResponse,
      isUser: false,
      timestamp: DateTime.now(),
      recommendedCollections: matchedCollections.take(3).toList(),
      recommendedStones: matchedStones.take(4).toList(),
    );
  }

  /// Filters architectural collections by multilingual keywords
  List<Collection> _filterMatchingCollections(String query, List<Collection> collections) {
    if (collections.isEmpty) {
      collections = MockDataService.collections;
    }
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
    if (stones.isEmpty) {
      stones = MockDataService.stones;
    }
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
  static String _sanitizeResponse(String rawText, List<Collection> collections, List<Stone> stones) {
    var t = rawText.trim();
    if (t.isEmpty) return t;

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
  String _generateLocalArchitecturalAdvice(String query, List<Collection> collections, List<Stone> stones) {
    final q = query.toLowerCase();
    final isHindi = q.contains('chahiye') ||
        q.contains('hai') ||
        q.contains('karo') ||
        q.contains('batao') ||
        q.contains('desinge') ||
        q.contains('tiles') ||
        q.contains('deewar') ||
        q.contains('bahar') ||
        q.contains('andar') ||
        q.contains('kaisa') ||
        q.contains('kitna');

    final primaryCollection = collections.isNotEmpty ? collections.first.displayName : 'Exclusive Patina Series';
    final secondCollection = collections.length > 1 ? collections[1].displayName : 'Grande Ledge Series';

    final isQuote = q.contains('quote') || q.contains('price') || q.contains('rate') || q.contains('cost') || q.contains('kitna');
    final isTech = q.contains('tech') || q.contains('spec') || q.contains('size') || q.contains('detail') || q.contains('dimension') || q.contains('weight') || q.contains('maintenance');
    final isCombo = q.contains('combo') || q.contains('combination') || q.contains('match') || q.contains('pair') || q.contains('together') || q.contains('finish') || q.contains('interiors');
    final isGreeting = q == 'hello' || q == 'hi' || q == 'namaste' || q.startsWith('hello') || q.startsWith('hi aarna');

    if (isGreeting) {
      return isHindi
          ? 'Namaste! Main hoon **Aarna** — Grazia Stones ki AI design consultant.\n\n*AARNA — Your Vision, My Intelligence.*\n\nAapke space ke liye authentic architectural design suites neeche curate kiye gaye hain. Living room, facade ya TV wall kiske liye collection explore karein?'
          : 'Hello! I\'m **Aarna**, your AI architectural consultant for Grazia Stones.\n\n*AARNA — Your Vision, My Intelligence.*\n\nHere are authentic architectural design suites curated for you below. Tap any collection to explore all designs or preview in Live AR!';
    }

    if (isQuote) {
      return isHindi
          ? 'Apni wall ka size (e.g. 10x12 ft) batayein! Main turant square footage calculate kar doongi. Recommended design suite **$primaryCollection** ₹385/sq.ft se start hoti hai.'
          : 'Share your approximate wall dimensions (e.g. 10x12 ft)! I\'ll calculate square footage and boxes instantly. Recommended design suite **$primaryCollection** starts at ₹385/sq.ft.';
    }

    if (isTech) {
      return isHindi
          ? 'Grazia ke engineered design suites lightweight natural composite se bane hain — zero grout lines, fire-resistant aur 100% weather-proof! **$primaryCollection** ke technical specs aur coverage neeche check karein.'
          : 'Grazia collections feature interlocking precision cuts with zero visible grout lines. They are lightweight, fire-rated, and fully weatherproof. Inspect architectural specifications for **$primaryCollection** below.';
    }

    if (isCombo) {
      return isHindi
          ? 'Modern interiors ke liye luxury combination: **$primaryCollection** ke metallic patina accents ko **$secondCollection** ke rugged split-face texture ke saath pair kijiye! Dono collections neeche explore karein.'
          : 'For elegant and modern interiors, pair **$primaryCollection** with **$secondCollection**. The blend of metallic patina accents and rugged split-face texture creates striking depth!';
    }

    if (isHindi) {
      if (q.contains('bahar') || q.contains('exterior') || q.contains('elevation')) {
        return 'Exterior elevation ke liye **$primaryCollection** aur **$secondCollection** top choice hain — completely weather-proof aur natural royal masonry look! Explore collections below.';
      }
      return 'Aapke space ke liye hamari recommended choice hai **$primaryCollection** aur **$secondCollection**. Inhe seedha neeche explore karein ya **Live AR** me decorate karke dekhiye!';
    } else {
      if (q.contains('exterior') || q.contains('elevation') || q.contains('facade')) {
        return 'For exteriors and facades, **$primaryCollection** and **$secondCollection** offer superior weather endurance and natural masonry grandeur. Explore collections below!';
      }
      return 'I recommend **$primaryCollection** and **$secondCollection** for your space — both deliver rich architectural presence and seamless elegance. Tap below to explore!';
    }
  }
}
