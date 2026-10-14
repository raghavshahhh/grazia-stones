import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart' show allStonesProvider, allCollectionsProvider;
import 'package:grazia_stones/features/aarna_ai/services/aarna_ai_service.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/shared/widgets/aarna_living_avatar.dart';

class AarnaAIChatScreen extends ConsumerStatefulWidget {
  const AarnaAIChatScreen({super.key});

  @override
  ConsumerState<AarnaAIChatScreen> createState() => _AarnaAIChatScreenState();
}

class _AarnaCapability {
  final String title;
  final String subtitle;
  final String imagePath;
  final String prompt;
  final AarnaPose pose;

  const _AarnaCapability({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.prompt,
    required this.pose,
  });
}

class _AarnaAIChatScreenState extends ConsumerState<AarnaAIChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AarnaChatMessage> _messages = [];
  bool _isTyping = false;
  // Id of the answer currently being typed out; its shortcuts/product cards stay hidden until the
  // text is complete, so the answer always lands before the products.
  String? _streamingId;
  AarnaPose _activeHeroPose = AarnaPose.idle;

  final List<_AarnaCapability> _capabilities = const [
    _AarnaCapability(
      title: 'Hello!',
      subtitle: 'Introduction',
      imagePath: 'assets/images/aarna/aarna_card_hello.png',
      prompt: 'Hello Aarna! Introduce yourself and how you help with Grazia Stones.',
      pose: AarnaPose.waving,
    ),
    _AarnaCapability(
      title: 'Find designs',
      subtitle: 'Living & Facades',
      imagePath: 'assets/images/aarna/aarna_card_designs.png',
      prompt: 'Find luxury stone designs for my living room feature wall.',
      pose: AarnaPose.searching,
    ),
    _AarnaCapability(
      title: 'Combinations',
      subtitle: 'Stone Pairings',
      imagePath: 'assets/images/aarna/aarna_card_combinations.png',
      prompt: 'Show elegant stone combinations and finishes for modern interiors.',
      pose: AarnaPose.combinations,
    ),
    _AarnaCapability(
      title: 'Technical info',
      subtitle: 'Specs & Care',
      imagePath: 'assets/images/aarna/aarna_card_technical.png',
      prompt: 'What are the technical specs and maintenance for Grazia Stones?',
      pose: AarnaPose.technical,
    ),
    _AarnaCapability(
      title: 'Get a quote',
      subtitle: 'Instant Estimate',
      imagePath: 'assets/images/aarna/aarna_card_quote.png',
      prompt: 'Help me calculate quantity and get a quote for my project.',
      pose: AarnaPose.quote,
    ),
  ];

  final List<String> _quickPrompts = [
    'Living room luxury feature wall ideas',
    '3D Fluted panels for modern TV lounge',
    'Exterior villa facade weather-proof stones',
    'Curated stones under ₹350/sq.ft',
    'Grand fireplace natural stone textures',
  ];

  @override
  void initState() {
    super.initState();
    _addInitialGreeting();
  }

  void _addInitialGreeting() {
    final curatedSuites = MockDataService.collections
        .where((c) => c.isListed)
        .take(3)
        .toList();

    _messages.add(
      AarnaChatMessage(
        id: 'welcome',
        text:
            'Hello! I am **Aarna**, your 3D AI architectural consultant for Grazia Stones.\n\n*AARNA — Your Vision, My Intelligence.*\n\nExplore our complete architectural suites and design collections curated below. Tap any collection to view all designs, or ask me for personalized space pairings!',
        isUser: false,
        timestamp: DateTime.now(),
        recommendedCollections: curatedSuites,
        recommendedStones: const [],
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    _textController.clear();
    HapticFeedback.lightImpact();

    final userMsg = AarnaChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: trimmed,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    // Fetch catalogue collections & stones for grounding
    List<Stone> catalogue = [];
    List<Collection> collections = [];
    try {
      final stonesAsync = ref.read(allStonesProvider);
      catalogue = stonesAsync.value ?? [];
      if (catalogue.isEmpty) {
        catalogue = await ref.read(stoneRepositoryProvider).getStones(limit: 100);
      }
    } catch (_) {}
    if (catalogue.isEmpty) {
      catalogue = MockDataService.stones;
    }

    try {
      final colsAsync = ref.read(allCollectionsProvider);
      collections = colsAsync.value ?? [];
      if (collections.isEmpty) {
        collections = await ref.read(stoneRepositoryProvider).getCollections();
      }
    } catch (_) {}
    if (collections.isEmpty) {
      collections = MockDataService.collections;
    }

    try {
      final aiResponse = await AarnaAIService.instance.askAarna(
        userQuery: trimmed,
        catalogueStones: catalogue,
        allCollections: collections,
        history: _messages,
      );

      if (!mounted) return;
      final fullText = aiResponse.text;
      final placeholder = aiResponse.copyWith(text: '');
      setState(() {
        _messages.add(placeholder);
        _isTyping = false;
        _streamingId = placeholder.id;
      });
      HapticFeedback.lightImpact();
      _scrollToBottom();

      // Smooth streaming typewriter effect (3-8 characters per tick)
      final msgIndex = _messages.length - 1;
      int charIdx = 0;
      final step = (fullText.length / 35).ceil().clamp(3, 8);
      while (charIdx < fullText.length && mounted) {
        charIdx = (charIdx + step).clamp(0, fullText.length);
        await Future.delayed(const Duration(milliseconds: 22));
        if (!mounted) return;
        setState(() {
          _messages[msgIndex] = placeholder.copyWith(
            text: fullText.substring(0, charIdx),
          );
        });
        _scrollToBottom();
      }
      if (!mounted) return;
      setState(() => _streamingId = null);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _streamingId = null;
        _messages.add(
          AarnaChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text:
                'Shama kijiye, abhi response generate karne me dikkat aayi. Aap kripya dubara poochiye ya hamare architectural collections explore kijiye.',
            isUser: false,
            timestamp: DateTime.now(),
            recommendedCollections: collections.where((c) => c.isListed).take(3).toList(),
          ),
        );
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Row(
          children: [
            AarnaLivingAvatar(
              size: 38,
              popOut: true,
              pose: _isTyping ? AarnaPose.searching : _activeHeroPose,
              isSearching: _isTyping || _activeHeroPose == AarnaPose.searching,
              showRadarRings: _isTyping,
              showSparkle: true,
              showOnlineBadge: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Aarna AI',
                        style: GoogleFonts.playfairDisplay(
                          color: palette.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.4 : 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'LUXURY CONCIERGE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Architectural Stone Specialist • Online',
                    style: GoogleFonts.plusJakartaSans(
                      color: palette.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: palette.textSecondary, size: 20),
            tooltip: 'Reset Chat',
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _messages.clear();
                _addInitialGreeting();
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat message list
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                // Dragging the chat or tapping outside the field closes the keyboard.
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: 1 + _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _buildAarnaHeroCard(palette, isDark);
                  }

                  final msgIndex = index - 1;
                  if (msgIndex == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }

                  final msg = _messages[msgIndex];
                  return _buildMessageItem(msg, palette, isDark);
                },
              ),
            ),

            // Quick Prompt Suggestions (shown when messages count is low)
            if (_messages.length <= 2)
              Container(
                height: 40,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _quickPrompts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final prompt = _quickPrompts[idx];
                    return InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _handleSubmitted(prompt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                                size: 12),
                            const SizedBox(width: 6),
                            Text(
                              prompt,
                              style: GoogleFonts.plusJakartaSans(
                                color: palette.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.border, width: 1.0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceDark,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: palette.border),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        style: GoogleFonts.plusJakartaSans(color: palette.textPrimary, fontSize: 14),
                        cursorColor: palette.primary,
                        textInputAction: TextInputAction.send,
                        onSubmitted: _handleSubmitted,
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        decoration: InputDecoration(
                          hintText: 'Ask Aarna in English or Hindi (e.g. living room wall)...',
                          hintStyle: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF707076),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => _handleSubmitted(_textController.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFD4AF37),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_upward_rounded, color: Colors.black, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(AarnaChatMessage msg, LuxuryPalette palette, bool isDark) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF26262A) : palette.primary.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(
              color: isDark ? const Color(0xFFD4AF37).withValues(alpha: 0.3) : palette.primary.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: _buildFormattedMessage(msg.text, palette, isDark, isUser: true),
        ),
      );
    }

    // Aarna Message
    final showExtras = msg.id != _streamingId;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2, right: 10),
                child: AarnaLivingAvatar(
                  size: 32,
                  pose: AarnaPose.idle,
                  showSparkle: false,
                  showOnlineBadge: true,
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF19191C) : palette.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.all(color: isDark ? const Color(0xFF2C2C32) : palette.border, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF2C2416).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: _buildFormattedMessage(msg.text, palette, isDark, isUser: false),
                ),
              ),
            ],
          ),

          // Action shortcuts only travel with a product answer, never with small talk.
          if (showExtras && (msg.recommendedCollections.isNotEmpty || msg.recommendedStones.isNotEmpty))
            Padding(
              padding: const EdgeInsets.only(left: 42, top: 10),
              child: _buildActionShortcuts(palette, isDark),
            ),

          // Recommended Architectural Collections & Design Suites
          if (showExtras && msg.recommendedCollections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'CURATED ARCHITECTURAL SUITES & COLLECTIONS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 230,
              margin: const EdgeInsets.only(left: 42),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: msg.recommendedCollections.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, idx) {
                  final col = msg.recommendedCollections[idx];
                  return _buildCollectionSuiteCard(col, palette, isDark);
                },
              ),
            ),
          ] else if (showExtras && msg.recommendedStones.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'RECOMMENDED GRAZIA ARCHITECTURAL SURFACES',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 218,
              margin: const EdgeInsets.only(left: 42),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: msg.recommendedStones.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final stone = msg.recommendedStones[idx];
                  return _buildStoneCard(stone, palette, isDark);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormattedMessage(
    String content,
    LuxuryPalette palette,
    bool isDark, {
    bool isUser = false,
  }) {
    final baseTextColor = isUser ? palette.textPrimary : palette.textPrimary;
    final accentGold = isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23);
    final boldColor = isUser
        ? palette.textPrimary
        : (isDark ? const Color(0xFFE8C868) : const Color(0xFF7A5818));

    final lines = content.split('\n');
    final List<Widget> lineWidgets = [];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i];
      final trimmedLine = rawLine.trim();

      if (trimmedLine.isEmpty) {
        if (i < lines.length - 1 && lines[i + 1].trim().isNotEmpty) {
          lineWidgets.add(const SizedBox(height: 6));
        }
        continue;
      }

      bool isBullet = false;
      String lineText = rawLine;
      if (trimmedLine.startsWith('• ') ||
          trimmedLine.startsWith('- ') ||
          (trimmedLine.startsWith('* ') && !trimmedLine.startsWith('** '))) {
        isBullet = true;
        lineText = trimmedLine.substring(2).trim();
      }

      final spans = _parseInlineSpans(lineText, baseTextColor, boldColor, accentGold);

      if (isBullet) {
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2, left: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: accentGold,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: spans,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: baseTextColor,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        lineWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.5),
            child: RichText(
              text: TextSpan(
                children: spans,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: isUser ? 14 : 13.5,
                  color: baseTextColor,
                  height: 1.45,
                ),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: lineWidgets,
    );
  }

  List<InlineSpan> _parseInlineSpans(
    String text,
    Color baseColor,
    Color boldColor,
    Color accentColor,
  ) {
    final List<InlineSpan> spans = [];
    final regExp = RegExp(r'\*\*(.+?)\*\*|\*([^*]+)\*');
    int currentIndex = 0;

    for (final match in regExp.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: TextStyle(color: baseColor, fontWeight: FontWeight.w400),
          ),
        );
      }

      if (match.group(1) != null) {
        // Bold (**text**) - stripped of asterisks and given clear font weight & warm tone
        spans.add(
          TextSpan(
            text: match.group(1),
            style: TextStyle(
              color: boldColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        // Italic (*text*)
        spans.add(
          TextSpan(
            text: match.group(2),
            style: TextStyle(
              color: accentColor,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(color: baseColor, fontWeight: FontWeight.w400),
        ),
      );
    }

    return spans;
  }

  Widget _buildCollectionSuiteCard(Collection collection, LuxuryPalette palette, bool isDark) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFD4AF37).withValues(alpha: 0.35) : palette.border,
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.35) : const Color(0xFF2C2416).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/collections/${collection.id}');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Luxury Architectural Room/Wall Banner
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      collection.effectiveBannerImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => SmartStoneImage(
                        imageUrl: collection.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                    // Gradient overlay for contrast
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Suite Category Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          collection.categoryType.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD4AF37),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    // Design Count Badge
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${collection.stoneCount > 0 ? collection.stoneCount : 12}+ Designs',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Suite Details & Dual Actions
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      collection.dimensionSpec,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push('/collections/${collection.id}');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2B2B30) : palette.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Explore Suite',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.push('/live-ai');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Live AR',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoneCard(Stone stone, LuxuryPalette palette, bool isDark) {
    return Container(
      width: 184,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF333338) : palette.border),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0xFF2C2416).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/stones/${stone.id}');
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stone Image
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    SmartStoneImage(
                      imageUrl: stone.mainImageUrl ?? (stone.images.isNotEmpty ? stone.images.first : null),
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          '₹${stone.pricePerSqFt.toInt()}/sq.ft',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Details & Actions
              Padding(
                padding: const EdgeInsets.all(9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      stone.collection,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 9.5,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              context.push('/stones/${stone.id}');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2B2B30) : palette.surfaceDark,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Specs',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.push('/live-ai?stoneId=${Uri.encodeComponent(stone.id)}');
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD4AF37),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  'Live AR',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: AarnaLivingAvatar(
              size: 32,
              pose: AarnaPose.searching,
              isSearching: true,
              showRadarRings: true,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF19191C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2C2C32), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Aarna is analyzing architectural options...',
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF8E8E93),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAarnaHeroCard(LuxuryPalette palette, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E1E24),
                  const Color(0xFF141418),
                ]
              : [
                  const Color(0xFFFAF8F5),
                  const Color(0xFFF0ECE1),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.1 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top character profile & brand introduction
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AarnaLivingAvatar(
                  size: 120,
                  greetOnLoad: true,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(18),
                  pose: _isTyping ? AarnaPose.searching : _activeHeroPose,
                  isSearching: _isTyping,
                  showRadarRings: _isTyping,
                  onTap: () {
                    setState(() {
                      _activeHeroPose = _activeHeroPose == AarnaPose.waving
                          ? AarnaPose.idle
                          : AarnaPose.waving;
                    });
                  },
                ),
                const SizedBox(width: 14),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tagline badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.2 : 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.5 : 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 10),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'AARNA — Your Vision, My Intelligence.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFFE8C868) : const Color(0xFF8B6B23),
                                  letterSpacing: 0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Meet Aarna',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your 3D Architectural AI Consultant for Grazia natural stones, 3D relief walls, finishes & quotes.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          height: 1.35,
                          color: palette.textSecondary,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: isDark ? const Color(0xFF2C2C34) : palette.border,
              height: 1,
            ),
          ),

          // Capabilities Title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Icon(Icons.touch_app_rounded, color: Color(0xFFD4AF37), size: 13),
                const SizedBox(width: 6),
                Text(
                  'CAPABILITIES — TAP ANY TO ASK AARNA',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: isDark ? const Color(0xFFD4AF37) : const Color(0xFF8B6B23),
                  ),
                ),
              ],
            ),
          ),

          // 5 Character Pose Cards (Horizontal Scroll)
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _capabilities.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final cap = _capabilities[idx];
                return _buildCapabilityCard(cap, palette, isDark);
              },
            ),
          ),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildCapabilityCard(_AarnaCapability cap, LuxuryPalette palette, bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _activeHeroPose = cap.pose);
        _handleSubmitted(cap.prompt);
      },
      child: Container(
        width: 110,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181D) : palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? const Color(0xFF33333C) : palette.border,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Character Pose Image
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF121215) : const Color(0xFFF5F3ED),
                child: Image.asset(
                  cap.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Center(
                    child: Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 24),
                  ),
                ),
              ),
            ),
            // Caption
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: isDark ? const Color(0xFF1E1E24) : palette.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cap.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary,
                    ),
                  ),
                  Text(
                    cap.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 8.5,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionShortcuts(LuxuryPalette palette, bool isDark) {
    final actions = [
      (
        icon: Icons.view_in_ar_rounded,
        label: 'Live AR',
        route: '/ar-view',
        color: const Color(0xFFD4AF37),
      ),
      (
        icon: Icons.inventory_2_outlined,
        label: 'Sample Kit',
        route: '/samples/request',
        color: const Color(0xFFE5A93B),
      ),
      (
        icon: Icons.straighten_rounded,
        label: 'Wall Calc',
        route: '/wall-calc',
        color: const Color(0xFF81C784),
      ),
      (
        icon: Icons.request_quote_outlined,
        label: 'Get Quote',
        route: '/quotes/new',
        color: const Color(0xFF64B5F6),
      ),
      (
        icon: Icons.auto_awesome_rounded,
        label: 'AI Studio',
        route: '/tools',
        color: const Color(0xFFBA68C8),
      ),
    ];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = actions[i];
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(a.route);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222226) : palette.surfaceDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF333338) : palette.border,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(a.icon, size: 13, color: a.color),
                  const SizedBox(width: 5),
                  Text(
                    a.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 9, color: palette.textSecondary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
