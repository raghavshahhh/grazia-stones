import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

class AIVizScreen extends StatefulWidget {
  const AIVizScreen({super.key});

  @override
  State<AIVizScreen> createState() => _AIVizScreenState();
}

class _AIVizScreenState extends State<AIVizScreen> {
  Uint8List? _selectedImage;
  String? _selectedStoneId;
  bool _isProcessing = false;
  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (!mounted) return;
        setState(() {
          _selectedImage = bytes;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _applyStoneTexture() {
    if (_selectedImage == null || _selectedStoneId == null) return;
    
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();
    
    // Simulate AI processing
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stone texture applied! (Preview simulation)'),
          backgroundColor: Colors.green,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final stones = MockDataService.getAllStones().take(6).toList();

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
          'AI Visualization',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: palette.background, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upload your space and visualize stones instantly',
                      style: GLuxuryTypography.bodyMedium.copyWith(color: palette.background),
                    ),
                  ),
                ],
              ),
            ),
            
            GLuxurySpacing.gapXl,
            
            // Image upload section
            Text('Step 1: Upload Image', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
            GLuxurySpacing.gapSm,
            
            if (_selectedImage == null)
              Row(
                children: [
                  Expanded(
                    child: _buildUploadButton(
                      palette,
                      'Camera',
                      Icons.camera_alt_outlined,
                      () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildUploadButton(
                      palette,
                      'Gallery',
                      Icons.photo_library_outlined,
                      () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                ],
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(_selectedImage!, height: 250, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      onPressed: () => setState(() {
                        _selectedImage = null;
                        _selectedStoneId = null;
                      }),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            
            GLuxurySpacing.gapXl,
            
            // Stone selection
            Text('Step 2: Select Stone', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
            GLuxurySpacing.gapSm,
            
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
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
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? palette.primary : palette.border,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                            child: Image.network(
                              stone.imageUrl ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: palette.surfaceDark,
                                child: Icon(Icons.image, color: palette.textTertiary),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            stone.name,
                            style: GLuxuryTypography.labelSmall.copyWith(color: palette.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: Container(
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
        child: ElevatedButton.icon(
          onPressed: _selectedImage != null && _selectedStoneId != null && !_isProcessing
              ? _applyStoneTexture
              : null,
          icon: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.auto_awesome),
          label: Text(_isProcessing ? 'Processing...' : 'Apply Stone Texture'),
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: palette.background,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            disabledBackgroundColor: palette.surfaceDark,
          ),
        ),
      ),
    );
  }

  Widget _buildUploadButton(GoldPalette palette, String label, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 40),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border, style: BorderStyle.solid),
          ),
          child: Column(
            children: [
              Icon(icon, color: palette.primary, size: 40),
              const SizedBox(height: 12),
              Text(
                label,
                style: GLuxuryTypography.labelMedium.copyWith(color: palette.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
