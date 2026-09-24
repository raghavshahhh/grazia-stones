import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

/// Screen 17: BOQ & Project Calculator (Project Calculator)
/// Matches Client Reference Sheet Screen 17:
/// - "Project Calculator"
/// - Inputs:
///     • Wall Area (sq.ft.): 450
///     • Panel Size: 8' x 4' (dropdown)
///     • Estimated Panels: 15
///     • Approx. Area Coverage: 480 sq.ft.
/// - "Your Estimated Project" card (Desert Stone - 3D Stone Panel)
/// - Gold Button: "Get Quotation" -> leads to Screen 18 (/quotes/new)
class BoqCalculatorScreen extends ConsumerStatefulWidget {
  const BoqCalculatorScreen({super.key});

  @override
  ConsumerState<BoqCalculatorScreen> createState() => _BoqCalculatorScreenState();
}

class _BoqCalculatorScreenState extends ConsumerState<BoqCalculatorScreen> {
  final TextEditingController _wallAreaController = TextEditingController(text: '450');
  String _selectedPanelSize = '8\' x 4\'';
  final List<String> _panelSizes = ['8\' x 4\' (32 sq.ft)', '4\' x 2\' (8 sq.ft)', '6\' x 3\' (18 sq.ft)'];

  double get _panelSqFt {
    if (_selectedPanelSize.startsWith('8')) return 32.0;
    if (_selectedPanelSize.startsWith('4')) return 8.0;
    return 18.0;
  }

  double get _wallArea => double.tryParse(_wallAreaController.text) ?? 450.0;
  int get _estimatedPanels => (_wallArea / _panelSqFt).ceil();
  double get _approxCoverage => _estimatedPanels * _panelSqFt;

  @override
  void dispose() {
    _wallAreaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Project Calculator',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Wall Area Input
                  Text(
                    'Wall Area (sq.ft.)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: TextField(
                      controller: _wallAreaController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: palette.textPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Panel Size Dropdown
                  Text(
                    'Panel Size',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: palette.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedPanelSize,
                        isExpanded: true,
                        dropdownColor: palette.surface,
                        items: _panelSizes.map((s) {
                          return DropdownMenuItem(
                            value: s.split(' (')[0],
                            child: Text(s, style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary)),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedPanelSize = v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Estimated Panels Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimated Panels',
                        style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
                      ),
                      Text(
                        '$_estimatedPanels',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Approx. Area Coverage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Approx. Area Coverage',
                        style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
                      ),
                      Text(
                        '${_approxCoverage.toInt()} sq.ft.',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Your Estimated Project Card (Cream / Dark luxury preview)
            Text(
              'YOUR ESTIMATED PROJECT',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1C19) : const Color(0xFFFAF6F0),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFFD4AF37).withValues(alpha: 0.3) : const Color(0xFFE8DFD1),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/grande_ledge_ta02.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(width: 64, height: 64, color: const Color(0xFF222222)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Desert Stone',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '3D Stone Panel (Natural / Matt)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: palette.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Total Units: $_estimatedPanels Panels (${_approxCoverage.toInt()} sq.ft)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFD4AF37),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Gold CTA: Get Quotation -> leads to /quotes/new
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  context.push('/quotes/new');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF121212),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Get Quotation',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: const Color(0xFF121212),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFF121212)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ),
    );
  }
}
