import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/features/cart/presentation/cart_screen.dart';

class StoneDetailScreen extends ConsumerStatefulWidget {
  final String stoneId;

  const StoneDetailScreen({super.key, required this.stoneId});

  @override
  ConsumerState<StoneDetailScreen> createState() => _StoneDetailScreenState();
}

class _StoneDetailScreenState extends ConsumerState<StoneDetailScreen> {
  int _currentImageIndex = 0;
  bool _isWishlisted = false;
  
  // Area Estimator State
  double _areaSqFt = 150.0;
  double _wastagePercent = 0.10; // 10% recommended

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final stoneAsync = ref.watch(stoneByIdProvider(widget.stoneId));

    return stoneAsync.when(
      loading: () => Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          elevation: 0,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          ),
        ),
        body: Center(child: CircularProgressIndicator(color: palette.primary)),
      ),
      error: (e, _) => _buildNotFound(palette),
      data: (stone) {
        if (stone == null) {
          return _buildNotFound(palette);
        }
        return _buildStoneDetail(palette, stone);
      },
    );
  }

  Widget _buildNotFound(LuxuryPalette palette) {
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/collections');
            }
          },
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Stone Details',
          style: GoogleFonts.playfairDisplay(fontSize: 18, fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.border),
                  ),
                  child: Icon(Icons.search_off_rounded, color: palette.textTertiary, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  'Stone Not Found',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The specific stone surface requested is unavailable or has been re-indexed in our active quarry catalogue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go('/collections'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Browse Collection', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.textPrimary,
                      side: BorderSide(color: palette.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Back to Home', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoneDetail(LuxuryPalette palette, Stone stone) {
    final images = stone.images.isNotEmpty ? stone.images : [stone.imageUrl ?? ''];

    // Calculation values
    final totalAreaWithWastage = _areaSqFt * (1 + _wastagePercent);
    final slabSizeSqFt = (stone.sqftPerBox > 0) ? stone.sqftPerBox : 45.0;
    final slabsNeeded = (totalAreaWithWastage / slabSizeSqFt).ceil();
    final totalEstimatedCost = totalAreaWithWastage * stone.pricePerSqFt;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 1. Top Image Viewer
              SliverAppBar(
                expandedHeight: 380,
                pinned: true,
                backgroundColor: palette.background,
                elevation: 0,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: palette.surface.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: palette.textPrimary),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      setState(() => _isWishlisted = !_isWishlisted);
                    },
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(
                        _isWishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 18,
                        color: _isWishlisted ? palette.primary : palette.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImageIndex = i),
                        itemBuilder: (context, i) {
                          return SmartStoneImage(
                            imageUrl: images[i],
                            fit: BoxFit.cover,
                            palette: palette,
                          );
                        },
                      ),
                      // Gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                palette.background,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Page indicator dots
                      if (images.length > 1)
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              images.length,
                              (i) => Container(
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: i == _currentImageIndex ? 20 : 6,
                                height: 5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  gradient: i == _currentImageIndex ? palette.primaryGradient : null,
                                  color: i == _currentImageIndex
                                      ? null
                                      : palette.textTertiary.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // 2. Main Content
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Collection Badge & In Stock
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stone.collection.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2,
                                color: palette.primary,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (stone.inStock)
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2E7D32),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'In Stock (Certified Quarry)',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Stone Name
                      Text(
                        stone.name,
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            '₹${stone.pricePerSqFt.toInt()}',
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '/ sq ft',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: palette.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          if (stone.rating > 0)
                            Row(
                              children: [
                                Icon(Icons.star_rounded, color: palette.primary, size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  stone.rating.toStringAsFixed(1),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 3. Dual Visualizer CTA Bar
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => context.push('/live-ai?stoneId=${stone.id}'),
                              icon: const Icon(Icons.view_in_ar_outlined, size: 18),
                              label: const Text('Live AR View'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: palette.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => context.push('/ai-viz?stoneId=${stone.id}'),
                              icon: Icon(Icons.auto_awesome_outlined, color: palette.primary, size: 18),
                              label: Text(
                                'AI Room Studio',
                                style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w600),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: palette.border, width: 1.2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 4. Architectural Specifications Grid
                      Text(
                        'ARCHITECTURAL SPECIFICATIONS',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: palette.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 2.2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildSpecTile(palette, 'Finish', stone.finish.isEmpty ? 'Polished' : stone.finish),
                          _buildSpecTile(palette, 'Thickness', stone.thickness.isEmpty ? '20 mm' : stone.thickness),
                          _buildSpecTile(palette, 'Slab Size', stone.size.isEmpty ? '120" x 75" (Jumbo)' : stone.size),
                          _buildSpecTile(palette, 'Origin', (stone.origin != null && stone.origin!.isNotEmpty) ? stone.origin! : 'Italy / Carrara'),
                          _buildSpecTile(palette, 'Texture', stone.texture.isEmpty ? 'Fine Veined' : stone.texture),
                          _buildSpecTile(palette, 'Absorption', '< 0.15% (Waterproof)'),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // 5. Area & Cost Estimator Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calculate_outlined, color: palette.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Area & Material Estimator',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Surface Area Required (sq ft)',
                              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                            ),
                            const SizedBox(height: 8),
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: palette.primary,
                                inactiveTrackColor: palette.border,
                                thumbColor: palette.primary,
                                overlayColor: palette.primary.withValues(alpha: 0.1),
                              ),
                              child: Slider(
                                value: _areaSqFt,
                                min: 20,
                                max: 1000,
                                divisions: 98,
                                label: '${_areaSqFt.toInt()} sq ft',
                                onChanged: (v) => setState(() => _areaSqFt = v),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${_areaSqFt.toInt()} sq ft', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary)),
                                Text('Wastage buffer:', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [5, 10, 15].map((percent) {
                                final isSelected = (_wastagePercent * 100).toInt() == percent;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text('$percent% ${percent == 10 ? '(Rec.)' : ''}'),
                                    selected: isSelected,
                                    onSelected: (_) => setState(() => _wastagePercent = percent / 100.0),
                                    selectedColor: palette.primary.withValues(alpha: 0.15),
                                    labelStyle: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected ? palette.primary : palette.textSecondary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const Divider(height: 28),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total Area (incl. buffer):', style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary)),
                                Text('${totalAreaWithWastage.toInt()} sq ft', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Estimated Slabs Needed:', style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary)),
                                Text('$slabsNeeded slabs', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Est. Material Cost:', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary)),
                                Text(
                                  '₹${totalEstimatedCost.toInt()}',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: palette.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Description
                      Text(
                        'ABOUT THIS SURFACE',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.8,
                          color: palette.textTertiary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        stone.description.isEmpty
                            ? 'A masterclass in natural stone aesthetics. Sourced from premier quarries with bookmatched slab availability for dramatic architectural statements.'
                            : stone.description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // 6. Sticky Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: MediaQuery.of(context).padding.bottom + 14,
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
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => context.push('/sample-order?stoneId=${stone.id}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.textPrimary,
                        side: BorderSide(color: palette.border, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        'Order Sample',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        ref.read(cartProvider.notifier).addItem(stone);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${stone.name} added to cart', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            backgroundColor: palette.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.only(bottom: 90, left: 24, right: 24),
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: 'Checkout →',
                              textColor: const Color(0xFFD4AF37),
                              onPressed: () => context.push('/checkout'),
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add to Project / Quote',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecTile(LuxuryPalette palette, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: palette.textTertiary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
