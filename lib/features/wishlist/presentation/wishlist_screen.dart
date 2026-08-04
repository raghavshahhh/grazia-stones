import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  // Mock wishlist (first 4 stones)
  List<Stone> _wishlist = [];
  Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _wishlist = MockDataService.getAllStones().take(4).toList();
  }

  void _removeItem(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _wishlist.removeWhere((s) => s.id == id);
      _selectedIds.remove(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Removed from wishlist'), backgroundColor: Colors.red),
    );
  }

  void _removeSelected() {
    if (_selectedIds.isEmpty) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _wishlist.removeWhere((s) => _selectedIds.contains(s.id));
      _selectedIds.clear();
      _isSelectionMode = false;
    });
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

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _wishlist.length) {
        _selectedIds.clear();
      } else {
        _selectedIds = _wishlist.map((s) => s.id).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

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
          if (_wishlist.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  _isSelectionMode = !_isSelectionMode;
                  if (!_isSelectionMode) _selectedIds.clear();
                });
              },
              child: Text(
                _isSelectionMode ? 'Cancel' : 'Select',
                style: GLuxuryTypography.labelMedium.copyWith(color: palette.primary),
              ),
            ),
        ],
      ),
      body: _wishlist.isEmpty ? _buildEmptyState(palette) : _buildWishlistContent(palette),
      bottomNavigationBar: _isSelectionMode && _selectedIds.isNotEmpty
          ? _buildBottomBar(palette)
          : null,
    );
  }

  Widget _buildEmptyState(GoldPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: palette.textTertiary.withValues(alpha: 0.3)),
          GLuxurySpacing.gapBase,
          Text(
            'Your wishlist is empty',
            style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
          ),
          GLuxurySpacing.gapSm,
          Text(
            'Add stones you love to your wishlist',
            style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
          ),
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

  Widget _buildWishlistContent(GoldPalette palette) {
    return Column(
      children: [
        if (_isSelectionMode) _buildSelectionHeader(palette),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _wishlist.length,
            itemBuilder: (context, i) {
              final stone = _wishlist[i];
              final isSelected = _selectedIds.contains(stone.id);
              return _buildWishlistCard(stone, isSelected, palette);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionHeader(GoldPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(bottom: BorderSide(color: palette.border)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: _selectedIds.length == _wishlist.length && _wishlist.isNotEmpty,
            onChanged: (_) => _selectAll(),
            activeColor: palette.primary,
          ),
          Text(
            '${_selectedIds.length} selected',
            style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildWishlistCard(Stone stone, bool isSelected, GoldPalette palette) {
    return Dismissible(
      key: Key(stone.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(stone.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
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
                child: Image.network(
                  stone.imageUrl ?? '',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: palette.surfaceDark,
                    child: Icon(Icons.image, color: palette.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stone.name,
                      style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stone.collection,
                      style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: palette.primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          stone.rating.toString(),
                          style: GLuxuryTypography.bodySmall.copyWith(color: palette.textPrimary),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            stone.finish,
                            style: GLuxuryTypography.labelSmall.copyWith(
                              color: palette.primary,
                              fontSize: 10,
                            ),
                          ),
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
                    style: GLuxuryTypography.h3.copyWith(color: palette.primary),
                  ),
                  Text(
                    '/sq ft',
                    style: GLuxuryTypography.labelSmall.copyWith(color: palette.textTertiary),
                  ),
                  const SizedBox(height: 8),
                  if (!_isSelectionMode)
                    IconButton(
                      onPressed: () => _removeItem(stone.id),
                      icon: Icon(Icons.close, color: palette.textTertiary, size: 20),
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

  Widget _buildBottomBar(GoldPalette palette) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
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
              label: Text('Remove Selected (${_selectedIds.length})'),
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
