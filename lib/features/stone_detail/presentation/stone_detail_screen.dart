import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/core/di.dart';

class StoneDetailScreen extends ConsumerStatefulWidget {
  final String stoneId;

  const StoneDetailScreen({super.key, required this.stoneId});

  @override
  ConsumerState<StoneDetailScreen> createState() => _StoneDetailScreenState();
}

class _StoneDetailScreenState extends ConsumerState<StoneDetailScreen> {
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _isWishlisted = false;

  Stone? get _stone => MockDataService.getStoneById(widget.stoneId);

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final stone = _stone;

    if (stone == null) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(child: Text('Stone not found', style: GLuxuryTypography.bodyLarge)),
      );
    }

    final images = stone.images.isNotEmpty ? stone.images : [stone.imageUrl ?? ''];

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Image Gallery
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                backgroundColor: palette.background,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.background.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.arrow_back_ios_new, size: 18, color: palette.textPrimary),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isWishlisted = !_isWishlisted);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: palette.background.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isWishlisted ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: _isWishlisted ? Colors.red : palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImageIndex = i),
                        itemBuilder: (context, i) {
                          return Image.network(
                            images[i],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: palette.surfaceDark,
                              child: Icon(Icons.image_outlined, size: 80, color: palette.textTertiary),
                            ),
                          );
                        },
                      ),
                      // Gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                palette.background.withValues(alpha: 0.8),
                                palette.background,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Page indicators
                      if (images.length > 1)
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _currentImageIndex ? 24 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: i == _currentImageIndex
                                      ? palette.primary
                                      : palette.textTertiary.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: GLuxurySpacing.horizontalBase,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GLuxurySpacing.gapBase,
                      
                      // Stock badge
                      if (stone.inStock)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                'In Stock',
                                style: GLuxuryTypography.labelSmall.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      GLuxurySpacing.gapSm,
                      
                      // Name
                      Text(
                        stone.name,
                        style: GLuxuryTypography.h1.copyWith(
                          color: palette.textPrimary,
                          fontSize: 28,
                        ),
                      ),
                      
                      GLuxurySpacing.gapXs,
                      
                      // Product code & Collection
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              stone.productCode,
                              style: GLuxuryTypography.labelSmall.copyWith(
                                color: palette.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            stone.collection,
                            style: GLuxuryTypography.bodyMedium.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      
                      GLuxurySpacing.gapBase,
                      
                      // Rating
                      Row(
                        children: [
                          Icon(Icons.star_rounded, color: palette.primary, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            stone.rating.toString(),
                            style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '(${stone.reviewCount} reviews)',
                            style: GLuxuryTypography.bodySmall.copyWith(color: palette.textTertiary),
                          ),
                        ],
                      ),
                      
                      GLuxurySpacing.gapXl,
                      
                      // Price
                      Row(
                        children: [
                          Text(
                            '₹${stone.pricePerSqFt.toInt()}',
                            style: GLuxuryTypography.displayMedium.copyWith(
                              color: palette.primary,
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '/ sq ft',
                            style: GLuxuryTypography.bodyMedium.copyWith(
                              color: palette.textTertiary,
                            ),
                          ),
                        ],
                      ),
                      
                      GLuxurySpacing.gapXl,
                      
                      // Quick Actions
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickAction(
                              palette,
                              Icons.auto_awesome_outlined,
                              'AI Viz',
                              () => context.push('/ai-viz'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildQuickAction(
                              palette,
                              Icons.view_in_ar_outlined,
                              'AR View',
                              () => context.push('/ar-view'),
                            ),
                          ),
                        ],
                      ),
                      
                      GLuxurySpacing.gapXl,
                      
                      // Specifications
                      Text(
                        'Specifications',
                        style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                      ),
                      GLuxurySpacing.gapBase,
                      
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _buildSpecCard(palette, 'Size', stone.size),
                          _buildSpecCard(palette, 'Thickness', stone.thickness),
                          _buildSpecCard(palette, 'Finish', stone.finish),
                          _buildSpecCard(palette, 'Texture', stone.texture),
                          _buildSpecCard(palette, 'Sqft/Box', '${stone.sqftPerBox}'),
                          _buildSpecCard(palette, 'Pieces/Box', '${stone.piecesPerBox}'),
                        ],
                      ),
                      
                      GLuxurySpacing.gapXl,
                      
                      // Description
                      Text(
                        'Description',
                        style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                      ),
                      GLuxurySpacing.gapSm,
                      Text(
                        stone.description,
                        style: GLuxuryTypography.bodyLarge.copyWith(
                          color: palette.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      
                      GLuxurySpacing.gapXl,
                      
                      // Ideal For
                      if (stone.idealFor.isNotEmpty) ...[
                        Text(
                          'Ideal For',
                          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                        ),
                        GLuxurySpacing.gapSm,
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: stone.idealFor.map((app) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: palette.border),
                              ),
                              child: Text(
                                app,
                                style: GLuxuryTypography.bodySmall.copyWith(
                                  color: palette.textSecondary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        GLuxurySpacing.gapXl,
                      ],
                      
                      // Available Colors
                      if (stone.availableColors.isNotEmpty) ...[
                        Text(
                          'Available Colors',
                          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
                        ),
                        GLuxurySpacing.gapSm,
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: stone.availableColors.map((color) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: palette.primaryGradient,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                color,
                                style: GLuxuryTypography.bodySmall.copyWith(
                                  color: palette.background,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      
                      SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: palette.background,
                border: Border(top: BorderSide(color: palette.border, width: 0.5)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      palette,
                      'Add to Cart',
                      Icons.shopping_cart_outlined,
                      () {
                        HapticFeedback.mediumImpact();
                        // Add to cart logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to cart'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      isPrimary: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      palette,
                      'Sample Order',
                      Icons.inventory_2_outlined,
                      () => context.push('/sample-order'),
                      isPrimary: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(GoldPalette palette, IconData icon, String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: palette.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GLuxuryTypography.labelMedium.copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecCard(GoldPalette palette, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GLuxuryTypography.labelSmall.copyWith(
              color: palette.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GLuxuryTypography.bodyMedium.copyWith(
              color: palette.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(GoldPalette palette, String label, IconData icon, VoidCallback onTap, {required bool isPrimary}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: isPrimary ? palette.primaryGradient : null,
            color: isPrimary ? null : palette.surface,
            borderRadius: BorderRadius.circular(28),
            border: isPrimary ? null : Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? palette.background : palette.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GLuxuryTypography.labelLarge.copyWith(
                  color: isPrimary ? palette.background : palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
