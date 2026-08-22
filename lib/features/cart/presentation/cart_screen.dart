import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/features/cart/presentation/checkout_screen.dart';

// ─── Cart State Model ──────────────────────────────────────
class CartItem {
  final Stone stone;
  int quantity;
  CartItem({required this.stone, this.quantity = 1});
  double get total => stone.pricePerSqFt * quantity;
}

// ─── Cart Provider ─────────────────────────────────────────
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void addItem(Stone stone) {
    final existing = state.indexWhere((i) => i.stone.id == stone.id);
    if (existing >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existing)
            CartItem(stone: state[i].stone, quantity: state[i].quantity + 1)
          else
            state[i]
      ];
    } else {
      state = [...state, CartItem(stone: stone)];
    }
  }

  void updateQuantity(int index, int delta) {
    final newQty = state[index].quantity + delta;
    if (newQty <= 0) {
      removeItem(index);
    } else {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == index)
            CartItem(stone: state[i].stone, quantity: newQty)
          else
            state[i]
      ];
    }
  }

  void removeItem(int index) {
    state = [...state]..removeAt(index);
  }

  void clear() => state = [];
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (_) => CartNotifier(),
);

// ─── Screen ───────────────────────────────────────────────
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final items = ref.watch(cartProvider);

    double subtotal = items.fold(0, (s, i) => s + i.total);
    double gst = subtotal * 0.18;
    double shipping = subtotal > 10000 ? 0 : 500;
    double total = subtotal + gst + shipping;

    return Scaffold(
      backgroundColor: palette.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: palette.background,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Text('My Cart', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
                const SizedBox(width: 8),
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text('${items.length}', style: TextStyle(color: palette.background, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () { HapticFeedback.mediumImpact(); ref.read(cartProvider.notifier).clear(); },
                  child: Text('Clear', style: TextStyle(color: palette.error, fontSize: 13)),
                ),
              const SizedBox(width: 8),
            ],
          ),

          if (items.isEmpty)
            SliverFillRemaining(child: _EmptyCart(palette: palette))
          else ...[
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _CartCard(
                    item: items[i],
                    index: i,
                    palette: palette,
                    onRemove: () {
                      HapticFeedback.mediumImpact();
                      ref.read(cartProvider.notifier).removeItem(i);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: const Text('Removed from cart'), backgroundColor: palette.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      );
                    },
                    onUpdateQty: (delta) {
                      HapticFeedback.lightImpact();
                      ref.read(cartProvider.notifier).updateQuantity(i, delta);
                    },
                  ),
                  childCount: items.length,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: palette.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Price Details', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
                      GLuxurySpacing.gapBase,
                      _PriceRow(label: 'Subtotal', amount: subtotal, palette: palette),
                      const SizedBox(height: 12),
                      _PriceRow(label: 'GST (18%)', amount: gst, palette: palette),
                      const SizedBox(height: 12),
                      _PriceRow(label: 'Shipping', amount: shipping, palette: palette, highlight: shipping == 0),
                      Divider(color: palette.border, height: 32),
                      _PriceRow(label: 'Total', amount: total, palette: palette, isTotal: true),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: palette.primaryGradient, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Icon(Icons.local_offer_outlined, color: palette.background),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Free Shipping on orders above ₹10,000', style: GLuxuryTypography.bodySmall.copyWith(color: palette.background, fontWeight: FontWeight.w600)),
                            Text(
                              subtotal < 10000 ? 'Add ₹${(10000 - subtotal).toInt()} more to unlock' : 'You have free shipping!',
                              style: GLuxuryTypography.labelSmall.copyWith(color: palette.background.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(color: palette.background, border: Border(top: BorderSide(color: palette.border)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 20, offset: const Offset(0, -4))]),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
                      Text('₹${total.toInt()}', style: GLuxuryTypography.h2.copyWith(color: palette.primary, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) => CheckoutScreen(
                            items: items.map((item) => CheckoutItem(stoneId: item.stone.id, name: item.stone.name, quantity: item.quantity, price: item.stone.pricePerSqFt)).toList(),
                            subtotal: subtotal, gst: gst, shipping: shipping, total: total,
                          ),
                        ));
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary, foregroundColor: palette.background,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), elevation: 0,
                      ),
                      child: Text('Proceed to Checkout', style: GLuxuryTypography.labelLarge.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final LuxuryPalette palette;
  const _EmptyCart({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 100, height: 100, decoration: BoxDecoration(color: palette.surfaceDark, borderRadius: BorderRadius.circular(28)), child: Icon(Icons.shopping_bag_outlined, size: 50, color: palette.textTertiary)),
          GLuxurySpacing.gapXl,
          Text('Your cart is empty', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          Text('Explore our collections and add\nyour favourite stones', style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary), textAlign: TextAlign.center),
          GLuxurySpacing.gapXxl,
          ElevatedButton.icon(
            onPressed: () => context.go('/collections'),
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: const Text('Browse Collections'),
            style: ElevatedButton.styleFrom(backgroundColor: palette.primary, foregroundColor: palette.background, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
          ),
        ],
      ),
    );
  }
}

class _CartCard extends StatelessWidget {
  final CartItem item;
  final int index;
  final LuxuryPalette palette;
  final VoidCallback onRemove;
  final ValueChanged<int> onUpdateQty;
  const _CartCard({required this.item, required this.index, required this.palette, required this.onRemove, required this.onUpdateQty});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: palette.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: palette.border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SmartStoneImage(localAsset: item.stone.images.isNotEmpty ? item.stone.images.first : null, width: 80, height: 80, fit: BoxFit.cover, fallbackColor: palette.surfaceDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: Text(item.stone.name, style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: palette.surfaceDark, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close, color: palette.textTertiary, size: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.stone.collection, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: palette.border), borderRadius: BorderRadius.circular(24)),
                      child: Row(
                        children: [
                          GestureDetector(onTap: () => onUpdateQty(-1), child: Container(padding: const EdgeInsets.all(8), child: Icon(Icons.remove, size: 16, color: palette.textPrimary))),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${item.quantity}', style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w700))),
                          GestureDetector(onTap: () => onUpdateQty(1), child: Container(padding: const EdgeInsets.all(8), child: Icon(Icons.add, size: 16, color: palette.textPrimary))),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${item.total.toInt()}', style: GLuxuryTypography.h3.copyWith(color: palette.primary, fontWeight: FontWeight.w700)),
                        Text('₹${item.stone.pricePerSqFt.toInt()}/sqft', style: GLuxuryTypography.labelSmall.copyWith(color: palette.textTertiary)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double amount;
  final LuxuryPalette palette;
  final bool isTotal;
  final bool highlight;
  const _PriceRow({required this.label, required this.amount, required this.palette, this.isTotal = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: (isTotal ? GLuxuryTypography.h3 : GLuxuryTypography.bodyMedium).copyWith(color: isTotal ? palette.textPrimary : palette.textSecondary)),
        Text(
          highlight && amount == 0 ? 'FREE ✓' : '₹${amount.toInt()}',
          style: (isTotal ? GLuxuryTypography.h2 : GLuxuryTypography.bodyMedium).copyWith(
            color: highlight && amount == 0 ? palette.success : (isTotal ? palette.primary : palette.textPrimary),
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
