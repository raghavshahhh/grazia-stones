import 'package:flutter/foundation.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';

class MayaChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<Stone> recommendedStones;
  final bool isLoading;

  const MayaChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.recommendedStones = const [],
    this.isLoading = false,
  });

  MayaChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    List<Stone>? recommendedStones,
    bool? isLoading,
  }) {
    return MayaChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      recommendedStones: recommendedStones ?? this.recommendedStones,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class MayaAIService {
  static final MayaAIService instance = MayaAIService._();
  MayaAIService._();

  /// Main conversation method: Queries Gemini with catalogue grounding & returns
  /// tailored architectural advice with matching Stone models.
  Future<MayaChatMessage> askMaya({
    required String userQuery,
    required List<Stone> catalogueStones,
    List<MayaChatMessage> history = const [],
  }) async {
    // 1. Find matching stones based on query semantics (Hindi & English keywords)
    final matchedStones = _filterMatchingStones(userQuery, catalogueStones);

    // 2. Live catalogue facts for grounding (brand knowledge + persona live
    // on the server in api/maya.js, so the Gemini key never ships in the app).
    final catalogueSummary = _buildCatalogueSummary(
      matchedStones.isNotEmpty ? matchedStones : catalogueStones.take(15).toList(),
    );

    // 3. Ask Maya (Gemini via the Vercel proxy)
    try {
      final recentHistory = history.where((m) => !m.isLoading).toList();
      // The chat screen already appended the current question; the server
      // adds it itself, so don't send it twice.
      if (recentHistory.isNotEmpty &&
          recentHistory.last.isUser &&
          recentHistory.last.text.trim() == userQuery.trim()) {
        recentHistory.removeLast();
      }
      final tail = recentHistory.length > 6
          ? recentHistory.sublist(recentHistory.length - 6)
          : recentHistory;

      final data = await AIEndpointClient.post('/api/maya', {
        'message': userQuery,
        'history': [
          for (final m in tail) {'role': m.isUser ? 'user' : 'model', 'text': m.text},
        ],
        'catalogue': catalogueSummary,
      });

      final text = (data['text'] as String?)?.trim() ?? '';
      if (text.isNotEmpty) {
        return MayaChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          recommendedStones: matchedStones.take(4).toList(),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [MayaAIService] Maya proxy error, using local fallback: $e');
    }

    // 4. Intelligent Offline/Local Architectural Engine Fallback
    // Guaranteed instant, high-quality consultation in English or Hindi!
    final fallbackResponse = _generateLocalArchitecturalAdvice(userQuery, matchedStones);

    return MayaChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: fallbackResponse,
      isUser: false,
      timestamp: DateTime.now(),
      recommendedStones: matchedStones.take(4).toList(),
    );
  }

  /// Filters stones by multilingual keywords (Hindi, Hinglish, English)
  List<Stone> _filterMatchingStones(String query, List<Stone> stones) {
    if (stones.isEmpty) return [];
    final q = query.toLowerCase();

    final isHindi = q.contains('chahiye') ||
        q.contains('hai') ||
        q.contains('karo') ||
        q.contains('batao') ||
        q.contains('desinge') ||
        q.contains('kamra') ||
        q.contains('ghar') ||
        q.contains('deewar') ||
        q.contains('bahar') ||
        q.contains('andar');

    final matches = <Stone>[];

    // Check specific spaces
    final isLivingRoom = q.contains('living') || q.contains('hall') || q.contains('drawing') || q.contains('sofa') || q.contains('tv');
    final isExterior = q.contains('exterior') || q.contains('bahar') || q.contains('elevation') || q.contains('boundary') || q.contains('facade') || q.contains('outdoor');
    final isFireplace = q.contains('fire') || q.contains('hearth') || q.contains('chimney');
    final isBedroom = q.contains('bedroom') || q.contains('bed') || q.contains('kamra') || q.contains('sleep');
    final is3DOrFluted = q.contains('3d') || q.contains('fluted') || q.contains('panel') || q.contains('texture') || q.contains('groove') || q.contains('linear');
    final isRusticOrRugged = q.contains('rustic') || q.contains('rugged') || q.contains('natural') || q.contains('ledge') || q.contains('quarry') || q.contains('stack');
    final isDarkOrBlack = q.contains('black') || q.contains('dark') || q.contains('charcoal') || q.contains('noir') || q.contains('kala');
    final isWhiteOrLight = q.contains('white') || q.contains('light') || q.contains('bianco') || q.contains('cream') || q.contains('beige') || q.contains('safed');

    for (final s in stones) {
      final name = s.name.toLowerCase();
      final collection = s.collection.toLowerCase();
      final category = s.category.toLowerCase();
      final desc = s.description.toLowerCase();
      final ideal = s.idealFor.map((e) => e.toLowerCase()).join(' ');

      int score = 0;

      // Direct name or collection hit
      if (q.contains(name) || q.contains(collection)) score += 5;

      if (isLivingRoom && (ideal.contains('living') || desc.contains('living') || name.contains('grande') || name.contains('classic'))) score += 3;
      if (isExterior && (ideal.contains('exterior') || desc.contains('exterior') || name.contains('mountain') || name.contains('rockface') || name.contains('country'))) score += 4;
      if (isFireplace && (ideal.contains('fire') || desc.contains('fire') || name.contains('ledge'))) score += 3;
      if (isBedroom && (ideal.contains('bedroom') || name.contains('athena') || name.contains('verona'))) score += 3;

      if (is3DOrFluted && (category.contains('3d') || name.contains('3d') || name.contains('athena') || name.contains('verona') || name.contains('fluted'))) score += 4;
      if (isRusticOrRugged && (category.contains('ledge') || name.contains('ledge') || desc.contains('rugged') || desc.contains('stack'))) score += 3;
      if (isDarkOrBlack && (name.contains('noir') || name.contains('charcoal') || desc.contains('dark') || desc.contains('black'))) score += 3;
      if (isWhiteOrLight && (name.contains('bianco') || name.contains('carrara') || desc.contains('white') || desc.contains('light'))) score += 3;

      if (score > 0) {
        matches.add(s);
      }
    }

    if (matches.isNotEmpty) {
      matches.sort((a, b) => b.rating.compareTo(a.rating));
      return matches;
    }

    // Default fallback: return top rated/trending stones
    return stones.where((s) => s.isTrending || s.isFeatured).take(6).toList();
  }

  String _buildCatalogueSummary(List<Stone> stones) {
    final buffer = StringBuffer();
    for (final s in stones.take(12)) {
      buffer.writeln('- ${s.name} (${s.collection}): ₹${s.pricePerSqFt}/sq.ft, Finish: ${s.finish}, Category: ${s.category}, Best for: ${s.idealFor.join(", ")}');
    }
    return buffer.toString();
  }

  /// High-fidelity sales-architectural generator when offline or fallback
  String _generateLocalArchitecturalAdvice(String query, List<Stone> stones) {
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

    final primaryStone = stones.isNotEmpty ? stones.first.name : 'Toran 3D Relief';
    final secondStone = stones.length > 1 ? stones[1].name : 'Grande Ledge Series';

    if (isHindi) {
      if (q.contains('bahar') || q.contains('exterior') || q.contains('elevation')) {
        return 'Exterior elevation ke liye **Mountain Ledge** aur **Rockface Series** perfect choice hain. Ye weather-proof natural split stones ghar ko timeless royal look dete hain.\n\n*Next Step:* Neeche diye gaye stones par tap karke unhe **Live AR** me apni facade par test kijiye!';
      }
      if (q.contains('3d') || q.contains('fluted') || q.contains('modern') || q.contains('tv')) {
        return 'Modern TV lounge ke liye hamari **$primaryStone** aur **Cosmic Flutes** sabse trending hain. Inka 3D linear relief spotlight ke under luxury depth create karta hai.\n\n*Action:* Kya aap iska texture feel karne ke liye **Sample Box** order karna chahenge?';
      }
      return 'Aapke space ke liye maine Grazia ki signature **$primaryStone** aur **$secondStone** select ki hain. Ye authentic natural texture ke saath aati hain jo space ki perceived value ko turant badha deti hain.\n\n*Next Step:* Inhe seedha **AI Room Studio** me decorate karke dekhiye!';
    } else {
      if (q.contains('exterior') || q.contains('elevation') || q.contains('facade')) {
        return 'For a striking exterior elevation, **Mountain Ledge** and **Rockface Series** offer unmatched weather resistance and textural grandeur. They instantly elevate the curb appeal and long-term value of your villa.\n\n*Next Step:* Tap below to preview these slabs at true scale on your wall using **Live AR**.';
      }
      if (q.contains('3d') || q.contains('fluted') || q.contains('modern') || q.contains('tv')) {
        return 'For modern luxury spaces, **$primaryStone** and **Cosmic Flutes** are our top architectural picks. Their acoustic relief creates captivating light-and-shadow dynamics under ambient lighting.\n\n*Action:* Would you like to visualize this on your wall in **AI Studio**, or order a physical sample tile?';
      }
      if (q.contains('living') || q.contains('hall') || q.contains('feature')) {
        return 'For a grand living room feature wall, **$primaryStone** paired with **$secondStone** creates an indelible statement of bespoke luxury that flat paint or ordinary tiles simply cannot match.\n\n*Action:* Feel the hand-chiselled stone grain by ordering a complimentary **Sample Kit** below.';
      }
      return 'Based on your design vision, I recommend **$primaryStone** and **$secondStone**. Both feature seamless interlocking stone masonry that conceals grout lines for a monolithic architectural finish.\n\n*Next Step:* Tap below to inspect technical specs or view in **Live AR**.';
    }
  }
}
