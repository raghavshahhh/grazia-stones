import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/shared/widgets/luxury_bottom_sheet.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  final List<_WishlistItem> _items = [
    _WishlistItem(
      name: 'Charcoal Black',
      collection: 'Basalt Series',
      price: '\$42/sqft',
      colorHex: '#2D2D2D',
      sqft: 150,
    ),
    _WishlistItem(
      name: 'Ivory Travertine',
      collection: 'Classica',
      price: '\$56/sqft',
      colorHex: '#F5F0EB',
      sqft: 80,
    ),
    _WishlistItem(
      name: 'Nero Marquina',
      collection: 'Marquina Premium',
      price: '\$68/sqft',
      colorHex: '#1A1A1A',
      sqft: 200,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Wishlist',
          style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          if (_items.isNotEmpty)
            TextButton(
              onPressed: () {},
              child: Text(
                'Clear All',
                style: GraziaTextStyles.bodySmall
                    .copyWith(color: AppColors.goldWarm),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: _items.isEmpty
            ? _buildEmptyState()
            : _buildWishlistBody(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.favorite_border, size: 80, color: AppColors.slate),
          const SizedBox(height: 16),
          Text(
            'Your wishlist is empty',
            style:
                GraziaTextStyles.titleMedium.copyWith(color: AppColors.silver),
          ),
          const SizedBox(height: 8),
          Text(
            'Save stones you love for later',
            style:
                GraziaTextStyles.bodyMedium.copyWith(color: AppColors.slate),
          ),
          const SizedBox(height: 24),
          GraziaButton(
            label: 'Browse Stones',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistBody() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppDimensions.spacingL),
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return _WishlistCard(
                item: item,
                onRemove: () => setState(() => _items.removeAt(index)),
                onTap: () => _showMoveToCartSheet(item),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          decoration: const BoxDecoration(
            color: AppColors.graphite,
            border: Border(top: BorderSide(color: AppColors.slate)),
          ),
          child: GraziaButton(
            label: 'Move All to Cart',
            icon: Icons.shopping_bag_outlined,
            onPressed: () {
              // TODO: move all to cart
            },
          ),
        ),
      ],
    );
  }

  void _showMoveToCartSheet(_WishlistItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LuxuryBottomSheet(
        title: 'Move to Cart',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(
                          int.parse(item.colorHex.replaceFirst('#', '0xFF'))),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: GraziaTextStyles.bodyLarge
                                .copyWith(color: Colors.white)),
                        Text('${item.sqft} sqft · ${item.price}',
                            style: GraziaTextStyles.bodySmall
                                .copyWith(color: AppColors.silver)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            GraziaButton(
              label: 'Add to Cart',
              onPressed: () {
                Navigator.pop(context);
                setState(() => _items.remove(item));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _WishlistCard extends StatelessWidget {
  final _WishlistItem item;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _WishlistCard({
    required this.item,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(
        int.parse(item.colorHex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.slate),
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.borderLight),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: GraziaTextStyles.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.collection,
                    style: GraziaTextStyles.bodySmall
                        .copyWith(color: AppColors.silver),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.price,
                        style: GraziaTextStyles.bodyMedium.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.sqft} sqft',
                        style: GraziaTextStyles.bodySmall
                            .copyWith(color: AppColors.slate),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 20),
                  color: AppColors.slate,
                ),
                const SizedBox(height: 4),
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  color: AppColors.gold,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistItem {
  final String name;
  final String collection;
  final String price;
  final String colorHex;
  final int sqft;

  const _WishlistItem({
    required this.name,
    required this.collection,
    required this.price,
    required this.colorHex,
    required this.sqft,
  });
}
