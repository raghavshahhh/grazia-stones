import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Wishlist items provider — fetches from Supabase
final wishlistProvider = FutureProvider.autoDispose<List<Stone>>((ref) async {
  final repo = ref.watch(stoneRepositoryProvider);
  return repo.getWishlist();
});

class WishlistScreen extends ConsumerStatefulWidget {
  const WishlistScreen({super.key});

  @override
  ConsumerState<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends ConsumerState<WishlistScreen> {
  Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  void _removeItem(String id) {
    HapticFeedback.mediumImpact();
    ref.read(stoneRepositoryProvider).removeFromWishlist(id);
    ref.invalidate(wishlistProvider);
    _selectedIds.remove(id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from wishlist'), backgroundColor: Colors.red),
    );
  }

  void _removeSelected() {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.mediumImpact();
    final repo = ref.read(stoneRepositoryProvider);
    for (final id in _selectedIds) {
      repo.removeFromWishlist(id);
    }
    _selectedIds.clear();
    _isSelectionMode = false;
    ref.invalidate(wishlistProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed selected items'), backgroundColor: Colors.red),
    );
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _clearAll() {
    HapticFeedback.mediumImpact();
    ref.invalidate(wishlistProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Wishlist cleared')),
    );
  }

  void _addToCart(Stone stone) {
    HapticFeedback.lightImpact();
    ref.read(cartRiverpodProvider.notifier).addItem(stone);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${stone.name} added to cart')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final wishlistAsync = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
        ),
        title: Text(
          'Wishlist',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
        actions: [
          wishlistAsync.when(
            data: (wishlist) {
              if (_isSelectionMode) {
                return TextButton(
                  onPressed: () {
                    setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                  child: Text('Cancel', style: GLuxuryTypography.labelMedium.copyWith(color: palette.primary)),
                );
              }
              return wishlist.isNotEmpty
                  ? TextButton(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      },
                      child: Text('Select', style: GLuxuryTypography.labelMedium.copyWith(color: palette.primary)),
                    )
                  : const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: wishlistAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: palette.error))),
        data: (wishlist) {
          if (wishlist.isEmpty) return _buildEmptyState(palette);
          return _buildWishlistContent(wishlist, palette);
        },
      ),
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? _buildBottomBar(palette)
          : null,
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: palette.textTertiary.withValues(alpha: 0.3)),
          GLuxurySpacing.gapBase,
          Text('Your wishlist is empty', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
          GLuxurySpacing.gapSm,
          Text('Add stones you love to your wishlist', style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary)),
          GLuxurySpacing.gapXl,
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.background,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: Text('Browse Stones', style: GLuxuryTypography.labelLarge),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistContent(List<Stone> wishlist, LuxuryPalette palette) {
    return Column(
      children: [
        if (_isSelectionMode)
          _buildSelectionHeader(wishlist, palette)
        else if (wishlist.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      for (final stone in wishlist) {
                        ref.read(cartRiverpodProvider.notifier).addItem(stone);
                      }
                      final repo = ref.read(stoneRepositoryProvider);
                      for (final s in wishlist) { repo.removeFromWishlist(s.id); }
                      ref.invalidate(wishlistProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${wishlist.length} item${wishlist.length > 1 ? 's' : ''} moved to cart')),
                      );
                    },
                    icon: Icon(Icons.add_shopping_cart, size: 16, color: palette.primary),
                    label: Text('Move All to Cart', style: GLuxuryTypography.labelMedium.copyWith(color: palette.primary)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: palette.primary.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  label: Text('Clear All', style: GLuxuryTypography.labelMedium.copyWith(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: wishlist.length,
            itemBuilder: (context, i) {
              final stone = wishlist[i];
              final isSelected = _selectedIds.contains(stone.id);
              return _buildWishlistCard(stone, isSelected, palette);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(List<Stone> wishlist, LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _selectedIds.length == wishlist.length && wishlist.isNotEmpty,
            onChanged: (_) {
              setState(() {
                if (_selectedIds.length == wishlist.length) {
                  _selectedIds.clear();
                } else {
                  _selectedIds = wishlist.map((s) => s.id).toSet();
                }
              });
            },
            activeColor: palette.primary,
          ),
          Text('${_selectedIds.length} selected', style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(Stone stone, bool isSelected, LuxuryPalette palette) {
    return Dismissible(
      key: Key(stone.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(stone.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      child: GestureDetector(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(stone.id);
          } else {
            context.push('/stones/${stone.id}');
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? palette.primary : palette.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(stone.id),
                  activeColor: palette.primary,
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 80, height: 80,
                  child: SmartStoneImage(imageUrl: stone.imageUrl, width: 80, height: 80, palette: palette),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stone.name, style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(stone.collection, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: palette.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(stone.rating.toString(), style: GLuxuryTypography.bodySmall.copyWith(color: palette.textPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('₹${stone.pricePerSqFt.toInt()}', style: GLuxuryTypography.h3.copyWith(color: palette.primary)),
                  const SizedBox(height: 8),
                  if (!_isSelectionMode)
                    IconButton(
                      onPressed: () => _addToCart(stone),
                      icon: Icon(Icons.add_shopping_cart, color: palette.primary, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(LuxuryPalette palette) {
    return Container(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _removeSelected,
              icon: const Icon(Icons.delete_outline),
              label: Text('Remove (${_selectedIds.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
