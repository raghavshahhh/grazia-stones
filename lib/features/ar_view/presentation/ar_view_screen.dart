import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';

class ARViewScreen extends ConsumerStatefulWidget {
  const ARViewScreen({super.key});

  @override
  ConsumerState<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends ConsumerState<ARViewScreen> {
  // AR Controllers
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  // State
  List<Stone>? _stones;
  String? _selectedStoneId;
  bool _isARActive = false;
  bool _isLoading = true;
  Object? _error;
  bool _surfaceDetected = false;
  List<ARNode> _arNodes = [];

  @override
  void initState() {
    super.initState();
    _loadStones();
  }

  Future<void> _loadStones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stoneRepo = ref.read(stoneRepositoryProvider);
      final stones = await stoneRepo.getTrendingStones(limit: 12);
      
      if (mounted) {
        setState(() {
          _stones = stones;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ AR View stones load error: $e');
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  void _startAR() {
    if (_selectedStoneId == null) return;
    setState(() => _isARActive = true);
    HapticFeedback.mediumImpact();
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      customPlaneTexturePath: "assets/triangle.png",
      showWorldOrigin: false,
      handlePans: true,
      handleRotation: true,
    );
    
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = (results) {
      if (!_surfaceDetected) {
        setState(() => _surfaceDetected = true);
        HapticFeedback.lightImpact();
      }
      _onPlaneOrPointTapped(results);
    };
  }

  Future<void> _onPlaneOrPointTapped(List<ARHitTestResult> hitTestResults) async {
    if (_selectedStoneId == null || hitTestResults.isEmpty) return;
    
    final planeHits = hitTestResults.where(
      (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane,
    );
    if (planeHits.isEmpty) return;
    final singleHitTestResult = planeHits.first;
    
    // Create a stone node
    var newNode = ARNode(
      type: NodeType.webGLB,
      uri: "https://github.com/KhronosGroup/glTF-Sample-Models/raw/master/2.0/Box/glTF/Box.gltf",
      scale: vector.Vector3(0.5, 0.5, 0.5),
      position: vector.Vector3(
        singleHitTestResult.worldTransform.getColumn(3)[0],
        singleHitTestResult.worldTransform.getColumn(3)[1],
        singleHitTestResult.worldTransform.getColumn(3)[2],
      ),
      rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
    );

    bool didAddNode = await arObjectManager!.addNode(newNode) ?? false;
    
    if (didAddNode) {
      _arNodes.add(newNode);
      HapticFeedback.mediumImpact();
      if (mounted) {
        showSuccessSnackbar(context, 'Stone placed in AR');
      }
    }
  }

  void _removeAllNodes() async {
    for (var node in _arNodes) {
      await arObjectManager?.removeNode(node);
    }
    _arNodes.clear();
    HapticFeedback.lightImpact();
    if (mounted) {
      showInfoSnackbar(context, 'All stones removed');
    }
  }

  void _captureScreenshot() {
    HapticFeedback.mediumImpact();
    showSuccessSnackbar(context, 'Screenshot captured');
    // TODO: Implement actual screenshot capture
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    
    // Loading state
    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
          ),
          title: Text('AR View', style: GLuxuryTypography.h3),
        ),
        body: Center(child: CircularProgressIndicator(color: palette.primary)),
      );
    }

    // Error state
    if (_error != null) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          backgroundColor: palette.background,
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
          ),
        ),
        body: ErrorHandlerWidget(
          error: _error!,
          onRetry: _loadStones,
        ),
      );
    }

    final stones = _stones ?? [];
    final selectedStone = _selectedStoneId != null
        ? stones.firstWhere((s) => s.id == _selectedStoneId, orElse: () => stones.first)
        : null;

    return Scaffold(
      backgroundColor: palette.background,
      body: Stack(
        children: [
          // AR View or Placeholder
          if (_isARActive)
            ARView(
              onARViewCreated: _onARViewCreated,
              planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
            )
          else
            _buildPlaceholder(palette),
          
          // Top bar
          _buildTopBar(context, palette, selectedStone),
          
          // Surface detection indicator
          if (_isARActive && !_surfaceDetected)
            _buildSurfaceDetectionHint(palette),
          
          // Stone selector at bottom
          if (!_isARActive)
            _buildStoneSelector(palette, stones),
          
          // AR controls
          if (_isARActive)
            _buildARControls(palette),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(LuxuryPalette palette) {
    return Container(
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
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: palette.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'How to use AR View:',
                          style: GLuxuryTypography.labelLarge.copyWith(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInstruction(palette, '1', 'Select your favorite stone'),
                  _buildInstruction(palette, '2', 'Tap "Start AR" button'),
                  _buildInstruction(palette, '3', 'Point camera at floor or wall'),
                  _buildInstruction(palette, '4', 'Tap to place stone'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstruction(LuxuryPalette palette, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: GLuxuryTypography.labelSmall.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GLuxuryTypography.bodySmall.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, LuxuryPalette palette, Stone? selectedStone) {
    return Positioned(
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
              (_isARActive ? Colors.black : palette.background).withValues(alpha: 0.8),
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
                  color: (_isARActive ? Colors.black : palette.surface).withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: _isARActive ? null : Border.all(color: palette.border),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new,
                  color: _isARActive ? Colors.white : palette.textPrimary,
                  size: 18,
                ),
              ),
            ),
            if (!_isARActive) ...[
              const SizedBox(width: 8),
              Text(
                'AR View',
                style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
              ),
            ],
            const Spacer(),
            if (selectedStone != null && _isARActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.layers, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      selectedStone.name,
                      style: GLuxuryTypography.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurfaceDetectionHint(LuxuryPalette palette) {
    return Positioned(
      top: 120,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(palette.primary),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Move your device to detect surfaces...',
                style: GLuxuryTypography.bodySmall.copyWith(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoneSelector(LuxuryPalette palette, List<Stone> stones) {
    if (stones.isEmpty) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: EdgeInsets.all(32),
          child: Text(
            'No stones available',
            textAlign: TextAlign.center,
            style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
          ),
        ),
      );
    }

    return Positioned(
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
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
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: palette.primary.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SmartStoneImage(
                          imageUrl: stone.imageUrl,
                          fit: BoxFit.cover,
                          palette: palette,
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
                  elevation: _selectedStoneId != null ? 4 : 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildARControls(LuxuryPalette palette) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildARControl(
              Icons.camera_alt,
              'Capture',
              _captureScreenshot,
            ),
            _buildARControl(
              Icons.delete_outline,
              'Clear All',
              _arNodes.isNotEmpty ? _removeAllNodes : null,
            ),
            _buildARControl(
              Icons.close,
              'Exit AR',
              () => setState(() {
                _isARActive = false;
                _surfaceDetected = false;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildARControl(IconData icon, String label, VoidCallback? onTap) {
    final isDisabled = onTap == null;
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GLuxuryTypography.labelSmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
