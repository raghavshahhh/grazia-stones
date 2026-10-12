import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/widgets/aarna_living_avatar.dart';

/// Ultra-luxury AI Prompt Pill for Aarna AI with authentic Typewriter animation.
///
/// Features:
/// 1. True Typewriter typing animation: types prompt letter-by-letter with a blinking golden cursor.
/// 2. Natural pause at completion so the user can easily read the prompt.
/// 3. Continuous luxury golden gradient border matching MakeMyTrip / luxury concierge styling.
/// 4. Integrated 3D Living Aarna Avatar that waves and blinks in real-time!
class AarnaAiPromptPill extends StatefulWidget {
  final LuxuryPalette palette;
  final bool isDark;
  final VoidCallback? onTap;

  const AarnaAiPromptPill({
    super.key,
    required this.palette,
    required this.isDark,
    this.onTap,
  });

  @override
  State<AarnaAiPromptPill> createState() => _AarnaAiPromptPillState();
}

class _AarnaAiPromptPillState extends State<AarnaAiPromptPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;
  Timer? _typewriterTimer;

  static const List<String> _prompts = [
    'Ask Aarna: 3D fluted wall panels',
    'Ask Aarna: Italian marble for villa foyer',
    'Ask Aarna: Patina & Grande Ledge pairings',
    'Ask Aarna: Golden onyx backlit temple designs',
    'Ask Aarna: Grand fireplace split-face textures',
    'Ask Aarna in Hindi or English...',
  ];

  int _promptIndex = 0;
  int _charIndex = 0;
  bool _isDeleting = false;
  String _displayedText = '';

  AarnaPose _getPoseForPrompt(int index) {
    switch (index % _prompts.length) {
      case 0:
        return AarnaPose.technical; // 3D fluted wall panels
      case 1:
        return AarnaPose.searching; // Italian marble search
      case 2:
        return AarnaPose.combinations; // Patina & Grande Ledge
      case 3:
        return AarnaPose.searching; // Backlit onyx
      case 4:
        return AarnaPose.combinations; // Fireplace textures
      default:
        return AarnaPose.waving; // Hello / Waving
    }
  }

  @override
  void initState() {
    super.initState();

    // 1. Blinking golden cursor (500ms cycle)
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    // 2. Start typewriter loop
    _startTypewriterLoop();
  }

  void _startTypewriterLoop() {
    _typewriterTimer?.cancel();

    const typingSpeed = Duration(milliseconds: 55);
    const deletingSpeed = Duration(milliseconds: 25);
    const pauseAtEnd = Duration(milliseconds: 2400);
    const pauseAtEmpty = Duration(milliseconds: 400);

    void step() {
      if (!mounted) return;

      final target = _prompts[_promptIndex];

      if (!_isDeleting) {
        // Typing forward
        if (_charIndex < target.length) {
          _charIndex++;
          setState(() {
            _displayedText = target.substring(0, _charIndex);
          });
          _typewriterTimer = Timer(typingSpeed, step);
        } else {
          // Finished typing: pause before backspacing
          _typewriterTimer = Timer(pauseAtEnd, () {
            if (!mounted) return;
            _isDeleting = true;
            step();
          });
        }
      } else {
        // Deleting backward
        if (_charIndex > 0) {
          _charIndex--;
          setState(() {
            _displayedText = target.substring(0, _charIndex);
          });
          _typewriterTimer = Timer(deletingSpeed, step);
        } else {
          // Finished deleting: pause and move to next prompt
          _isDeleting = false;
          _promptIndex = (_promptIndex + 1) % _prompts.length;
          _typewriterTimer = Timer(pauseAtEmpty, step);
        }
      }
    }

    _typewriterTimer = Timer(const Duration(milliseconds: 200), step);
  }

  @override
  void dispose() {
    _typewriterTimer?.cancel();
    _cursorController.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.lightImpact();
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      context.push('/aarna-ai');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        // Continuous luxury golden gradient border
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFDF73), // luminous champagne gold
            Color(0xFFD4AF37), // rich gold
            Color(0xFFAA7C11), // deep antique bronze gold
            Color(0xFFF5D77F), // bright gold highlight
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(
              alpha: widget.isDark ? 0.32 : 0.22,
            ),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          if (widget.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: const EdgeInsets.all(1.8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: _handleTap,
          splashColor: const Color(0xFFD4AF37).withValues(alpha: 0.15),
          highlightColor: const Color(0xFFD4AF37).withValues(alpha: 0.08),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              color: widget.isDark
                  ? const Color(0xFF141416)
                  : Colors.white,
            ),
            padding: const EdgeInsets.only(left: 18, right: 6, top: 4, bottom: 4),
            child: Row(
              children: [
                // Typewriter animated prompt text with blinking golden cursor
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _displayedText.isEmpty ? 'Ask Aarna...' : _displayedText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: widget.palette.textPrimary.withValues(
                              alpha: widget.isDark ? 0.90 : 0.85,
                            ),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      // Blinking golden cursor (|)
                      AnimatedBuilder(
                        animation: _cursorController,
                        builder: (context, _) {
                          return Opacity(
                            opacity: _cursorController.value > 0.4 ? 1.0 : 0.0,
                            child: Text(
                              '|',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFD4AF37),
                                height: 1.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Living 3D Aarna AI Character Orb (waving hand & blinking eyes!)
                AarnaLivingAvatar(
                  size: 44,
                  pose: _getPoseForPrompt(_promptIndex),
                  isSearching: _getPoseForPrompt(_promptIndex) == AarnaPose.searching,
                  showSparkle: true,
                  showOnlineBadge: true,
                  onTap: _handleTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
