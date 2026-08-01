import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';

class GraziaTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? prefixIcon;
  final Widget? prefix;
  final Widget? suffix;
  final bool obscure;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final int maxLines;
  final int? maxLength;
  final FocusNode? focusNode;

  const GraziaTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.prefixIcon,
    this.prefix,
    this.suffix,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.maxLines = 1,
    this.maxLength,
    this.focusNode,
  });

  @override
  State<GraziaTextField> createState() => _GraziaTextFieldState();
}

class _GraziaTextFieldState extends State<GraziaTextField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(() {
      setState(() => _isFocused = widget.focusNode?.hasFocus ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _isFocused ? AppColors.goldWarm : AppColors.silverMedium,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: AppDimensions.xs),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: GlassTheme.durationNormal,
              decoration: BoxDecoration(
                color: _isFocused
                    ? AppColors.white.withOpacity(0.08)
                    : AppColors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isFocused
                      ? AppColors.goldWarm.withOpacity(0.3)
                      : AppColors.white.withOpacity(0.06),
                  width: _isFocused ? 1.0 : 0.5,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: AppColors.goldWarm.withOpacity(0.06),
                          blurRadius: 16,
                          spreadRadius: -4,
                        ),
                      ]
                    : null,
              ),
              child: TextFormField(
                controller: widget.controller,
                obscureText: widget.obscure,
                keyboardType: widget.keyboardType,
                validator: widget.validator,
                onChanged: widget.onChanged,
                readOnly: widget.readOnly,
                onTap: widget.onTap,
                maxLines: widget.maxLines,
                maxLength: widget.maxLength,
                focusNode: widget.focusNode,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.white,
                ),
                cursorColor: AppColors.goldWarm,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.silverDark.withOpacity(0.5),
                  ),
                  prefixIcon: widget.prefix ??
                      (widget.prefixIcon != null
                          ? Icon(widget.prefixIcon,
                              size: 20,
                              color: _isFocused
                                  ? AppColors.goldWarm
                                  : AppColors.silverDark)
                          : null),
                  suffixIcon: widget.suffix,
                  counterText: '',
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
