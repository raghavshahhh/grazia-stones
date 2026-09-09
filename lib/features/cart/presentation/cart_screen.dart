import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:grazia_stones/core/widgets/animated_widgets.dart';
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
/// Real cart with dual-mode persistence:
/// - Logged in → Supabase `cart_items` (RLS-protected, survives
///   restart and cross-device login)
/// - Guest → local Hive cache (survives restart until login)
/// Every mutation updates memory + persistent store; a failed
/// Supabase write rolls back so the UI never shows a lie.
class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]) {
    _restore();
  }

  final _storage = StorageService.instance;

  /// Test/splash-safe Supabase access — returns null before Supabase
  /// has initialized instead of throwing an assertion.
  SupabaseClient? get _clientOrNull {
    try {
      return SupabaseService.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _userId => _clientOrNull?.auth.currentUser?.id;

  /// Load cart: Supabase is source of truth when logged in; local
  /// cache serves guests.
  Future<void> _restore() async {
    final client = _clientOrNull;
    final userId = client?.auth.currentUser?.id;
    if (client != null && userId != null) {
      try {
        final data = await client
            .from('cart_items')
            .select('id, quantity, unit_price, stones(*)')
            .eq('user_id', userId)
            .order('created_at');
        final items = <CartItem>[];
        for (final row in data) {
          final stoneJson = row['stones'];
          if (stoneJson == null) continue; // stone since deleted
          items.add(CartItem(
            stone: Stone.fromMap(Map<String, dynamic>.from(stoneJson)),
            quantity: (row['quantity'] as num).toInt(),
          ));
        }
        state = items;
        // Local cache is stale — replace with server truth.
        await _persistLocal();
        return;
      } catch (_) {
        // Network/RLS error — fall through to local cache so the
        // user still sees their items this session.
      }
    }
    final cached = _safeCachedCart();
    final items = <CartItem>[];
    for (final entry in cached) {
      final stoneJson = entry['stone'] as Map<String, dynamic>?;
      if (stoneJson == null) continue;
      items.add(CartItem(
        stone: Stone.fromMap(stoneJson),
        quantity: (entry['quantity'] as num?)?.toInt() ?? 1,
      ));
    }
    state = items;
  }

  /// Local cache read that treats an uninitialized store (tests, or a
  /// rare init failure) as simply "no saved cart" instead of crashing.
  List<Map<String, dynamic>> _safeCachedCart() {
    try {
      return _storage.getCart();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persistLocal() async {
    try {
      await _storage.saveCart([
        for (final item in state)
          {
            'stone': item.stone.toMap(),
            'quantity': item.quantity,
          },
      ]);
    } catch (_) {
      // Cache write is best-effort — never break a cart action on it.
    }
  }

  void addItem(Stone stone, {int quantity = 1}) {
    final existing = state.indexWhere((i) => i.stone.id == stone.id);
    final newQty = existing >= 0 ? state[existing].quantity + quantity : quantity;
    _mutate(
      change: () {
        if (existing >= 0) {
          state = [
            for (int i = 0; i < state.length; i++)
              if (i == existing)
                CartItem(stone: state[i].stone, quantity: newQty)
              else
                state[i]
          ];
        } else {
          state = [...state, CartItem(stone: stone, quantity: quantity)];
        }
      },
      persist: () async {
        final client = _clientOrNull;
        if (client != null && _userId != null) {
          await client.from('cart_items').upsert(
            {
              'user_id': _userId,
              'stone_id': stone.id,
              'quantity': newQty,
              'unit_price': stone.pricePerSqFt,
            },
            onConflict: 'user_id,stone_id',
          );
        }
        await _persistLocal();
      },
    );
  }

  void updateQuantity(int index, int delta) {
    if (index < 0 || index >= state.length) return;
    final item = state[index];
    final newQty = item.quantity + delta;
    if (newQty <= 0) {
      removeItem(index);
      return;
    }
    _mutate(
      change: () {
        state = [
          for (int i = 0; i < state.length; i++)
            if (i == index)
              CartItem(stone: state[i].stone, quantity: newQty)
            else
              state[i]
        ];
      },
      persist: () async {
        final client = _clientOrNull;
        if (client != null && _userId != null) {
          await client
              .from('cart_items')
              .update({'quantity': newQty})
              .eq('user_id', _userId!)
              .eq('stone_id', item.stone.id);
        }
        await _persistLocal();
      },
    );
  }

  void removeItem(int index) {
    if (index < 0 || index >= state.length) return;
    final removed = state[index];
    _mutate(
      change: () {
        state = [...state]..removeAt(index);
      },
      persist: () async {
        final client = _clientOrNull;
        if (client != null && _userId != null) {
          await client
              .from('cart_items')
              .delete()
              .eq('user_id', _userId!)
              .eq('stone_id', removed.stone.id);
        }
        await _persistLocal();
      },
    );
  }

  void clear() {
    _mutate(
      change: () => state = [],
      persist: () async {
        final client = _clientOrNull;
        if (client != null && _userId != null) {
          await client
              .from('cart_items')
              .delete()
              .eq('user_id', _userId!);
        }
        await _storage.clearCart().catchError((_) {});
      },
    );
  }

  /// Applies the UI change immediately, then persists. Persistence is
  /// best-effort: if Supabase is unreachable the local cache still
  /// holds the change (and vice versa), so we log instead of rolling
  /// back — the user already saw the update happen.
  void _mutate({
    required void Function() change,
    required Future<void> Function() persist,
  }) {
    change();
    unawaited(persist().catchError((Object e) {
      debugPrint('⚠️ [Cart] persistence failed (state kept): $e');
    }));
  }

  /// Reload from backend (e.g. after auth state changes).
  Future<void> refresh() => _restore();
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (_) => CartNotifier(),
);

// ─── Screen ───────────────────────────────────────────────
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  void _confirmClearCart(BuildContext context, WidgetRef ref, LuxuryPalette palette) {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Clear Cart?',
          style: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to remove all stone slabs from your project cart?',
          style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: palette.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(cartProvider.notifier).clear();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(
              'Clear All',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;
    final items = ref.watch(cartProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    double subtotal = items.fold(0, (s, i) => s + i.total);
    double gst = subtotal * 0.18;
    double shipping = subtotal > 10000 ? 0 : 500;
    double total = subtotal + gst + shipping;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Centered Responsive Scroll Area
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    backgroundColor: palette.background,
                    pinned: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    automaticallyImplyLeading: false,
                    leading: Navigator.of(context).canPop()
                        ? IconButton(
                            icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 20),
                            onPressed: () => Navigator.of(context).pop(),
                          )
                        : null,
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
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [palette.primary, palette.primary.withValues(alpha: 0.85)],
                              ),
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
                          onPressed: () => _confirmClearCart(context, ref, palette),
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
                    // Stone Items
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => FadeInStagger(
                            index: i,
                            child: _CartCard(
                              item: items[i],
                              index: i,
                              palette: palette,
                              onRemove: () {
                                HapticFeedback.mediumImpact();
                                final removedItem = items[i];
                                ref.read(cartProvider.notifier).removeItem(i);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text('${removedItem.stone.name} removed from cart'),
                                    backgroundColor: palette.textPrimary,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      textColor: palette.primary,
                                      onPressed: () {
                                        ref.read(cartProvider.notifier).addItem(
                                          removedItem.stone,
                                          quantity: removedItem.quantity,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                              onUpdateQty: (delta) {
                                HapticFeedback.selectionClick();
                                ref.read(cartProvider.notifier).updateQuantity(i, delta);
                              },
                            ),
                          ),
                          childCount: items.length,
                        ),
                      ),
                    ),

                    // Price Details Summary Card
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
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
                              _PriceRow(
                                label: 'Shipping / Transit Insurance',
                                amount: shipping,
                                palette: palette,
                                highlight: shipping == 0,
                              ),
                              Divider(color: palette.border, height: 28),
                              _PriceRow(
                                label: 'Estimated Total',
                                amount: total,
                                palette: palette,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Free Shipping Progress Card
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      sliver: SliverToBoxAdapter(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: palette.primary.withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, color: palette.primary, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      subtotal >= 10000
                                          ? 'Complimentary Delivery & Insurance Unlocked!'
                                          : 'Free Delivery on orders above ₹10,000',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (subtotal / 10000).clamp(0.0, 1.0),
                                  backgroundColor: palette.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtotal < 10000
                                    ? 'Add ₹${(10000 - subtotal).toInt()} more to unlock complimentary white-glove transit'
                                    : 'Complimentary white-glove delivery & transit insurance applied ✓',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Trust Badges
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 240),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Expanded(child: _buildTrustBadge(Icons.verified_outlined, '100% Genuine', 'Quarry certified', palette)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildTrustBadge(Icons.security_outlined, 'Insured Transit', 'Zero-breakage cover', palette)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildTrustBadge(Icons.support_agent_outlined, 'Expert Architect', 'Dedicated support', palette)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Floating Glass Checkout Bar (Appears above GraziaBottomNav)
          if (items.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: (bottomPadding > 0 ? bottomPadding + 6 : 14) + 72,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B1917).withValues(alpha: 0.92)
                              : Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: palette.primary.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
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
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 1),
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
                            const Spacer(),
                            ApplePressable(
                              onTap: () {
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
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      palette.primary,
                                      palette.primary.withValues(alpha: 0.85),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: palette.primary.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Checkout',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrustBadge(IconData icon, String title, String subtitle, LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: palette.primary),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 9,
              color: palette.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 90, left: 24, right: 24, top: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ambient glowing gold shopping bag badge
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    palette.primary.withValues(alpha: 0.18),
                    palette.surfaceDark.withValues(alpha: 0.5),
                  ],
                ),
                border: Border.all(
                  color: palette.primary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.primary.withValues(alpha: 0.15),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(Icons.shopping_bag_outlined, size: 44, color: palette.primary),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Project Cart is Empty',
              style: GoogleFonts.playfairDisplay(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                'Explore our curated Italian marbles, granites, and rare onyx slabs to create a bespoke architectural estimate.',
                style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.45),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 28),
            ApplePressable(
              onTap: () {
                HapticFeedback.mediumImpact();
                context.go('/collections');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.primary,
                      palette.primary.withValues(alpha: 0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: palette.primary.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.grid_view_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Browse Curated Stones',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Quick Studio Shortcuts
            Text(
              'QUICK ARCHITECTURAL TOOLS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.textTertiary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _buildShortcutChip(
                  context,
                  icon: Icons.auto_awesome_rounded,
                  label: 'AI Studio',
                  onTap: () => context.go('/tools'),
                  palette: palette,
                ),
                _buildShortcutChip(
                  context,
                  icon: Icons.view_in_ar_rounded,
                  label: 'Live AR View',
                  onTap: () => context.push('/ar-view'),
                  palette: palette,
                ),
                _buildShortcutChip(
                  context,
                  icon: Icons.square_foot_rounded,
                  label: 'Wall Estimator',
                  onTap: () => context.push('/measure/tile-visualizer'),
                  palette: palette,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required LuxuryPalette palette,
  }) {
    return ApplePressable(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: palette.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: palette.textPrimary,
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SmartStoneImage(
              localAsset: item.stone.images.isNotEmpty ? item.stone.images.first : null,
              width: 86,
              height: 86,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ApplePressable(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.close_rounded, color: palette.textTertiary, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.stone.collection,
                      style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                    ),
                    if (item.stone.finish.isNotEmpty) ...[
                      Text(' • ', style: TextStyle(color: palette.textTertiary, fontSize: 10)),
                      Text(
                        item.stone.finish,
                        style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Apple-style tactile stepper
                    Container(
                      decoration: BoxDecoration(
                        color: palette.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          ApplePressable(
                            onTap: () => onUpdateQty(-1),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
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
                          ApplePressable(
                            onTap: () => onUpdateQty(1),
                            child: Padding(
                              padding: const EdgeInsets.all(7),
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
                            fontSize: 16,
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
