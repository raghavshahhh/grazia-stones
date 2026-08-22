import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
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
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            title: Row(
              children: [
                Text(
                  'Cart & Project',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                if (items.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: palette.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${items.length}',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(cartProvider.notifier).clear();
                  },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.inter(color: palette.error, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(width: 8),
            ],
          ),

          if (items.isEmpty)
            SliverFillRemaining(child: _EmptyCart(palette: palette))
          else ...[
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                        SnackBar(
                          content: const Text('Removed from cart'),
                          backgroundColor: palette.textPrimary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
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
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Price Details',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _PriceRow(label: 'Subtotal', amount: subtotal, palette: palette),
                      const SizedBox(height: 12),
                      _PriceRow(label: 'GST (18%)', amount: gst, palette: palette),
                      const SizedBox(height: 12),
                      _PriceRow(label: 'Shipping / Transit Insurance', amount: shipping, palette: palette, highlight: shipping == 0),
                      Divider(color: palette.border, height: 28),
                      _PriceRow(label: 'Estimated Total', amount: total, palette: palette, isTotal: true),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 180),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, color: palette.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Free Shipping on orders above ₹10,000',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              subtotal < 10000
                                  ? 'Add ₹${(10000 - subtotal).toInt()} more to unlock complimentary delivery'
                                  : 'Complimentary shipping applied!',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: palette.textSecondary,
                              ),
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
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: MediaQuery.of(context).padding.bottom + 84,
              ),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.border, width: 1.0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Payable',
                        style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                      ),
                      Text(
                        '₹${total.toInt()}',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          color: palette.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CheckoutScreen(
                              items: items
                                  .map((item) => CheckoutItem(
                                        stoneId: item.stone.id,
                                        name: item.stone.name,
                                        quantity: item.quantity,
                                        price: item.stone.pricePerSqFt,
                                      ))
                                  .toList(),
                              subtotal: subtotal,
                              gst: gst,
                              shipping: shipping,
                              total: total,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Proceed to Checkout',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
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
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_bag_outlined, size: 40, color: palette.textTertiary),
          ),
          const SizedBox(height: 20),
          Text(
            'Your Cart is Empty',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore our curated collections and add\narchitectural stone slabs to your project.',
            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/collections'),
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: const Text('Browse Curated Stones'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
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
  const _CartCard({
    required this.item,
    required this.index,
    required this.palette,
    required this.onRemove,
    required this.onUpdateQty,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SmartStoneImage(
              localAsset: item.stone.images.isNotEmpty ? item.stone.images.first : null,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              fallbackColor: palette.surfaceDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.stone.name,
                        style: GoogleFonts.playfairDisplay(
                          color: palette.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close, color: palette.textTertiary, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  item.stone.collection,
                  style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: palette.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => onUpdateQty(-1),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.remove, size: 14, color: palette.textPrimary),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              '${item.quantity}',
                              style: GoogleFonts.inter(
                                color: palette.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => onUpdateQty(1),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.add, size: 14, color: palette.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${item.total.toInt()}',
                          style: GoogleFonts.inter(
                            color: palette.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '₹${item.stone.pricePerSqFt.toInt()}/sqft',
                          style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 10),
                        ),
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
  const _PriceRow({
    required this.label,
    required this.amount,
    required this.palette,
    this.isTotal = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            color: isTotal ? palette.textPrimary : palette.textSecondary,
          ),
        ),
        Text(
          highlight && amount == 0 ? 'FREE ✓' : '₹${amount.toInt()}',
          style: GoogleFonts.inter(
            fontSize: isTotal ? 18 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.w600,
            color: highlight && amount == 0
                ? palette.success
                : (isTotal ? palette.primary : palette.textPrimary),
          ),
        ),
      ],
    );
  }
}
