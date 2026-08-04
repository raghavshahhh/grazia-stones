import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';

import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/theme/glass_theme.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';

class StoneGridTile extends StatefulWidget {
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
  State<StoneGridTile> createState() => _StoneGridTileState();
}

class _StoneGridTileState extends State<StoneGridTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = widget.stone.imageUrl ?? '';
    final hasImage = imageUrl.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: HoverScale(
        scale: 1.02,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: GlassTheme.durationNormal,
            curve: Curves.easeOutCubic,
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppColors.goldWarm.withValues(alpha: 0.12),
                        blurRadius: 28,
                        spreadRadius: -6,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: -4,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: _isHovered ? 12 : 6,
                  sigmaY: _isHovered ? 12 : 6,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: _isHovered ? 0.08 : 0.04),
                    border: Border.all(
                      color: _isHovered
                          ? AppColors.goldWarm.withValues(alpha: 0.25)
                          : AppColors.white.withValues(alpha: 0.06),
                      width: _isHovered ? 1.0 : 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildImage(imageUrl, hasImage)),
                      Expanded(flex: 2, child: _buildInfo()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl, bool hasImage) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasImage)
          Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildShimmer();
            },
            errorBuilder: (context, error, stackTrace) => _buildShimmer(),
          )
        else
          _buildShimmer(),

        // Gradient overlay at bottom
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
                  AppColors.charcoal.withValues(alpha: 0.8),
                ],
              ),
            ),
          ),
        ),

        // Price badge
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
                  color: AppColors.charcoal.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.goldWarm.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '₹${widget.stone.pricePerSqFt.toInt()}',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.goldWarm,
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
          child: _buildWishlistButton(),
        ),
      ],
    );
  }

  Widget _buildWishlistButton() {
    return GestureDetector(
      onTap: widget.onWishlist,
      child: AnimatedContainer(
        duration: GlassTheme.durationFast,
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: widget.isWishlisted
              ? AppColors.goldWarm.withValues(alpha: 0.2)
              : AppColors.charcoal.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isWishlisted
                ? AppColors.goldWarm.withValues(alpha: 0.3)
                : AppColors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: Icon(
          widget.isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 16,
          color: widget.isWishlisted ? AppColors.goldWarm : AppColors.silverLight,
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ShimmerWidget(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF2A2A2A),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.charcoal.withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.stone.name,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
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
              color: AppColors.goldWarm.withValues(alpha: 0.7),
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Row(
            children: [
              if (widget.stone.rating > 0) ...[
                const Icon(Icons.star_rounded, size: 12, color: AppColors.goldWarm),
                const SizedBox(width: 2),
                Text(
                  widget.stone.rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.silverLight,
                  ),
                ),
                const Spacer(),
              ] else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.stone.finish.isEmpty ? 'Natural' : widget.stone.finish,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppColors.silverDark.withValues(alpha: 0.7),
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
