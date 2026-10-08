import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart' show allStonesProvider;
import 'package:grazia_stones/features/maya_ai/services/maya_ai_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class MayaAIChatScreen extends ConsumerStatefulWidget {
  const MayaAIChatScreen({super.key});

  @override
  ConsumerState<MayaAIChatScreen> createState() => _MayaAIChatScreenState();
}

class _MayaAIChatScreenState extends ConsumerState<MayaAIChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<MayaChatMessage> _messages = [];
  bool _isTyping = false;

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
    _messages.add(
      MayaChatMessage(
        id: 'welcome',
        text:
            'Hello! I am **Maya**, Grazia Stones’ Luxury Architectural & Natural Stone Consultant.\n\nI can help you curate the perfect surface for your space from our 35 signature collections — whether it is a grand living room feature wall, modern 3D fluted panels, or weather-resilient exterior ledges.\n\nWhat architectural vision are you creating today? (Feel free to ask in English or Hindi!)',
        isUser: false,
        timestamp: DateTime.now(),
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

    final userMsg = MayaChatMessage(
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

    // Fetch catalogue stones for grounding
    List<Stone> catalogue = [];
    try {
      final stonesAsync = ref.read(allStonesProvider);
      catalogue = stonesAsync.value ?? [];
      if (catalogue.isEmpty) {
        catalogue = await ref.read(stoneRepositoryProvider).getStones(limit: 50);
      }
    } catch (_) {}

    try {
      final aiResponse = await MayaAIService.instance.askMaya(
        userQuery: trimmed,
        catalogueStones: catalogue,
        history: _messages,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(aiResponse);
        _isTyping = false;
      });
      HapticFeedback.mediumImpact();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          MayaChatMessage(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            text:
                'Shama kijiye, abhi response generate karne me dikkat aayi. Aap kripya dubara poochiye ya hamara curated catalogue explore kijiye.',
            isUser: false,
            timestamp: DateTime.now(),
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
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFD4AF37),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.35 : 0.25),
                        blurRadius: 8,
                        spreadRadius: 0.5,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/maya_avatar.jpg',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFFD4AF37),
                        size: 20,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Maya AI',
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isTyping) {
                    return _buildTypingIndicator();
                  }

                  final msg = _messages[index];
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
                        decoration: InputDecoration(
                          hintText: 'Ask Maya in English or Hindi (e.g. living room wall)...',
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

  Widget _buildMessageItem(MayaChatMessage msg, LuxuryPalette palette, bool isDark) {
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

    // Maya Message
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(top: 2, right: 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: isDark ? 0.3 : 0.2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/maya_avatar.jpg',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFD4AF37),
                      size: 16,
                    ),
                  ),
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

          // Recommended Stones Carousel
          if (msg.recommendedStones.isNotEmpty) ...[
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
              height: 204,
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

  Widget _buildStoneCard(Stone stone, LuxuryPalette palette, bool isDark) {
    return Container(
      width: 180,
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
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stone.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                Text(
                  stone.collection,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
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
                              'View',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
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
                          context.push('/tools?stoneId=${stone.id}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              'AI Studio',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
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
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFD4AF37),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome_rounded, color: Colors.black, size: 14),
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
                  'Maya is analyzing architectural options...',
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
}
