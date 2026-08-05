import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class StoneGridTile extends ConsumerStatefulWidget {
  final Stone stone;
  final VoidCallback? onTap;
  final VoidCallback? onWishlist;
  final bool isWishlisted;
  final double? width;
  final double? height;

  const StoneGridTile({
    super.key,
    required this.stone,
    this.onTap,
    this.onWishlist,
    this.isWishlisted = false,
    this.width,
    this.height,
  });

  @override
  ConsumerState<StoneGridTile> createState() => _StoneGridTileState();
}

class _StoneGridTileState extends ConsumerState<StoneGridTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final imageUrl = widget.stone.imageUrl ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: HoverScale(
        scale: 1.02,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: palette.primary.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: -4,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 12,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isHovered
                        ? palette.primary.withValues(alpha: 0.5)
                        : palette.border,
                    width: _isHovered ? 1.5 : 0.8,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildImage(imageUrl, palette),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildInfo(palette),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, LuxuryPalette palette) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // SmartStoneImage handles asset & network images seamlessly
        SmartStoneImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          palette: palette,
        ),

        // Bottom gradient for visual depth
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
            ),
          ),
        ),

        // Price tag badge
        Positioned(
          top: 10,
          right: 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette.primary.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '₹${widget.stone.pricePerSqFt.toInt()}',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.primary,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Wishlist button
        Positioned(
          top: 10,
          left: 10,
          child: _buildWishlistButton(palette),
        ),
      ],
    );
  }

  Widget _buildWishlistButton(LuxuryPalette palette) {
    return GestureDetector(
      onTap: widget.onWishlist,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: widget.isWishlisted
              ? palette.primary.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isWishlisted
                ? palette.primary
                : Colors.white.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
        child: Icon(
          widget.isWishlisted
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          size: 16,
          color: widget.isWishlisted ? palette.primary : Colors.white,
        ),
      ),
    );
  }

  Widget _buildInfo(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: palette.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.stone.name,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: palette.textPrimary,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            widget.stone.collection,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: palette.textSecondary,
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              if (widget.stone.rating > 0) ...[
                Icon(Icons.star_rounded, size: 13, color: palette.primary),
                const SizedBox(width: 3),
                Text(
                  widget.stone.rating.toStringAsFixed(1),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const Spacer(),
              ] else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: palette.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: palette.border, width: 0.5),
                ),
                child: Text(
                  widget.stone.finish.isEmpty ? 'Natural' : widget.stone.finish,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: palette.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
