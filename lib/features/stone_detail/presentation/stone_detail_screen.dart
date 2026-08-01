import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/core/providers/cart_provider.dart';

class StoneDetailScreen extends StatelessWidget {
  final String stoneId;

  const StoneDetailScreen({super.key, required this.stoneId});

  @override
  Widget build(BuildContext context) {
    final stone = MockDataService.getStoneById(stoneId);
    if (stone == null) {
      return Scaffold(
        backgroundColor: AppColors.charcoal,
        body: Center(
          child: Text(
            'Stone not found',
            style: GraziaTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.charcoal,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 340,
            pinned: true,
            backgroundColor: AppColors.charcoal,
            leading: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.favorite_border, color: AppColors.white),
                  onPressed: () {},
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.surfaceMedium, AppColors.charcoal],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: AppColors.goldGradient.withOpacity(0.15),
                          border: Border.all(
                            color: AppColors.goldWarm.withOpacity(0.3),
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.landscape, size: 60, color: AppColors.goldWarm),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(stone.name, style: GraziaTextStyles.h3),
                            const SizedBox(height: 4),
                            Text(
                              stone.collection,
                              style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.goldWarm),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${stone.pricePerSqFt.toStringAsFixed(0)}/sqft',
                            style: GraziaTextStyles.h3.copyWith(color: AppColors.goldWarm),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: AppColors.goldWarm, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${stone.rating} (${stone.reviewCount} reviews)',
                                style: GraziaTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  _buildSpecsRow(stone),
                  const SizedBox(height: 24),

                  Text('Description', style: GraziaTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    stone.description,
                    style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.6),
                  ),

                  const SizedBox(height: 24),
                  Text('Available Colors', style: GraziaTextStyles.titleMedium),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      for (var i = 0; i < stone.availableColors.length; i++)
                        _colorDot(Color(int.parse(stone.availableColors[i].replaceAll('#', '0xFF'))), i == 0),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: GraziaButton(
                          label: 'AI Visualize',
                          icon: Icons.auto_awesome_outlined,
                          variant: GraziaButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pushNamed('/ai-viz'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GraziaButton(
                          label: 'View in AR',
                          icon: Icons.view_in_ar_outlined,
                          variant: GraziaButtonVariant.outline,
                          onPressed: () => Navigator.of(context).pushNamed('/ar-view'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GraziaButton(
                    label: 'Add to Cart',
                    icon: Icons.shopping_cart_outlined,
                    onPressed: () {
                      context.read<CartProvider>().addItem(stone);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${stone.name} added to cart'),
                          backgroundColor: AppColors.goldWarm,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/quotes'),
                      icon: const Icon(Icons.request_quote_outlined, color: AppColors.goldWarm, size: 18),
                      label: Text(
                        'Request Quote',
                        style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.goldWarm),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.goldWarm, width: 0.8),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecsRow(Stone stone) {
    final specs = [
      {'label': 'Thickness', 'value': stone.thickness},
      {'label': 'Finish', 'value': stone.finish},
      {'label': 'Size', 'value': stone.size},
      {'label': 'Origin', 'value': stone.origin},
    ];

    return Row(
      children: specs.map((s) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderSubtle, width: 0.5),
            ),
            child: Column(
              children: [
                Text(
                  s['value']!,
                  style: GraziaTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  s['label']!,
                  style: GraziaTextStyles.labelSmall.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _colorDot(Color color, bool selected) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.goldWarm : AppColors.borderSubtle,
          width: selected ? 2 : 1,
        ),
      ),
      child: selected ? const Icon(Icons.check, color: AppColors.charcoal, size: 14) : null,
    );
  }
}
