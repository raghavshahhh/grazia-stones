import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';

class GraziaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final VoidCallback? onBackPressed;
  final List<Widget>? actions;
  final Widget? leading;
  final bool transparent;

  const GraziaAppBar({
    super.key,
    required this.title,
    this.showBack = true,
    this.onBackPressed,
    this.actions,
    this.leading,
    this.transparent = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: transparent
              ? Colors.transparent
              : AppColors.black.withOpacity(0.95),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  if (showBack)
                    IconButton(
                      onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
                        color: AppColors.silverLight,
                      ),
                    )
                  else if (leading != null)
                    leading!,
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  if (actions != null) ...actions!,
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
