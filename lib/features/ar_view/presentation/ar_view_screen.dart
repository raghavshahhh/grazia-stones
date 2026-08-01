import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';

class ARViewScreen extends StatefulWidget {
  const ARViewScreen({super.key});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  bool _isARActive = false;
  String? _selectedStone;
  double _scale = 1.0;
  double _rotation = 0.0;

  final List<Map<String, String>> _stones = const [
    {'name': 'Charcoal Black', 'color': '#1C1C1E'},
    {'name': 'Graphite Grey', 'color': '#48484A'},
    {'name': 'Walnut Brown', 'color': '#5C3D2E'},
    {'name': 'Matte White', 'color': '#E5E5EA'},
    {'name': 'Brushed Silver', 'color': '#AEAEB2'},
    {'name': 'Accent Gold', 'color': '#C9A84C'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── AR Camera View (placeholder) ──
          if (_isARActive)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.view_in_ar_outlined,
                      size: 80,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AR Camera Active',
                      style: GraziaTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Point your camera at a flat surface\nto place the stone',
                      textAlign: TextAlign.center,
                      style: GraziaTextStyles.bodyMedium.copyWith(
                        color: AppColors.silver,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Stone preview overlay
                    if (_selectedStone != null)
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Color(
                            int.parse(
                              _stones
                                  .firstWhere((s) => s['name'] == _selectedStone)['color']!
                                  .replaceFirst('#', '0xFF'),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gold, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Transform.scale(
                          scale: _scale,
                          child: Transform.rotate(
                            angle: _rotation,
                            child: const Icon(
                              Icons.texture,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            // Camera permission state
            Container(
              color: AppColors.charcoal,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        size: 48,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Enable Camera for AR',
                      style: GraziaTextStyles.headlineSmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'Grant camera access to visualize stones in your real space using augmented reality.',
                        textAlign: TextAlign.center,
                        style: GraziaTextStyles.bodyMedium.copyWith(
                          color: AppColors.silver,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    GraziaButton(
                      label: 'Enable Camera',
                      icon: Icons.camera_alt,
                      onPressed: () {
                        setState(() => _isARActive = true);
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ── Top controls ──
          if (_isARActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Close
                  _CircleButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  // AR indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.gold),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AR Active',
                          style: GraziaTextStyles.bodySmall.copyWith(
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Capture
                  _CircleButton(
                    icon: Icons.camera,
                    onTap: () {
                      // TODO: Capture screenshot
                    },
                  ),
                ],
              ),
            ),

          // ── Bottom controls ──
          if (_isARActive)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // Scale slider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Row(
                      children: [
                        const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                        Expanded(
                          child: Slider(
                            value: _scale,
                            min: 0.5,
                            max: 3.0,
                            activeColor: AppColors.gold,
                            inactiveColor: AppColors.slate,
                            onChanged: (v) => setState(() => _scale = v),
                          ),
                        ),
                        const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Stone strip
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _stones.length,
                      itemBuilder: (context, index) {
                        final stone = _stones[index];
                        final isSelected = _selectedStone == stone['name'];
                        final color = Color(
                          int.parse(
                            stone['color']!.replaceFirst('#', '0xFF'),
                          ),
                        );
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedStone = stone['name']),
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.gold
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Instructions
                  Text(
                    _selectedStone == null
                        ? 'Select a stone from the strip below'
                        : 'Tap on a surface to place ${_selectedStone}',
                    style: GraziaTextStyles.bodySmall.copyWith(
                      color: AppColors.silver,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
