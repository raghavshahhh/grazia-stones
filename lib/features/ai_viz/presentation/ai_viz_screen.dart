import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  bool _isGenerating = false;
  String? _generatedUrl;
  String? _selectedRoomStyle;
  final TextEditingController _descriptionController = TextEditingController();

  final List<String> _roomStyles = [
    'Living Room',
    'Kitchen',
    'Bathroom',
    'Bedroom',
    'Outdoor Patio',
    'Lobby',
  ];

  final Map<String, String> _stylePrompts = {
    'Living Room': 'modern%20luxury%20living%20room%20with%20stone%20wall%20accents%20warm%20lighting%20interior%20design',
    'Kitchen': 'modern%20luxury%20kitchen%20with%20stone%20countertops%20and%20backsplash%20interior%20design',
    'Bathroom': 'luxury%20spa%20bathroom%20with%20stone%20walls%20and%20floor%20interior%20design',
    'Bedroom': 'elegant%20bedroom%20with%20stone%20accent%20wall%20cozy%20ambiance%20interior%20design',
    'Outdoor Patio': 'luxury%20outdoor%20patio%20with%20stone%20flooring%20and%20walls%20landscaping',
    'Lobby': 'grand%20hotel%20lobby%20with%20marble%20walls%20and%20floors%20luxury%20interior%20design',
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _generateVisualization() async {
    if (_selectedRoomStyle == null) return;

    setState(() => _isGenerating = true);

    final basePrompt = _stylePrompts[_selectedRoomStyle] ?? 'luxury%20stone%20interior';
    final customDesc = _descriptionController.text.trim();
    final fullPrompt = customDesc.isNotEmpty
        ? '${Uri.encodeComponent(customDesc)}%20$basePrompt'
        : basePrompt;
    final url = 'https://image.pollinations.ai/prompt/$fullPrompt?width=768&height=512&seed=${DateTime.now().millisecondsSinceEpoch}';

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _generatedUrl = url;
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDark,
      appBar: AppBar(
        backgroundColor: AppColors.charcoal,
        title: const Text('AI Room Visualizer', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'See how our stones look in your space',
              style: AppTextStyles.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              'Select a room style, add a description, and our AI will generate a visualization.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'Room Style',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Wrap(
              spacing: AppDimensions.spacingS,
              runSpacing: AppDimensions.spacingS,
              children: _roomStyles.map((style) {
                final isSelected = _selectedRoomStyle == style;
                return ChoiceChip(
                  label: Text(style),
                  selected: isSelected,
                  selectedColor: AppColors.gold,
                  backgroundColor: AppColors.charcoal,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.gold : AppColors.borderSubtle,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _selectedRoomStyle = selected ? style : null;
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spacingL),
            Text(
              'Additional Details (optional)',
              style: AppTextStyles.titleSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. "Warm ambient lighting, modern furniture, large windows"',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.charcoal,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  borderSide: const BorderSide(color: AppColors.gold, width: 2),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            SizedBox(
              width: double.infinity,
              height: AppDimensions.buttonHeight,
              child: ElevatedButton.icon(
                onPressed: (_selectedRoomStyle == null || _isGenerating)
                    ? null
                    : _generateVisualization,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isGenerating ? 'Generating...' : 'Visualize Room',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  disabledBackgroundColor: AppColors.textTertiary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            if (_generatedUrl != null) ...[
              Text(
                'Generated Visualization',
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.charcoal,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Image.network(
                        _generatedUrl!,
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 300,
                            color: AppColors.surfaceLight,
                            child: const Center(
                              child: CircularProgressIndicator(color: AppColors.gold),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 300,
                            color: AppColors.surfaceLight,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error_outline, size: 48, color: AppColors.textTertiary),
                                  SizedBox(height: 8),
                                  Text('Failed to generate image', style: TextStyle(color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacingM),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.gold, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Room style: $_selectedRoomStyle',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.spacingM),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _generateVisualization,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    padding: const EdgeInsets.all(AppDimensions.spacingM),
                  ),
                ),
              ),
            ],
            if (_generatedUrl == null && !_isGenerating) ...[
              const SizedBox(height: AppDimensions.spacingXxl),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.room_preferences,
                      size: 64,
                      color: AppColors.textTertiary.withOpacity(0.5),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    Text(
                      'Select a room style above to get started',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
