import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';

class ARViewScreen extends StatefulWidget {
  const ARViewScreen({super.key});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  String? _selectedStoneId;
  bool _isARActive = false;

  void _startAR() {
    if (_selectedStoneId == null) return;
    setState(() => _isARActive = true);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final stones = MockDataService.getAllStones().take(6).toList();
    final selectedStone = _selectedStoneId != null
        ? stones.firstWhere((s) => s.id == _selectedStoneId)
        : null;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // Camera placeholder
          if (_isARActive)
            Container(
              color: Colors.black,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.view_in_ar, size: 100, color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 20),
                    Text(
                      'AR Camera View',
                      style: GLuxuryTypography.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Point camera at wall to place stone',
                      style: GLuxuryTypography.bodyMedium.copyWith(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [palette.background, palette.surfaceDark],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.view_in_ar_outlined, size: 80, color: palette.primary),
                    const SizedBox(height: 20),
                    Text(
                      'AR View Ready',
                      style: GLuxuryTypography.h1.copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Select a stone and tap Start AR',
                      style: GLuxuryTypography.bodyLarge.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          
          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: 8,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                  const Spacer(),
                  if (selectedStone != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        selectedStone.name,
                        style: GLuxuryTypography.bodyMedium.copyWith(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Stone selector at bottom
          if (!_isARActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Stone',
                      style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: stones.length,
                        itemBuilder: (context, i) {
                          final stone = stones[i];
                          final isSelected = _selectedStoneId == stone.id;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedStoneId = stone.id);
                              HapticFeedback.selectionClick();
                            },
                            child: Container(
                              width: 100,
                              margin: EdgeInsets.only(right: i < stones.length - 1 ? 12 : 0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? palette.primary : palette.border,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  stone.imageUrl ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: palette.surfaceDark,
                                    child: Icon(Icons.image, color: palette.textTertiary),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _selectedStoneId != null ? _startAR : null,
                        icon: const Icon(Icons.view_in_ar),
                        label: const Text('Start AR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.background,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          disabledBackgroundColor: palette.surfaceDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // AR controls
          if (_isARActive)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildARControl(Icons.camera_alt, 'Capture', () {}),
                    _buildARControl(Icons.close, 'Exit', () => setState(() => _isARActive = false)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildARControl(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GLuxuryTypography.labelSmall.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
