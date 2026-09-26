import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/services/location_service.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
import 'package:grazia_stones/features/quotes/presentation/quotes_screen.dart' show quotesProvider;

/// Streamlined, frictionless quote request screen.
/// Eliminates bloated 15-field forms and supports 1-tap client submission.
class QuoteRequestSupabaseScreen extends ConsumerStatefulWidget {
  final Stone? preselectedStone;
  final String? preselectedStoneId;

  const QuoteRequestSupabaseScreen({
    super.key,
    this.preselectedStone,
    this.preselectedStoneId,
  });

  @override
  ConsumerState<QuoteRequestSupabaseScreen> createState() => _QuoteRequestSupabaseScreenState();
}

class _QuoteRequestSupabaseScreenState extends ConsumerState<QuoteRequestSupabaseScreen> {
  static const Color _gold = Color(0xFFD4AF37);

  final _formKey = GlobalKey<FormState>();

  // 1-Tap Client Details
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  final _sqftController = TextEditingController(text: '250');
  final _customNoteController = TextEditingController();

  final Set<String> _selectedStoneIds = {};
  String _projectType = 'Residential';
  bool _isCustomDesign = false;
  bool _hasSavedProfile = false;
  bool _isEditingProfile = false;
  bool _isSubmitting = false;
  bool _isLoadingStones = true;
  bool _isDetectingLocation = false;
  List<Stone> _stones = [];

  final List<String> _projectTypes = [
    'Residential',
    'Commercial',
    'Villa/Bungalow',
    'Hospitality',
  ];

  final List<int> _quickSqftChips = [100, 250, 500, 1000, 2500];

  @override
  void initState() {
    super.initState();
    _loadStones();
    _loadUserProfile();

    if (widget.preselectedStone != null) {
      _selectedStoneIds.add(widget.preselectedStone!.id);
    } else if (widget.preselectedStoneId != null) {
      _selectedStoneIds.add(widget.preselectedStoneId!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _sqftController.dispose();
    _customNoteController.dispose();
    super.dispose();
  }

  void _loadUserProfile() {
    final localProfile = StorageService.instance.getClientProfile();
    final authState = ref.read(authRiverpodProvider);

    final savedName = localProfile['name']?.isNotEmpty == true
        ? localProfile['name']!
        : (authState.userName ?? '');
    final savedPhone = localProfile['phone']?.isNotEmpty == true
        ? localProfile['phone']!
        : (authState.userPhone ?? '');
    final savedCity = localProfile['city'] ?? localProfile['address'] ?? '';

    if (savedName.isNotEmpty) _nameController.text = savedName;
    if (savedPhone.isNotEmpty) _phoneController.text = savedPhone;
    if (savedCity.isNotEmpty) _cityController.text = savedCity;

    if (_nameController.text.trim().isNotEmpty && _phoneController.text.trim().isNotEmpty) {
      setState(() {
        _hasSavedProfile = true;
        _isEditingProfile = false;
      });
    } else {
      setState(() {
        _hasSavedProfile = false;
        _isEditingProfile = true;
      });
    }
  }

  Future<void> _loadStones() async {
    try {
      final stoneRepo = ref.read(stoneRepositoryProvider);
      final stones = await stoneRepo.getAllStones();
      if (mounted) {
        setState(() {
          _stones = stones;
          _isLoadingStones = false;
          if (_selectedStoneIds.isEmpty && stones.isNotEmpty && !_isCustomDesign) {
            _selectedStoneIds.add(stones.first.id);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStones = false);
    }
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _isDetectingLocation = true);
    HapticFeedback.lightImpact();
    try {
      final loc = await detectCurrentLocation();
      if (loc != null && mounted) {
        final locText = [loc.city, loc.state].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() {
          _cityController.text = locText.isNotEmpty ? locText : (loc.addressLine1 ?? '');
        });
        showSuccessSnackbar(context, 'Location detected: ${_cityController.text}');
      }
    } catch (_) {
      if (mounted) {
        showErrorSnackbar(context, Exception('Could not detect location. Please enter your city.'));
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _submitQuote() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isCustomDesign && _selectedStoneIds.isEmpty) {
      showErrorSnackbar(context, Exception('Please choose at least one stone or select Custom Design'));
      return;
    }

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final city = _cityController.text.trim();
    final sqft = double.tryParse(_sqftController.text.trim()) ?? 100.0;

    if (name.isEmpty || phone.isEmpty) {
      showErrorSnackbar(context, Exception('Please enter your Name and Mobile Number'));
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      // 1. Save profile universally so user NEVER fills it again
      await StorageService.instance.saveClientProfile(
        name: name,
        phone: phone,
        city: city,
      );

      final orderRepo = ref.read(orderRepositoryProvider);
      final selectedStoneNames = _stones
          .where((s) => _selectedStoneIds.contains(s.id))
          .map((s) => s.name)
          .join(', ');

      final messageBody = _isCustomDesign
          ? '''
[BESPOKE CUSTOM DESIGN REQUEST]
Project Type: $_projectType
Area: ${sqft.toStringAsFixed(0)} sq.ft.
Location: ${city.isNotEmpty ? city : 'India'}
Custom Specs / Note: ${_customNoteController.text.trim().isNotEmpty ? _customNoteController.text.trim() : 'Bespoke architectural layout requested'}
'''.trim()
          : '''
Project Type: $_projectType
Area: ${sqft.toStringAsFixed(0)} sq.ft.
Location: ${city.isNotEmpty ? city : 'India'}
Selected Stones: $selectedStoneNames
Notes: ${_customNoteController.text.trim()}
'''.trim();

      await orderRepo.submitQuote(
        name: name,
        phone: phone,
        stoneId: _isCustomDesign ? null : _selectedStoneIds.firstOrNull,
        stoneName: _isCustomDesign ? 'Bespoke Custom Design' : selectedStoneNames,
        areaSqft: sqft,
        message: messageBody,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        ref.read(quotesProvider.notifier).load();
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  void _showSuccessDialog() {
    final palette = ref.read(themePaletteProvider);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [_gold.withValues(alpha: 0.2), _gold.withValues(alpha: 0.05)],
                ),
                border: Border.all(color: _gold, width: 1.5),
              ),
              child: const Icon(Icons.check_rounded, color: _gold, size: 38),
            ),
            const SizedBox(height: 18),
            Text(
              'Quotation Submitted',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Your inquiry has been routed to our senior stone architects. A formal estimate with slab layouts will be shared on WhatsApp / Phone within 2 hours.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: palette.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text('Done', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14)),
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

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Instant Quotation',
          style: GoogleFonts.playfairDisplay(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          // Direct shortcut to Bespoke 3D Custom Studio
          TextButton.icon(
            onPressed: () => context.push('/custom-design'),
            icon: const Icon(Icons.architecture_rounded, color: _gold, size: 16),
            label: Text(
              '3D Studio',
              style: GoogleFonts.inter(
                color: _gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Toggle Mode: Catalogue vs Custom Design
              _buildTypeSelector(palette),
              const SizedBox(height: 20),

              // 2. Stone Selection OR Custom Design Notice
              if (!_isCustomDesign) ...[
                _buildStoneSelector(palette),
                const SizedBox(height: 20),
              ] else ...[
                _buildCustomDesignBanner(palette),
                const SizedBox(height: 20),
              ],

              // 3. Project Type & Area
              _buildAreaAndTypeSection(palette),
              const SizedBox(height: 20),

              // 4. Frictionless Client Profile (1-Tap if saved, else 2 simple fields)
              _buildFrictionlessContactSection(palette),
              const SizedBox(height: 24),

              // 5. Submit Button
              _buildSubmitButton(palette),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isCustomDesign = false);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isCustomDesign ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.diamond_outlined,
                      size: 16,
                      color: !_isCustomDesign ? Colors.black : palette.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Catalogue Stone',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: !_isCustomDesign ? FontWeight.w700 : FontWeight.w500,
                        color: !_isCustomDesign ? Colors.black : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isCustomDesign = true);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isCustomDesign ? _gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.architecture_rounded,
                      size: 16,
                      color: _isCustomDesign ? Colors.black : palette.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Custom Bespoke',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: _isCustomDesign ? FontWeight.w700 : FontWeight.w500,
                        color: _isCustomDesign ? Colors.black : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDesignBanner(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _gold.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.brush_rounded, color: _gold, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bespoke Stone Crafting',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    Text(
                      'Fluted walls, CNC carved motifs, bookmatched slabs & custom sizes',
                      style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _customNoteController,
            maxLines: 2,
            style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary),
            decoration: InputDecoration(
              hintText: 'E.g. 10x8 ft Fluted wall panel with brass inlay for living room...',
              hintStyle: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary.withValues(alpha: 0.7)),
              filled: true,
              fillColor: palette.surface,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: palette.border),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/custom-design'),
              icon: const Icon(Icons.view_in_ar_rounded, size: 16, color: _gold),
              label: Text(
                'Open Interactive 3D Custom Studio',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: _gold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _gold),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoneSelector(LuxuryPalette palette) {
    if (_isLoadingStones) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: _gold, strokeWidth: 2),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Select Stone',
              style: GoogleFonts.playfairDisplay(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            Text(
              '${_selectedStoneIds.length} selected',
              style: GoogleFonts.inter(fontSize: 12, color: _gold, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _stones.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final stone = _stones[index];
              final isSelected = _selectedStoneIds.contains(stone.id);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isSelected) {
                      if (_selectedStoneIds.length > 1) {
                        _selectedStoneIds.remove(stone.id);
                      }
                    } else {
                      _selectedStoneIds.add(stone.id);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 90,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? _gold : palette.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: SmartStoneImage(
                            imageUrl: stone.imageUrl,
                            palette: palette,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected) ...[
                              const Icon(Icons.check_circle_rounded, color: _gold, size: 12),
                              const SizedBox(width: 3),
                            ],
                            Flexible(
                              child: Text(
                                stone.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? _gold : palette.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAreaAndTypeSection(LuxuryPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Scope',
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Project Type Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _projectTypes.map((type) {
                final isSelected = _projectType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _projectType = type);
                    },
                    selectedColor: _gold.withValues(alpha: 0.18),
                    backgroundColor: palette.background,
                    side: BorderSide(
                      color: isSelected ? _gold : palette.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? _gold : palette.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Approx Area
          Row(
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _sqftController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Approx Area (Sq. Ft.)',
                    labelStyle: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                    prefixIcon: const Icon(Icons.straighten_rounded, color: _gold, size: 18),
                    filled: true,
                    fillColor: palette.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: _cityController,
                  style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'City / Location',
                    labelStyle: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                    prefixIcon: const Icon(Icons.location_city_rounded, color: _gold, size: 18),
                    suffixIcon: IconButton(
                      onPressed: _isDetectingLocation ? null : _autoDetectLocation,
                      icon: _isDetectingLocation
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _gold))
                          : const Icon(Icons.my_location_rounded, color: _gold, size: 18),
                      tooltip: 'Detect GPS',
                    ),
                    filled: true,
                    fillColor: palette.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick sqft buttons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _quickSqftChips.map((chip) {
              final isCurrent = _sqftController.text == chip.toString();
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _sqftController.text = chip.toString());
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent ? _gold.withValues(alpha: 0.15) : palette.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isCurrent ? _gold : palette.border.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      '$chip sqft',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCurrent ? _gold : palette.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFrictionlessContactSection(LuxuryPalette palette) {
    // 1-Tap Saved Profile Card
    if (_hasSavedProfile && !_isEditingProfile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _gold.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded, color: _gold, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _nameController.text,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Verified Client',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.green),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '+91 ${_phoneController.text}${_cityController.text.isNotEmpty ? ' • ${_cityController.text}' : ''}',
                    style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _isEditingProfile = true),
              icon: Icon(Icons.edit_outlined, size: 18, color: palette.textSecondary),
              tooltip: 'Edit details',
            ),
          ],
        ),
      );
    }

    // Unsaved: Only 2 required fields
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Contact Details',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              if (_hasSavedProfile)
                TextButton(
                  onPressed: () => setState(() => _isEditingProfile = false),
                  child: Text('Cancel', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
            decoration: InputDecoration(
              labelText: 'Full Name *',
              labelStyle: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
              prefixIcon: const Icon(Icons.person_outline_rounded, color: _gold, size: 18),
              filled: true,
              fillColor: palette.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Please enter mobile number';
              if (v.trim().replaceAll(RegExp(r'\D'), '').length < 10) return 'Enter valid 10-digit number';
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Mobile Number *',
              labelStyle: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
              prefixIcon: const Icon(Icons.phone_outlined, color: _gold, size: 18),
              prefixText: '+91 ',
              prefixStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary),
              filled: true,
              fillColor: palette.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We will save this securely so you never have to re-enter it.',
            style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(LuxuryPalette palette) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _submitQuote,
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: _gold.withValues(alpha: 0.35),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        _isCustomDesign ? 'Request Bespoke Quotation' : 'Get Instant Slab Quotation',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 13, color: _gold),
            const SizedBox(width: 6),
            Text(
              'No spam guaranteed • Directly routed to Grazia Stone HQ',
              style: GoogleFonts.inter(fontSize: 11, color: palette.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}
