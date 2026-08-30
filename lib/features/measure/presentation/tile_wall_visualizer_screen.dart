import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Deterministic, proportional wall visualizer — NOT the AI/generative
/// pipeline. Given a real wall width/height and a real backend product,
/// this renders the wall at its true aspect ratio, tiles it with the
/// product's actual texture at its actual tile dimensions, and computes
/// box quantity from the product's real coverage data. No invented
/// packaging numbers, no fixed decorative geometry.
class TileWallVisualizerScreen extends ConsumerStatefulWidget {
  const TileWallVisualizerScreen({super.key});

  @override
  ConsumerState<TileWallVisualizerScreen> createState() => _TileWallVisualizerScreenState();
}

class _TileWallVisualizerScreenState extends ConsumerState<TileWallVisualizerScreen> {
  final _widthController = TextEditingController(text: '10');
  final _heightController = TextEditingController(text: '10');
  String _unit = 'ft';
  double _wastagePercent = 10;
  Stone? _selectedStone;
  final TransformationController _viewerController = TransformationController();

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _viewerController.dispose();
    super.dispose();
  }

  double? get _widthValue => double.tryParse(_widthController.text);
  double? get _heightValue => double.tryParse(_heightController.text);

  /// Converts the entered wall dimension to feet — all downstream tile
  /// math (which uses cm-based product dimensions) is normalized to feet
  /// via a shared conversion so proportions never drift by unit.
  double _toFeet(double value) {
    switch (_unit) {
      case 'in':
        return value / 12;
      case 'm':
        return value * 3.28084;
      case 'cm':
        return value * 0.0328084;
      default:
        return value;
    }
  }

  void _resetView() {
    _viewerController.value = Matrix4.identity();
    HapticFeedback.selectionClick();
  }

  void _fitView() => _resetView();

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final stonesAsync = ref.watch(allStonesProvider);

    final widthFt = _widthValue != null ? _toFeet(_widthValue!) : null;
    final heightFt = _heightValue != null ? _toFeet(_heightValue!) : null;
    final validDimensions = widthFt != null && heightFt != null && widthFt > 0 && heightFt > 0;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text('Tile Visualizer', style: TextStyle(color: palette.textPrimary)),
        actions: [
          IconButton(icon: const Icon(Icons.center_focus_strong), tooltip: 'Fit', onPressed: _fitView),
          IconButton(icon: const Icon(Icons.restart_alt), tooltip: 'Reset', onPressed: _resetView),
        ],
      ),
      body: Column(
        children: [
          _DimensionInputs(
            widthController: _widthController,
            heightController: _heightController,
            unit: _unit,
            wastagePercent: _wastagePercent,
            onUnitChanged: (u) => setState(() => _unit = u),
            onWastageChanged: (w) => setState(() => _wastagePercent = w),
            onChanged: () => setState(() {}),
          ),
          Expanded(
            child: !validDimensions
                ? Center(
                    child: Text(
                      'Enter a valid width and height to visualize the wall.',
                      style: TextStyle(color: palette.textSecondary),
                    ),
                  )
                : InteractiveViewer(
                    transformationController: _viewerController,
                    minScale: 0.5,
                    maxScale: 6,
                    child: Center(
                      child: _WallCanvas(
                        wallWidthFt: widthFt,
                        wallHeightFt: heightFt,
                        stone: _selectedStone,
                        onTapTile: _selectedStone == null
                            ? null
                            : () => _showTileDetail(context, _selectedStone!, widthFt, heightFt, _wastagePercent),
                      ),
                    ),
                  ),
          ),
          if (validDimensions)
            _QuantitySummary(
              widthFt: widthFt,
              heightFt: heightFt,
              stone: _selectedStone,
              wastagePercent: _wastagePercent,
            ),
          stonesAsync.when(
            data: (stones) => _ProductStrip(
              stones: stones,
              selected: _selectedStone,
              onSelect: (s) => setState(() => _selectedStone = s),
            ),
            loading: () => const SizedBox(height: 96, child: Center(child: CircularProgressIndicator())),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _showTileDetail(BuildContext context, Stone stone, double wallWidthFt, double wallHeightFt, double wastage) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TileDetailSheet(stone: stone),
    );
  }
}

class _DimensionInputs extends StatelessWidget {
  final TextEditingController widthController;
  final TextEditingController heightController;
  final String unit;
  final double wastagePercent;
  final ValueChanged<String> onUnitChanged;
  final ValueChanged<double> onWastageChanged;
  final VoidCallback onChanged;

  const _DimensionInputs({
    required this.widthController,
    required this.heightController,
    required this.unit,
    required this.wastagePercent,
    required this.onUnitChanged,
    required this.onWastageChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widthController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Width', isDense: true, border: OutlineInputBorder()),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: heightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Height', isDense: true, border: OutlineInputBorder()),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: unit,
            items: const ['ft', 'in', 'm', 'cm']
                .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                .toList(),
            onChanged: (u) {
              if (u != null) onUnitChanged(u);
            },
          ),
        ],
      ),
    );
  }
}

/// Renders the wall at its true proportion (never distorted by the
/// viewport) tiled with the product's actual texture at actual tile size.
class _WallCanvas extends StatelessWidget {
  final double wallWidthFt;
  final double wallHeightFt;
  final Stone? stone;
  final VoidCallback? onTapTile;

  const _WallCanvas({
    required this.wallWidthFt,
    required this.wallHeightFt,
    required this.stone,
    required this.onTapTile,
  });

  @override
  Widget build(BuildContext context) {
    // Proportion is fixed by the real aspect ratio — the viewport (and
    // InteractiveViewer's zoom) only scales the whole thing uniformly,
    // never stretches width independently of height.
    const maxRenderSize = 360.0;
    final aspect = wallWidthFt / wallHeightFt;
    final renderWidth = aspect >= 1 ? maxRenderSize : maxRenderSize * aspect;
    final renderHeight = aspect >= 1 ? maxRenderSize / aspect : maxRenderSize;

    return GestureDetector(
      onTap: onTapTile,
      child: Container(
        width: renderWidth,
        height: renderHeight,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black26, width: 2),
          color: Colors.grey.shade300,
        ),
        child: stone == null
            ? const Center(child: Text('Select a product below'))
            : ClipRect(
                child: _TiledTexture(
                  imageUrl: stone!.arTextureUrl,
                  wallWidthFt: wallWidthFt,
                  wallHeightFt: wallHeightFt,
                  // Tile dimensions come from the real product record
                  // (length_cm x width_cm), converted to feet — falls
                  // back to a single full-bleed tile only if the product
                  // has no dimension data at all.
                  tileWidthFt: (stone!.lengthCm ?? 0) > 0 ? stone!.lengthCm! / 30.48 : wallWidthFt,
                  tileHeightFt: (stone!.widthCm ?? 0) > 0 ? stone!.widthCm! / 30.48 : wallHeightFt,
                ),
              ),
      ),
    );
  }
}

class _TiledTexture extends StatelessWidget {
  final String? imageUrl;
  final double wallWidthFt;
  final double wallHeightFt;
  final double tileWidthFt;
  final double tileHeightFt;

  const _TiledTexture({
    required this.imageUrl,
    required this.wallWidthFt,
    required this.wallHeightFt,
    required this.tileWidthFt,
    required this.tileHeightFt,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return Container(color: Colors.grey.shade400);

    final columns = (wallWidthFt / tileWidthFt).ceil().clamp(1, 200);
    final rows = (wallHeightFt / tileHeightFt).ceil().clamp(1, 200);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / columns;
        final cellH = constraints.maxHeight / rows;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: cellW / cellH,
          ),
          itemCount: columns * rows,
          itemBuilder: (context, i) => Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black12, width: 0.5), // grout line
              image: DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }
}

class _QuantitySummary extends StatelessWidget {
  final double widthFt;
  final double heightFt;
  final Stone? stone;
  final double wastagePercent;

  const _QuantitySummary({
    required this.widthFt,
    required this.heightFt,
    required this.stone,
    required this.wastagePercent,
  });

  @override
  Widget build(BuildContext context) {
    final area = widthFt * heightFt;
    final withWastage = area * (1 + wastagePercent / 100);

    String boxesLabel = 'Select a product';
    if (stone != null) {
      boxesLabel = stone!.sqftPerBox > 0
          ? '${(withWastage / stone!.sqftPerBox).ceil()} boxes'
          : 'Packaging data unavailable';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          Text('Area: ${area.toStringAsFixed(1)} sqft'),
          Text('With ${wastagePercent.toInt()}% wastage: ${withWastage.toStringAsFixed(1)} sqft'),
          Text(boxesLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ProductStrip extends StatelessWidget {
  final List<Stone> stones;
  final Stone? selected;
  final ValueChanged<Stone> onSelect;

  const _ProductStrip({required this.stones, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: stones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = stones[i];
          final isSelected = s.id == selected?.id;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelect(s);
            },
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isSelected ? Colors.amber : Colors.black12, width: isSelected ? 2 : 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: SmartStoneImage(imageUrl: s.imageUrl, fit: BoxFit.cover),
            ),
          );
        },
      ),
    );
  }
}

class _TileDetailSheet extends StatelessWidget {
  final Stone stone;
  const _TileDetailSheet({required this.stone});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stone.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('SKU: ${stone.productCode.isNotEmpty ? stone.productCode : 'N/A'}'),
            const Divider(height: 24),
            _detailRow('Finish', stone.finish),
            _detailRow('Colour', stone.availableColors.isNotEmpty ? stone.availableColors.first : 'N/A'),
            _detailRow('Dimensions', stone.size.isNotEmpty ? stone.size : 'N/A'),
            _detailRow('Thickness', stone.thickness.isNotEmpty ? stone.thickness : 'N/A'),
            _detailRow(
              'Coverage / box',
              stone.sqftPerBox > 0 ? '${stone.sqftPerBox.toStringAsFixed(1)} sqft' : 'Packaging data unavailable',
            ),
            _detailRow(
              'Pieces / box',
              stone.piecesPerBox > 0 ? '${stone.piecesPerBox}' : 'Packaging data unavailable',
            ),
            _detailRow('Price', '₹${stone.pricePerSqFt.toStringAsFixed(0)} / sqft'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
