import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class AdminProductsScreen extends ConsumerStatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Stone> _stones = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStones();
  }

  Future<void> _loadStones() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Admin CMS listing: includes archived (active=false) products so
      // they can be reviewed, restored, or permanently deleted. Public
      // catalogue visibility is untouched — RLS still hides archived
      // rows from normal users.
      final adminRepo = ref.read(adminProductRepositoryProvider);
      final stones = await adminRepo.getAllProductsAdmin();

      if (mounted) {
        setState(() {
          _stones = stones;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteStone(String stoneId, {bool permanent = false}) async {
    try {
      final adminRepo = ref.read(adminProductRepositoryProvider);
      
      if (permanent) {
        await adminRepo.permanentlyDeleteProduct(stoneId);
      } else {
        await adminRepo.deleteProduct(stoneId);
      }

      if (mounted) {
        showSuccessSnackbar(context, permanent ? 'Stone permanently deleted' : 'Stone marked as inactive');
        _loadStones();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
      }
    }
  }

  void _showDeleteDialog(Stone stone, LuxuryPalette palette) {
    // Archived products get a restore path — soft delete was a one-way
    // trap before (archived rows vanished from the CMS with no way back).
    if (!stone.isActive) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text('Archived Stone', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary)),
          content: Text('"${stone.name}" is hidden from the catalogue. Restore it to make it live again, or delete it permanently.',
              style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: palette.primary, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await ref.read(adminProductRepositoryProvider).restoreProduct(stone.id);
                  if (mounted) {
                    showSuccessSnackbar(context, '${stone.name} restored to the catalogue');
                    _loadStones();
                  }
                } catch (e) {
                  if (mounted) showErrorSnackbar(context, e);
                }
              },
              child: const Text('Restore'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
              onPressed: () {
                Navigator.pop(ctx);
                _deleteStone(stone.id, permanent: true);
              },
              child: const Text('Delete Forever'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Delete Stone', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How do you want to delete "${stone.name}"?',
                style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Text('• Soft Delete: Hide from catalog (can be restored later)',
                style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11)),
            const SizedBox(height: 4),
            Text('• Permanent Delete: Remove from database forever',
                style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteStone(stone.id, permanent: false);
            },
            child: Text('Soft Delete', style: TextStyle(color: palette.primary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteStone(stone.id, permanent: true);
            },
            child: const Text('Permanent'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final filteredStones = _stones.where((s) {
      if (_searchQuery.isEmpty) return true;
      return s.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.collection.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

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
          'Manage Products (${_stones.length})',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadStones)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      child: TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search stones by name or collection...',
                          hintStyle: GoogleFonts.inter(fontSize: 13, color: palette.textTertiary),
                          prefixIcon: Icon(Icons.search, color: palette.primary, size: 20),
                          filled: true,
                          fillColor: palette.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: palette.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child: RefreshIndicator(
                        color: palette.primary,
                        backgroundColor: palette.surface,
                        onRefresh: _loadStones,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          itemCount: filteredStones.length,
                          itemBuilder: (context, i) {
                            final stone = filteredStones[i];
                            return _buildProductTile(palette, stone);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/admin/products/add');
          if (result == true) {
            _loadStones();
          }
        },
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('Add New Stone', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildProductTile(LuxuryPalette palette, Stone stone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: SmartStoneImage(
                localAsset: stone.images.isNotEmpty ? stone.images.first : null,
                imageUrl: stone.imageUrl,
                width: 64,
                height: 64,
                palette: palette,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stone.name,
                          style: GoogleFonts.playfairDisplay(
                            color: stone.isActive
                                ? palette.textPrimary
                                : palette.textTertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!stone.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade700.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade700.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'ARCHIVED',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.orange.shade700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 2),
                Text(
                  '${stone.collection} • ${stone.category}',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${stone.pricePerSqFt.toInt()}/sqft • ${stone.finish}',
                  style: GoogleFonts.inter(color: palette.primary, fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: palette.primary, size: 18),
            onPressed: () async {
              final result = await context.push('/admin/products/edit/${stone.id}', extra: stone);
              if (result == true) {
                _loadStones();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => _showDeleteDialog(stone, palette),
          ),
        ],
      ),
    );
  }
}
