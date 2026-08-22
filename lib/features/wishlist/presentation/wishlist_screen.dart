import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
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
      const SnackBar(content: Text('Removed from wishlist'), behavior: SnackBarBehavior.floating),
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
      const SnackBar(content: Text('Removed selected items'), behavior: SnackBarBehavior.floating),
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
      const SnackBar(content: Text('Wishlist cleared'), behavior: SnackBarBehavior.floating),
    );
  }

  void _addToCart(Stone stone) {
    HapticFeedback.lightImpact();
    ref.read(cartRiverpodProvider.notifier).addItem(stone);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${stone.name} added to cart'), behavior: SnackBarBehavior.floating),
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
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Saved Specifications',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
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
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: palette.primary, fontWeight: FontWeight.w600),
                  ),
                );
              }
              return wishlist.isNotEmpty
                  ? TextButton(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = true;
                        });
                      },
                      child: Text(
                        'Select',
                        style: GoogleFonts.inter(color: palette.primary, fontWeight: FontWeight.w600),
                      ),
                    )
                  : const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: wishlistAsync.when(
        loading: () => Center(child: CircularProgressIndicator(color: palette.primary)),
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
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.favorite_border_rounded, size: 40, color: palette.textTertiary),
          ),
          const SizedBox(height: 20),
          Text(
            'Your Wishlist is Empty',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark luxury slabs from our catalog\nto review for your project specification.',
            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/collections'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              'Browse Collections',
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
            ),
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
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      for (final stone in wishlist) {
                        ref.read(cartRiverpodProvider.notifier).addItem(stone);
                      }
                      final repo = ref.read(stoneRepositoryProvider);
                      for (final s in wishlist) {
                        repo.removeFromWishlist(s.id);
                      }
                      ref.invalidate(wishlistProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${wishlist.length} item${wishlist.length > 1 ? 's' : ''} moved to cart'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: Icon(Icons.add_shopping_cart, size: 16, color: palette.primary),
                    label: Text(
                      'Move All to Cart',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: palette.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: palette.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _clearAll,
                  icon: Icon(Icons.delete_outline, size: 16, color: palette.textTertiary),
                  label: Text(
                    'Clear All',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textTertiary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
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
          Text(
            '${_selectedIds.length} selected',
            style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
          ),
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
        decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
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
              width: isSelected ? 1.5 : 1,
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
                  width: 80,
                  height: 80,
                  child: SmartStoneImage(
                    localAsset: stone.images.isNotEmpty ? stone.images.first : null,
                    imageUrl: stone.imageUrl,
                    width: 80,
                    height: 80,
                    palette: palette,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone.name,
                      style: GoogleFonts.playfairDisplay(
                        color: palette.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stone.collection,
                      style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: palette.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          stone.rating.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '• ${stone.category}',
                          style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${stone.pricePerSqFt.toInt()}',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),
                  Text(
                    '/sqft',
                    style: GoogleFonts.inter(fontSize: 10, color: palette.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  if (!_isSelectionMode)
                    GestureDetector(
                      onTap: () => _addToCart(stone),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: palette.surfaceDark,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: palette.border),
                        ),
                        child: Icon(Icons.add_shopping_cart, color: palette.primary, size: 16),
                      ),
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
        left: 18,
        right: 18,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _removeSelected,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(
                'Remove (${_selectedIds.length})',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
