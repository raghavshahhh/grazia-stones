import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';

// ─── Quote Model ─────────────────────────────────────────
class QuoteEntry {
  final String id;
  final String stoneName;
  final String finish;
  final String area;
  final String notes;
  final String status;
  final DateTime createdAt;

  QuoteEntry({
    required this.id,
    required this.stoneName,
    required this.finish,
    required this.area,
    required this.notes,
    required this.status,
    required this.createdAt,
  });
}

// ─── Quote Riverpod ──────────────────────────────────────
class QuoteNotifier extends StateNotifier<List<QuoteEntry>> {
  QuoteNotifier()
      : super([
          QuoteEntry(
            id: 'q001',
            stoneName: 'Grande Ledge TA02',
            finish: 'Natural',
            area: '150 sq ft',
            notes: 'For living room feature wall',
            status: 'Pending',
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          QuoteEntry(
            id: 'q002',
            stoneName: 'Classic Ledge 07',
            finish: 'Polished',
            area: '80 sq ft',
            notes: '',
            status: 'Completed',
            createdAt: DateTime.now().subtract(const Duration(days: 7)),
          ),
        ]);

  void addQuote(QuoteEntry q) => state = [q, ...state];
}

final quotesProvider = StateNotifierProvider<QuoteNotifier, List<QuoteEntry>>(
  (_) => QuoteNotifier(),
);

// ─── Quotes Screen ───────────────────────────────────────
class QuotesScreen extends ConsumerStatefulWidget {
  const QuotesScreen({super.key});

  @override
  ConsumerState<QuotesScreen> createState() => _QuotesScreenState();
}

class _QuotesScreenState extends ConsumerState<QuotesScreen> {
  final _areaController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedStoneId;
  String _selectedFinish = 'Natural';

  final List<String> _finishes = ['Natural', 'Polished', 'Honed', 'Brushed', 'Flamed', 'Leathered'];

  @override
  void dispose() {
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final quotes = ref.watch(quotesProvider);
    final stones = MockDataService.getAllStones();
    _selectedStoneId ??= stones.first.id;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary, size: 20),
        ),
        title: Text(
          'Request Quote',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: palette.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(Icons.request_quote_outlined, color: palette.background, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Get a Personalized Quote',
                          style: GLuxuryTypography.h3.copyWith(color: palette.background, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Our team responds within 24 hours',
                          style: GLuxuryTypography.bodySmall.copyWith(color: palette.background.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            GLuxurySpacing.gapXl,

            // Stone selector
            _Label('Select Stone', palette),
            GLuxurySpacing.gapSm,
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedStoneId,
                  isExpanded: true,
                  dropdownColor: palette.surface,
                  icon: Icon(Icons.expand_more, color: palette.textSecondary),
                  style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary),
                  items: stones.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name, style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedStoneId = v),
                ),
              ),
            ),

            GLuxurySpacing.gapBase,

            // Finish
            _Label('Finish Type', palette),
            GLuxurySpacing.gapSm,
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _finishes.map((f) {
                final isSelected = _selectedFinish == f;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedFinish = f);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? palette.primary.withValues(alpha: 0.15) : palette.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? palette.primary : palette.border,
                        width: isSelected ? 1.5 : 0.8,
                      ),
                    ),
                    child: Text(
                      f,
                      style: GLuxuryTypography.bodySmall.copyWith(
                        color: isSelected ? palette.primary : palette.textSecondary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            GLuxurySpacing.gapBase,

            // Area
            _Label('Coverage Area', palette),
            GLuxurySpacing.gapSm,
            _TextField(
              controller: _areaController,
              hint: 'e.g. 150',
              suffix: 'sq ft',
              palette: palette,
              keyboardType: TextInputType.number,
              icon: Icons.square_foot_outlined,
            ),

            GLuxurySpacing.gapBase,

            // Notes
            _Label('Additional Notes (optional)', palette),
            GLuxurySpacing.gapSm,
            _TextField(
              controller: _notesController,
              hint: 'Any specific requirements...',
              palette: palette,
              maxLines: 3,
              icon: Icons.notes_outlined,
            ),

            GLuxurySpacing.gapXl,

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitQuote,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Submit Quote Request'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
              ),
            ),

            GLuxurySpacing.gapXxl,

            // Previous quotes
            if (quotes.isNotEmpty) ...[
              Text(
                'YOUR QUOTES',
                style: GLuxuryTypography.labelSmall.copyWith(
                  color: palette.textTertiary,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              GLuxurySpacing.gapBase,
              ...quotes.map((q) => _QuoteCard(quote: q, palette: palette)),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _submitQuote() {
    if (_areaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter coverage area'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final palette = ref.read(themePaletteProvider);
    final stone = MockDataService.getAllStones().firstWhere((s) => s.id == _selectedStoneId!);

    ref.read(quotesProvider.notifier).addQuote(QuoteEntry(
      id: 'q${DateTime.now().millisecondsSinceEpoch}',
      stoneName: stone.name,
      finish: _selectedFinish,
      area: '${_areaController.text} sq ft',
      notes: _notesController.text,
      status: 'Pending',
      createdAt: DateTime.now(),
    ));

    _areaController.clear();
    _notesController.clear();
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(gradient: palette.primaryGradient, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: palette.background, size: 32),
            ),
            const SizedBox(height: 16),
            Text('Quote Requested!', style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary)),
            const SizedBox(height: 8),
            Text(
              'Our team will get back to you within 24 hours with a detailed quote.',
              textAlign: TextAlign.center,
              style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final LuxuryPalette palette;
  const _Label(this.text, this.palette);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GLuxuryTypography.bodySmall.copyWith(
        color: palette.textSecondary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final LuxuryPalette palette;
  final String? suffix;
  final int maxLines;
  final TextInputType keyboardType;
  final IconData icon;

  const _TextField({
    required this.controller,
    required this.hint,
    required this.palette,
    this.suffix,
    this.maxLines = 1,
    this.keyboardType = TextInputType.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GLuxuryTypography.bodyMedium.copyWith(color: palette.textTertiary),
        suffixText: suffix,
        suffixStyle: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
        prefixIcon: Icon(icon, color: palette.textSecondary, size: 20),
        filled: true,
        fillColor: palette.surface,
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
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final QuoteEntry quote;
  final LuxuryPalette palette;
  const _QuoteCard({required this.quote, required this.palette});

  @override
  Widget build(BuildContext context) {
    final isComplete = quote.status == 'Completed';
    final statusColor = isComplete ? palette.success : palette.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(quote.stoneName, style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  '${quote.finish} · ${quote.area} · ${quote.createdAt.day}/${quote.createdAt.month}/${quote.createdAt.year}',
                  style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              quote.status,
              style: GLuxuryTypography.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
