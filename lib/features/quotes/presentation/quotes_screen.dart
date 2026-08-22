import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';

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
    final stonesAsync = ref.watch(allStonesProvider);
    final stones = stonesAsync.valueOrNull ?? [];
    if (stones.isNotEmpty && _selectedStoneId == null) {
      _selectedStoneId = stones.first.id;
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Project Quotes',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Architectural Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.request_quote_outlined, color: palette.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Direct Architectural Pricing',
                          style: GoogleFonts.playfairDisplay(
                            color: palette.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Our estimate desk computes pricing within 24 business hours.',
                          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stone selector
            _Label('SELECT SPECIFICATION', palette),
            const SizedBox(height: 8),
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
                  style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
                  items: stones.map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name, style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14)),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedStoneId = v),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Finish
            _Label('SURFACE FINISH', palette),
            const SizedBox(height: 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? palette.primary : palette.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? palette.primary : palette.border,
                      ),
                    ),
                    child: Text(
                      f,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : palette.textSecondary,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Area
            _Label('ESTIMATED COVERAGE AREA', palette),
            const SizedBox(height: 8),
            _TextField(
              controller: _areaController,
              hint: 'e.g. 150',
              suffix: 'sq ft',
              palette: palette,
              keyboardType: TextInputType.number,
              icon: Icons.square_foot_outlined,
            ),

            const SizedBox(height: 20),

            // Notes
            _Label('PROJECT NOTES & SPECIFICATIONS (OPTIONAL)', palette),
            const SizedBox(height: 8),
            _TextField(
              controller: _notesController,
              hint: 'e.g. living room feature wall, requires bookmatch alignment...',
              palette: palette,
              maxLines: 3,
              icon: Icons.notes_outlined,
            ),

            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitQuote,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text('Submit Quote Request', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Previous quotes
            if (quotes.isNotEmpty) ...[
              Text(
                'YOUR QUOTE INQUIRIES',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: palette.textTertiary,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...quotes.map((q) => _QuoteCard(quote: q, palette: palette)),
            ],

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  void _submitQuote() {
    if (_areaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter coverage area', style: GoogleFonts.inter()),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final palette = ref.read(themePaletteProvider);
    final stonesList = ref.read(allStonesProvider).valueOrNull ?? [];
    final stone = stonesList.firstWhere((s) => s.id == _selectedStoneId!);

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
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: palette.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: palette.primary, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              'Quote Requested!',
              style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Our architectural estimation desk will compute exact slab requirements and reach out within 24 hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, height: 1.35),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
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
      style: GoogleFonts.inter(
        color: palette.textTertiary,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
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
      style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: palette.textTertiary, fontSize: 13),
        suffixText: suffix,
        suffixStyle: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: palette.primary, size: 20),
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
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
                Text(
                  quote.stoneName,
                  style: GoogleFonts.playfairDisplay(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quote.finish} · ${quote.area} · ${quote.createdAt.day}/${quote.createdAt.month}/${quote.createdAt.year}',
                  style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              quote.status.toUpperCase(),
              style: GoogleFonts.inter(
                color: statusColor,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
