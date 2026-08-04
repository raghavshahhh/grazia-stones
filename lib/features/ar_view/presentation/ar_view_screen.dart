import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';

class ARViewScreen extends StatefulWidget {
  const ARViewScreen({super.key});

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  bool _cameraGranted = false;
  bool _isARActive = false;
  bool _isDetecting = false;
  String? _selectedStone;
  double _scale = 1.0;
  Offset? _placedPosition;
  String _surfaceStatus = 'Point camera at a flat surface...';

  final List<Map<String, dynamic>> _stones = const [
    {'name': 'Charcoal Black', 'color': '#1C1C1E', 'texture': 'matte'},
    {'name': 'Graphite Grey', 'color': '#48484A', 'texture': 'polished'},
    {'name': 'Walnut Brown', 'color': '#5C3D2E', 'texture': 'natural'},
    {'name': 'Matte White', 'color': '#E5E5EA', 'texture': 'matte'},
    {'name': 'Brushed Silver', 'color': '#AEAEB2', 'texture': 'brushed'},
    {'name': 'Accent Gold', 'color': '#C9A84C', 'texture': 'polished'},
  ];

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() => _cameraGranted = status.isGranted);
  }

  void _startAR() {
    setState(() {
      _isARActive = true;
      _isDetecting = true;
      _surfaceStatus = 'Scanning for surfaces...';
    });
    // Simulate surface detection after a brief delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _isDetecting) {
        setState(() {
          _surfaceStatus = 'Surface detected — tap to place stone';
          _isDetecting = false;
        });
      }
    });
  }

  void _onTapToPlace(TapUpDetails details) {
    if (_selectedStone == null || _isDetecting) return;
    setState(() => _placedPosition = details.localPosition);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isARActive)
            _buildARView()
          else
            _buildPermissionScreen(),
          if (_isARActive) _buildTopControls(),
          if (_isARActive) _buildBottomControls(),
        ],
      ),
    );
  }

  // ── Permission / Enable screen ──
  Widget _buildPermissionScreen() {
    return Container(
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
                  color: AppColors.gold.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _cameraGranted
                    ? Icons.view_in_ar_outlined
                    : Icons.camera_alt_outlined,
                size: 48,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _cameraGranted ? 'Ready for AR' : 'Enable Camera for AR',
              style: GraziaTextStyles.headlineSmall.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _cameraGranted
                    ? 'Point your camera at a flat wall or floor to visualize stones in your space.'
                    : 'Grant camera access to visualize stones in your real space using augmented reality.',
                textAlign: TextAlign.center,
                style: GraziaTextStyles.bodyMedium.copyWith(
                  color: AppColors.silver,
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (!_cameraGranted)
              GraziaButton(
                label: 'Enable Camera',
                icon: Icons.camera_alt,
                onPressed: _requestCameraPermission,
              )
            else
              GraziaButton(
                label: 'Start AR',
                icon: Icons.view_in_ar_outlined,
                onPressed: _startAR,
              ),
          ],
        ),
      ),
    );
  }

  // ── AR Camera view ──
  Widget _buildARView() {
    return GestureDetector(
      onTapUp: _onTapToPlace,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: Stack(
          children: [
            // Simulated camera feed (gradient mimicking room)
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF2C2C2E),
                    Color(0xFF3A3A3C),
                    Color(0xFF48484A),
                  ],
                ),
              ),
            ),
            // Grid overlay for surface detection
            if (_isDetecting)
              CustomPaint(
                size: Size.infinite,
                painter: _GridPainter(),
              ),
            // Scanning indicator
            if (_isDetecting)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.gold.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _surfaceStatus,
                      style: GraziaTextStyles.bodyMedium.copyWith(
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
            // Placed stone overlay
            if (_placedPosition != null && _selectedStone != null)
              Positioned(
                left: _placedPosition!.dx - 50,
                top: _placedPosition!.dy - 50,
                child: Transform.scale(
                  scale: _scale,
                  child: _buildStoneOverlay(),
                ),
              ),
            // Instruction text
            if (_placedPosition == null && !_isDetecting)
              Positioned(
                bottom: 140,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    _selectedStone == null
                        ? 'Select a stone below, then tap to place'
                        : 'Tap anywhere to place $_selectedStone',
                    style: GraziaTextStyles.bodySmall.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoneOverlay() {
    final stone = _stones.firstWhere((s) => s['name'] == _selectedStone);
    final color = Color(
      int.parse(stone['color'].replaceFirst('#', '0xFF')),
    );

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.texture,
            color: Colors.white.withValues(alpha: 0.9),
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            stone['name'],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Top controls ──
  Widget _buildTopControls() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleButton(
            icon: Icons.close,
            onTap: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isDetecting ? Colors.orange : Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _isDetecting ? 'Scanning...' : 'AR Active',
                  style: GraziaTextStyles.bodySmall.copyWith(
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
          ),
          _CircleButton(
            icon: Icons.camera,
            onTap: () {
              // TODO: Capture screenshot
            },
          ),
        ],
      ),
    );
  }

  // ── Bottom controls ──
  Widget _buildBottomControls() {
    return Positioned(
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
                  int.parse(stone['color'].replaceFirst('#', '0xFF')),
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
          const SizedBox(height: 8),

          // Status text
          Text(
            _surfaceStatus,
            style: GraziaTextStyles.bodySmall.copyWith(
              color: AppColors.silver,
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
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Grid overlay for surface detection visualization.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
