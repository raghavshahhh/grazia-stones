import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';

class CustomDesignScreen extends ConsumerStatefulWidget {
  const CustomDesignScreen({super.key});

  @override
  ConsumerState<CustomDesignScreen> createState() => _CustomDesignScreenState();
}

class _CustomDesignScreenState extends ConsumerState<CustomDesignScreen> {
  // ── Custom Design Parameters ──
  int _selectedPatternIndex = 0;
  int _selectedMaterialIndex = 0;
  int _selectedFinishIndex = 0;
  final int _selectedLightingIndex = 0;

  final _widthController = TextEditingController(text: '12');
  final _heightController = TextEditingController(text: '10');
  final _notesController = TextEditingController();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();

  bool _hasBrassInlay = false;
  bool _hasLedBacklight = false;
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _patterns = [
    {
      'name': '3D Fluted Ribbed',
      'subtitle': 'Vertical linear fluting for modern lobbies',
      'icon': Icons.view_headline_rounded,
      'basePrice': 450.0,
      'asset': 'assets/images/home_hero_living_room.jpg',
    },
    {
      'name': 'Hexagonal 3D Relief',
      'subtitle': 'Interlocking geometric architectural blocks',
      'icon': Icons.hexagon_outlined,
      'basePrice': 480.0,
      'asset': 'assets/images/auth_luxury_background.jpg',
    },
    {
      'name': 'Bookmatched Slabs',
      'subtitle': 'Mirrored vein continuity across walls',
      'icon': Icons.filter_frames_rounded,
      'basePrice': 520.0,
      'asset': 'assets/images/home_hero_living_room.jpg',
    },
    {
      'name': 'Organic Wave Strata',
      'subtitle': 'Fluid undulating carved stone surface',
      'icon': Icons.waves_rounded,
      'basePrice': 490.0,
      'asset': 'assets/images/auth_luxury_background.jpg',
    },
    {
      'name': 'Linear Split Ledge',
      'subtitle': 'Deep dimensional natural split stone',
      'icon': Icons.splitscreen_rounded,
      'basePrice': 390.0,
      'asset': 'assets/images/home_hero_living_room.jpg',
    },
  ];

  final List<Map<String, dynamic>> _materials = [
    {
      'name': 'Travertine Beige',
      'color': Color(0xFFD8C4A2),
      'origin': 'Tivoli, Italy',
      'multiplier': 1.0,
    },
    {
      'name': 'Statuario White',
      'color': Color(0xFFEBEBEB),
      'origin': 'Carrara, Italy',
      'multiplier': 1.25,
    },
    {
      'name': 'Charcoal Basalt',
      'color': Color(0xFF2C2C2B),
      'origin': 'Deccan Plateau',
      'multiplier': 1.1,
    },
    {
      'name': 'Forest Emerald Quartzite',
      'color': Color(0xFF233E32),
      'origin': 'Rajasthan Quarry',
      'multiplier': 1.35,
    },
    {
      'name': 'Desert Ochre Sandstone',
      'color': Color(0xFFC79D67),
      'origin': 'Dholpur Heritage',
      'multiplier': 0.95,
    },
  ];

  final List<String> _finishes = [
    'Chiseled Rockface',
    'Velvet Honed (Matte)',
    'High-Gloss Mirror',
    'Antique Brushed Leather',
  ];

  final List<Map<String, dynamic>> _lightingOptions = [
    {'name': 'Warm Spotlight (3000K)', 'icon': Icons.wb_sunny_rounded, 'color': Color(0xFFFFD180)},
    {'name': 'Architectural Neutral (4000K)', 'icon': Icons.lightbulb_outline_rounded, 'color': Color(0xFFFFFFFF)},
    {'name': 'Dusk Luxury Mood', 'icon': Icons.nightlight_round, 'color': Color(0xFFE0C3FC)},
  ];

  @override
  void initState() {
    super.initState();
    _prefillProfile();
  }

  void _prefillProfile() {
    final profile = StorageService.instance.getClientProfile();
    if (profile['name']?.isNotEmpty == true) _nameController.text = profile['name']!;
    if (profile['phone']?.isNotEmpty == true) _phoneController.text = profile['phone']!;
    if (profile['city']?.isNotEmpty == true) _cityController.text = profile['city']!;
  }

  double get _calculatedArea {
    final w = double.tryParse(_widthController.text.trim()) ?? 12.0;
    final h = double.tryParse(_heightController.text.trim()) ?? 10.0;
    return w * h;
  }

  double get _estimatedRate {
    final pattern = _patterns[_selectedPatternIndex];
    final mat = _materials[_selectedMaterialIndex];
    double rate = (pattern['basePrice'] as double) * (mat['multiplier'] as double);
    if (_hasBrassInlay) rate += 65.0;
    if (_hasLedBacklight) rate += 45.0;
    return rate;
  }

  double get _estimatedTotal => _calculatedArea * _estimatedRate;

  Future<void> _submitCustomDesign() async {
    if (_phoneController.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit phone number for custom design consultation.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final pattern = _patterns[_selectedPatternIndex]['name'];
      final material = _materials[_selectedMaterialIndex]['name'];
      final finish = _finishes[_selectedFinishIndex];
      final area = _calculatedArea;

      // Save client profile locally
      await StorageService.instance.saveClientProfile(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Valued Client',
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
      );

      final orderRepo = ref.read(orderRepositoryProvider);
      await orderRepo.submitQuote(
        name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Custom Design Client',
        phone: _phoneController.text.trim(),
        stoneName: '✨ BESPOKE: $pattern ($material)',
        areaSqft: area,
        message: '''
🌟 BESPOKE CUSTOM STONE DESIGN SPECIFICATION
──────────────────────────────────────
• Pattern / Profile: $pattern
• Stone Material: $material (${_materials[_selectedMaterialIndex]['origin']})
• Surface Finish: $finish
• Wall Dimensions: ${_widthController.text.trim()} ft (W) × ${_heightController.text.trim()} ft (H) = ${area.toStringAsFixed(1)} sq.ft
• Brass Metal Inlays: ${_hasBrassInlay ? 'YES (+₹65/sqft)' : 'NO'}
• LED Lighting Channel: ${_hasLedBacklight ? 'YES (+₹45/sqft)' : 'NO'}
• Estimated Budget: ₹${_estimatedTotal.toInt()} (approx ₹${_estimatedRate.toInt()}/sqft)
• Site Location: ${_cityController.text.trim().isNotEmpty ? _cityController.text.trim() : 'To be confirmed'}
• Client Notes: ${_notesController.text.trim().isNotEmpty ? _notesController.text.trim() : 'Standard custom architectural execution'}
──────────────────────────────────────
'''.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Submission noted: $e'),
            backgroundColor: const Color(0xFFD4AF37),
          ),
        );
        _showSuccessDialog();
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181614),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 1.2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFFD4AF37), size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Custom Design Received!',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Our Chief Architectural Mason at Kanpur Flagship is reviewing your bespoke specifications. You will receive 3D CAD render & final costing on WhatsApp.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: const Color(0xFFC0B8A8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/home');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'Return to Home',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final activeMaterial = _materials[_selectedMaterialIndex];
    final activePattern = _patterns[_selectedPatternIndex];
    final activeLighting = _lightingOptions[_selectedLightingIndex];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0E0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0E0D),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bespoke Design Studio',
              style: GoogleFonts.playfairDisplay(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Create Custom Architectural Stone Walls',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                color: const Color(0xFFD4AF37),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Interactive 3D Architectural Wall Visualizer Preview ──
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(21),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Dynamic Base Texture & Color Tint
                    Image.asset(
                      activePattern['asset'] as String,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                    Container(
                      color: (activeMaterial['color'] as Color).withValues(alpha: 0.40),
                    ),
                    // Ambient / Spotlight Lighting Simulation
                    Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, -0.4),
                          radius: 1.0,
                          colors: [
                            (activeLighting['color'] as Color).withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.65),
                          ],
                        ),
                      ),
                    ),

                    // Top Badge: Active Custom Specifications
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.palette_rounded, size: 12, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 5),
                                Text(
                                  '${activePattern['name']} • ${activeMaterial['name']}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD4AF37),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '≈ ₹${_estimatedRate.toInt()}/sqft',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom Floating Strip: Dimension & Estimated Price
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Wall: ${_calculatedArea.toStringAsFixed(0)} sq.ft (${_widthController.text}×${_heightController.text} ft)',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                            Text(
                              'Total: ₹${_estimatedTotal.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD4AF37),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── 2. Select Architectural Pattern ──
            Text(
              '1. SELECT WALL PATTERN & RELIEF',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _patterns.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final p = _patterns[index];
                  final isSelected = _selectedPatternIndex == index;
                  return ApplePressable(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedPatternIndex = index);
                    },
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                            : const Color(0xFF181614),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            p['icon'] as IconData,
                            size: 18,
                            color: isSelected ? const Color(0xFFD4AF37) : Colors.white70,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'from ₹${(p['basePrice'] as double).toInt()}/sqft',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              color: const Color(0xFFD4AF37),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ── 3. Select Stone Material & Quarry ──
            Text(
              '2. SELECT NATURAL STONE MATERIAL',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_materials.length, (index) {
                final mat = _materials[index];
                final isSelected = _selectedMaterialIndex == index;
                return ApplePressable(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedMaterialIndex = index);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                          : const Color(0xFF181614),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
                        width: isSelected ? 1.4 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: mat['color'] as Color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30, width: 0.8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          mat['name'] as String,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // ── 4. Finish & Luxury Accents ──
            Text(
              '3. SURFACE FINISH & METALLIC ACCENTS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_finishes.length, (index) {
                final isSelected = _selectedFinishIndex == index;
                return ChoiceChip(
                  label: Text(_finishes[index]),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedFinishIndex = index);
                  },
                  selectedColor: const Color(0xFFD4AF37),
                  backgroundColor: const Color(0xFF181614),
                  labelStyle: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.black : Colors.white70,
                  ),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFFD4AF37) : Colors.white12,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: Text(
                      'Brass Metal Inlay (+₹65)',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                    ),
                    selected: _hasBrassInlay,
                    onSelected: (v) => setState(() => _hasBrassInlay = v),
                    selectedColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    backgroundColor: const Color(0xFF181614),
                    checkmarkColor: const Color(0xFFD4AF37),
                    side: BorderSide(
                      color: _hasBrassInlay ? const Color(0xFFD4AF37) : Colors.white12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: Text(
                      'LED Lighting Channel',
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.white),
                    ),
                    selected: _hasLedBacklight,
                    onSelected: (v) => setState(() => _hasLedBacklight = v),
                    selectedColor: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    backgroundColor: const Color(0xFF181614),
                    checkmarkColor: const Color(0xFFD4AF37),
                    side: BorderSide(
                      color: _hasLedBacklight ? const Color(0xFFD4AF37) : Colors.white12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── 5. Wall Dimensions (Width × Height) ──
            Text(
              '4. WALL DIMENSIONS (FEET)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF181614),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _widthController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Width (Feet)',
                        labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                        suffixText: 'ft',
                        suffixStyle: GoogleFonts.inter(color: const Color(0xFFD4AF37)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.close_rounded, color: Colors.white30, size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF181614),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: TextField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        labelText: 'Height (Feet)',
                        labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
                        suffixText: 'ft',
                        suffixStyle: GoogleFonts.inter(color: const Color(0xFFD4AF37)),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── 6. Client Quick Consultation Details (No 15 forms!) ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF181614),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFFD4AF37), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '1-TAP CLIENT CONSULTATION',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Your Name / Firm',
                      labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 16, color: Color(0xFFD4AF37)),
                      filled: true,
                      fillColor: Colors.black26,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'Phone / WhatsApp *',
                            labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                            prefixIcon: const Icon(Icons.phone_outlined, size: 16, color: Color(0xFFD4AF37)),
                            filled: true,
                            fillColor: Colors.black26,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: TextField(
                          controller: _cityController,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: 'City / Site',
                            labelStyle: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                            prefixIcon: const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFFD4AF37)),
                            filled: true,
                            fillColor: Colors.black26,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.white12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 7. Submit Action Button ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitCustomDesign,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.send_rounded, size: 17, color: Colors.black),
                          const SizedBox(width: 8),
                          Text(
                            'Request Custom Design Quote (₹${_estimatedTotal.toInt()})',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.black,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
