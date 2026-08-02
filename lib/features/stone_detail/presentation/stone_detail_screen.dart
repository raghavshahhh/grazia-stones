import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/tokens.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/features/cart/providers/cart_provider.dart';

class StoneDetailScreen extends StatefulWidget {
  final String stoneId;

  const StoneDetailScreen({super.key, required this.stoneId});

  @override
  State<StoneDetailScreen> createState() => _StoneDetailScreenState();
}

class _StoneDetailScreenState extends State<StoneDetailScreen> {
  int _quantity = 1;
  bool _isWishlisted = false;
  String? _selectedColor;

  Stone? get _stone => MockDataService.getStoneById(widget.stoneId);

  double get _pricePerSqFt => _stone?.pricePerSqFt ?? 0;

  double get _discount {
    if (_quantity >= 500) return 0.10;
    if (_quantity >= 100) return 0.05;
    return 0.0;
  }

  String get _discountLabel {
    if (_quantity >= 500) return '10% Bulk Discount';
    if (_quantity >= 100) return '5% Bulk Discount';
    return '';
  }

  double get _totalPrice => _pricePerSqFt * _quantity * (1 - _discount);

  double get _totalSaved => _pricePerSqFt * _quantity * _discount;

  @override
  void initState() {
    super.initState();
    if (_stone != null && _stone!.availableColors.isNotEmpty) {
      _selectedColor = _stone!.availableColors.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final stone = _stone;

    if (stone == null) {
      return Scaffold(
        backgroundColor: palette.background,
        body: Center(
          child: Text(
            'Stone not found',
            style: GLuxuryTypography.bodyLarge.copyWith(color: palette.textSecondary),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(stone, palette),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(stone, palette),
                _buildSpecCards(stone, palette),
                _buildQuantitySelector(palette),
                _buildPriceBreakdown(palette),
                _buildDescription(stone, palette),
                _buildColorSection(stone, palette),
                _buildReviewSection(palette),
                const SizedBox(height: GTokens.space6),
                _buildActionButtons(stone, palette),
                SizedBox(height: MediaQuery.of(context).padding.bottom + GTokens.space6),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(Stone stone, LuxuryPalette palette) {
    return SliverAppBar(
      expandedHeight: 360,
      pinned: true,
      backgroundColor: palette.background,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.all(GTokens.space2 + 2),
          decoration: BoxDecoration(
            color: palette.surfaceLight.withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(color: palette.border, width: 0.5),
          ),
          child: Icon(
            Icons.arrow_back_ios_new,
            color: palette.textPrimary,
            size: 18,
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () => setState(() => _isWishlisted = !_isWishlisted),
          child: Container(
            margin: const EdgeInsets.all(GTokens.space2 + 2),
            decoration: BoxDecoration(
              color: palette.surfaceLight.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: palette.border, width: 0.5),
            ),
            child: Icon(
              _isWishlisted ? Icons.favorite : Icons.favorite_border,
              color: _isWishlisted ? palette.primary : palette.textPrimary,
              size: 20,
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [palette.surfaceLight, palette.background],
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(GTokens.radius2xl),
                    gradient: LinearGradient(
                      colors: [
                        palette.primaryDark.withValues(alpha: 0.12),
                        palette.primary.withValues(alpha: 0.15),
                        palette.primaryLight.withValues(alpha: 0.12),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    border: Border.all(
                      color: palette.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.landscape,
                        size: 56,
                        color: palette.primary,
                      ),
                      const SizedBox(height: GTokens.space2),
                      Text(
                        stone.collection,
                        style: GLuxuryTypography.labelMedium.copyWith(
                          color: palette.primary.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, palette.background],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Stone stone, LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space4, GTokens.space5, 0),
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
                    Text(stone.name, style: GLuxuryTypography.h2),
                    const SizedBox(height: GTokens.space1),
                    Text(
                      stone.collection,
                      style: GLuxuryTypography.labelMedium.copyWith(color: palette.primary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${stone.pricePerSqFt.toStringAsFixed(0)}',
                    style: GLuxuryTypography.priceLarge.copyWith(color: palette.primary),
                  ),
                  Text(
                    '/sqft',
                    style: GLuxuryTypography.labelSmall.copyWith(color: palette.textTertiary),
                  ),
                  const SizedBox(height: GTokens.space1),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: palette.primary, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        '${stone.rating}',
                        style: GLuxuryTypography.labelSmall.copyWith(color: palette.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${stone.reviewCount})',
                        style: GLuxuryTypography.labelSmall.copyWith(color: palette.textTertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCards(Stone stone, LuxuryPalette palette) {
    final specs = <Map<String, dynamic>>[
      {'icon': Icons.straighten, 'label': 'Thickness', 'value': stone.thickness},
      {'icon': Icons.auto_awesome, 'label': 'Finish', 'value': stone.finish},
      {'icon': Icons.crop_square, 'label': 'Size', 'value': stone.size},
      {'icon': Icons.public, 'label': 'Origin', 'value': stone.origin},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space5, GTokens.space5, 0),
      child: Row(
        children: specs.map((s) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: GTokens.space1),
              padding: const EdgeInsets.symmetric(vertical: GTokens.space3, horizontal: GTokens.space2),
              decoration: BoxDecoration(
                color: palette.surfaceLight,
                borderRadius: BorderRadius.circular(GTokens.radiusLg),
                border: Border.all(color: palette.border, width: 0.5),
              ),
              child: Column(
                children: [
                  Icon(s['icon'] as IconData, color: palette.primary, size: GTokens.iconSm),
                  const SizedBox(height: GTokens.space1 + 2),
                  Text(
                    s['value']!,
                    style: GLuxuryTypography.bodySmall.copyWith(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s['label']!,
                    style: GLuxuryTypography.labelSmall.copyWith(
                      color: palette.textTertiary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuantitySelector(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space6, GTokens.space5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quantity (sqft)', style: GLuxuryTypography.h3),
          const SizedBox(height: GTokens.space3),
          Container(
            decoration: BoxDecoration(
              color: palette.surfaceLight,
              borderRadius: BorderRadius.circular(GTokens.radiusXl),
              border: Border.all(color: palette.border, width: 0.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: GTokens.space2, vertical: GTokens.space1),
            child: Row(
              children: [
                _qtyButton(palette, Icons.remove, () {
                  if (_quantity > 1) setState(() => _quantity--);
                }),
                Expanded(
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: GTokens.space2),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(GTokens.radiusMd),
                    ),
                    child: TextField(
                      controller: TextEditingController(text: _quantity.toString()),
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GLuxuryTypography.priceMedium.copyWith(color: palette.textPrimary),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: GTokens.space2),
                        suffixText: 'sqft',
                        suffixStyle: GLuxuryTypography.bodySmall.copyWith(color: palette.textTertiary),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val);
                        if (parsed != null && parsed >= 1 && parsed <= 9999) {
                          setState(() => _quantity = parsed);
                        }
                      },
                    ),
                  ),
                ),
                _qtyButton(palette, Icons.add, () {
                  if (_quantity < 9999) setState(() => _quantity++);
                }),
              ],
            ),
          ),
          if (_discountLabel.isNotEmpty) ...[
            const SizedBox(height: GTokens.space3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: GTokens.space3, vertical: GTokens.space1 + 2),
              decoration: BoxDecoration(
                color: palette.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(GTokens.radiusFull),
                border: Border.all(color: palette.success.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer, size: 14, color: palette.success),
                  const SizedBox(width: GTokens.space1),
                  Text(
                    _discountLabel,
                    style: GLuxuryTypography.labelMedium.copyWith(color: palette.success),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _qtyButton(LuxuryPalette palette, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: palette.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: palette.primary, size: 20),
      ),
    );
  }

  Widget _buildPriceBreakdown(LuxuryPalette palette) {
    final unitPrice = _pricePerSqFt;
    final discountPct = (_discount * 100).toInt();
    final saved = _totalSaved;

    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space5, GTokens.space5, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(GTokens.radiusXl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: GTokens.blurMd, sigmaY: GTokens.blurMd),
          child: Container(
            padding: const EdgeInsets.all(GTokens.space4),
            decoration: BoxDecoration(
              color: palette.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(GTokens.radiusXl),
              border: Border.all(color: palette.border, width: 0.5),
            ),
            child: Column(
              children: [
                _priceRow(palette, 'Unit Price', '₹${unitPrice.toStringAsFixed(0)}/sqft'),
                const SizedBox(height: GTokens.space2),
                _priceRow(palette, 'Quantity', '$_quantity sqft'),
                if (discountPct > 0) ...[
                  const SizedBox(height: GTokens.space2),
                  _priceRow(palette, 'Discount', '-$discountPct%', color: palette.success),
                ],
                Divider(color: palette.border, height: GTokens.space4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${_totalPrice.toStringAsFixed(0)}',
                          style: GLuxuryTypography.priceLarge.copyWith(color: palette.primary),
                        ),
                        if (saved > 0)
                          Text(
                            'You save ₹${saved.toStringAsFixed(0)}',
                            style: GLuxuryTypography.labelSmall.copyWith(color: palette.success),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _priceRow(LuxuryPalette palette, String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary)),
        Text(
          value,
          style: GLuxuryTypography.bodyMedium.copyWith(
            color: color ?? palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(Stone stone, LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space6, GTokens.space5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: GLuxuryTypography.h3),
          const SizedBox(height: GTokens.space3),
          Text(
            stone.description,
            style: GLuxuryTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSection(Stone stone, LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space6, GTokens.space5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Colors', style: GLuxuryTypography.h3),
          const SizedBox(height: GTokens.space3),
          Wrap(
            spacing: GTokens.space3,
            runSpacing: GTokens.space2,
            children: stone.availableColors.map((hex) {
              final c = Color(int.parse(hex.replaceAll('#', '0xFF')));
              final isSelected = hex == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? palette.primary : palette.border,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: palette.primary.withValues(alpha: 0.3), blurRadius: 8)]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, color: palette.textPrimary, size: 16)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewSection(LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space6, GTokens.space5, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Reviews', style: GLuxuryTypography.h3),
              Text(
                'See All',
                style: GLuxuryTypography.labelMedium.copyWith(color: palette.primary),
              ),
            ],
          ),
          const SizedBox(height: GTokens.space3),
          _reviewCard(
            palette,
            name: 'Arjun M.',
            rating: 5,
            date: '2 days ago',
            text: 'Stunning quality. The finish is exactly as shown. Perfect for our kitchen renovation.',
          ),
          const SizedBox(height: GTokens.space2 + 2),
          _reviewCard(
            palette,
            name: 'Priya S.',
            rating: 4,
            date: '1 week ago',
            text: 'Great stone, slightly darker than expected but still beautiful. Fast delivery.',
          ),
        ],
      ),
    );
  }

  Widget _reviewCard(LuxuryPalette palette, {required String name, required int rating, required String date, required String text}) {
    return Container(
      padding: const EdgeInsets.all(GTokens.space3),
      decoration: BoxDecoration(
        color: palette.surfaceLight,
        borderRadius: BorderRadius.circular(GTokens.radiusLg),
        border: Border.all(color: palette.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: palette.primary.withValues(alpha: 0.2),
                child: Text(
                  name[0],
                  style: GLuxuryTypography.labelSmall.copyWith(color: palette.primary),
                ),
              ),
              const SizedBox(width: GTokens.space2),
              Text(name, style: GLuxuryTypography.labelMedium.copyWith(color: palette.textPrimary)),
              const Spacer(),
              Text(date, style: GLuxuryTypography.labelSmall.copyWith(color: palette.textTertiary)),
            ],
          ),
          const SizedBox(height: GTokens.space2),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star : Icons.star_border,
                color: palette.primary,
                size: 14,
              ),
            ),
          ),
          const SizedBox(height: GTokens.space2),
          Text(
            text,
            style: GLuxuryTypography.bodySmall.copyWith(
              color: palette.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Stone stone, LuxuryPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(GTokens.space5, GTokens.space5, GTokens.space5, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GraziaButton(
                  label: 'AI Visualize',
                  icon: Icons.auto_awesome_outlined,
                  variant: GraziaButtonVariant.outline,
                  onPressed: () => context.push('/ai-viz'),
                ),
              ),
              const SizedBox(width: GTokens.space3),
              Expanded(
                child: GraziaButton(
                  label: 'View in AR',
                  icon: Icons.view_in_ar_outlined,
                  variant: GraziaButtonVariant.outline,
                  onPressed: () => context.push('/ar-view'),
                ),
              ),
            ],
          ),
          const SizedBox(height: GTokens.space3),
          GraziaButton(
            label: 'Add to Cart — ₹${_totalPrice.toStringAsFixed(0)}',
            icon: Icons.shopping_cart_outlined,
            onPressed: () {
              context.read<CartProvider>().addItem(stone);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${stone.name} added to cart'),
                  backgroundColor: palette.primary,
                  duration: const Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GTokens.radiusMd)),
                ),
              );
            },
          ),
          const SizedBox(height: GTokens.space3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/quotes'),
              icon: Icon(Icons.request_quote_outlined, color: palette.primary, size: 18),
              label: Text(
                'Request Quote',
                style: GLuxuryTypography.bodyMedium.copyWith(color: palette.primary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.primary, width: 0.8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GTokens.radiusLg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
