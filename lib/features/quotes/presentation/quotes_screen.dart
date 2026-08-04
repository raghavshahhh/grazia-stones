import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/quote_request.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';

class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  final _areaController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedStone = 'Charcoal Black';
  String _selectedFinish = 'Polished';

  final List<String> _stones = [
    'Charcoal Black',
    'Graphite Grey',
    'Walnut Brown',
    'Matte White',
    'Brushed Silver',
    'Accent Gold',
  ];

  final List<String> _finishes = [
    'Polished',
    'Honed',
    'Leathered',
    'Brushed',
    'Flamed',
  ];

  @override
  void dispose() {
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Request Quote',
          style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get a personalized quote',
              style: GraziaTextStyles.headlineSmall.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Select your stone preferences and area requirements. Our team will respond within 24 hours.',
              style: GraziaTextStyles.bodyMedium.copyWith(color: AppColors.silver),
            ),
            const SizedBox(height: AppDimensions.spacingXL),

            Text('Stone', style: GraziaTextStyles.titleSmall.copyWith(color: Colors.white)),
            const SizedBox(height: AppDimensions.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.slate),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStone,
                  isExpanded: true,
                  dropdownColor: AppColors.graphite,
                  style: GraziaTextStyles.bodyMedium.copyWith(color: Colors.white),
                  icon: const Icon(Icons.expand_more, color: AppColors.silver),
                  items: _stones.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => _selectedStone = v!),
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),

            Text('Finish', style: GraziaTextStyles.titleSmall.copyWith(color: Colors.white)),
            const SizedBox(height: AppDimensions.spacingS),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _finishes.map((f) {
                final isSelected = _selectedFinish == f;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFinish = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.gold.withValues(alpha: 0.2) : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isSelected ? AppColors.gold : AppColors.slate),
                    ),
                    child: Text(
                      f,
                      style: GraziaTextStyles.bodyMedium.copyWith(
                        color: isSelected ? AppColors.gold : AppColors.silver,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppDimensions.spacingL),

            GraziaTextField(
              label: 'Area (sq. ft.)',
              controller: _areaController,
              keyboardType: TextInputType.number,
              prefix: const Icon(Icons.square_foot, size: 20),
            ),
            const SizedBox(height: AppDimensions.spacingL),

            GraziaTextField(
              label: 'Additional Notes (optional)',
              controller: _notesController,
              maxLines: 3,
              prefix: const Icon(Icons.notes_outlined, size: 20),
            ),
            const SizedBox(height: AppDimensions.spacingXL),

            SizedBox(
              width: double.infinity,
              child: GraziaButton(
                label: 'Submit Quote Request',
                icon: Icons.send_outlined,
                onPressed: _submitQuote,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingL),

            Text('Previous Quotes', style: GraziaTextStyles.titleSmall.copyWith(color: Colors.white)),
            const SizedBox(height: AppDimensions.spacingM),
            Builder(
              builder: (context) {
                final quotes = ref.watch(quoteRiverpodProvider).quotes;
                return Column(
                  children: quotes.map((q) {
                    final isCompleted = q.status == 'Completed';
                    final date = '${q.createdAt.month}/${q.createdAt.day}/${q.createdAt.year}';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.spacingM),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.slate),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q.stoneName,
                                    style: GraziaTextStyles.bodyMedium.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${q.area} · $date',
                                    style: GraziaTextStyles.bodySmall.copyWith(color: AppColors.silver),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isCompleted
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : AppColors.gold.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                q.status,
                                style: GraziaTextStyles.bodySmall.copyWith(
                                  color: isCompleted ? Colors.green : AppColors.gold,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitQuote() {
    if (_areaController.text.isEmpty) return;

    ref.read(quoteRiverpodProvider.notifier).addQuote(
          QuoteRequest(
            id: 'q${DateTime.now().millisecondsSinceEpoch}',
            stoneName: _selectedStone,
            finish: _selectedFinish,
            area: '${_areaController.text} sq ft',
            notes: _notesController.text,
            status: 'Pending',
            createdAt: DateTime.now(),
          ),
        );

    _areaController.clear();
    _notesController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.graphite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppColors.charcoal, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Quote Requested!', style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              'Our team will get back to you within 24 hours with a detailed quote.',
              textAlign: TextAlign.center,
              style: GraziaTextStyles.bodySmall.copyWith(color: AppColors.silver),
            ),
            const SizedBox(height: 20),
            GraziaButton(label: 'Done', onPressed: () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }
}
