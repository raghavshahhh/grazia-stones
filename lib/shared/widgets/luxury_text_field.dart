import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/tokens.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';

/// Glass-morphism text field with floating label, validation, icons.
class GLuxuryTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? error;
  final String? prefixText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool readOnly;
  final int maxLines;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  const GLuxuryTextField({
    super.key,
    this.label,
    this.hint,
    this.error,
    this.prefixText,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.controller,
    this.keyboardType,
    this.obscure = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
  });

  @override
  State<GLuxuryTextField> createState() => _GLuxuryTextFieldState();
}

class _GLuxuryTextFieldState extends State<GLuxuryTextField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final hasError = widget.error != null && widget.error!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: GTokens.space1, bottom: GTokens.space2),
            child: Text(
              widget.label!.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: _isFocused ? palette.primary : palette.textTertiary,
              ),
            ),
          ),
        ],
        AnimatedContainer(
          duration: GTokens.durationFast,
          decoration: BoxDecoration(
            color: palette.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(GTokens.radiusMd),
            border: Border.all(
              color: hasError
                  ? palette.error
                  : _isFocused
                      ? palette.primary.withValues(alpha: 0.6)
                      : palette.border,
              width: hasError || _isFocused ? 1.5 : 1,
            ),
            boxShadow: _isFocused ? GLuxuryShadows.goldGlowSubtle : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(GTokens.radiusMd),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: GTokens.blurSm, sigmaY: GTokens.blurSm),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                keyboardType: widget.keyboardType,
                obscureText: widget.obscure,
                readOnly: widget.readOnly,
                maxLines: widget.maxLines,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
                inputFormatters: widget.inputFormatters,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: palette.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 15,
                    color: palette.textTertiary.withValues(alpha: 0.6),
                  ),
                  prefixText: widget.prefixText,
                  prefixIcon: widget.prefixIcon != null
                      ? Padding(
                          padding: const EdgeInsets.only(left: 14, right: 10),
                          child: Icon(
                            widget.prefixIcon,
                            size: 20,
                            color: _isFocused ? palette.primary : palette.textTertiary,
                          ),
                        )
                      : null,
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: widget.suffixIcon != null
                      ? GestureDetector(
                          onTap: widget.onSuffixTap,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Icon(
                              widget.suffixIcon,
                              size: 20,
                              color: palette.textTertiary,
                            ),
                          ),
                        )
                      : null,
                  suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: GTokens.space4,
                    vertical: GTokens.space4,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: GTokens.space1, top: GTokens.space1),
            child: Text(
              widget.error!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: palette.error,
              ),
            ),
          ),
      ],
    );
  }
}
