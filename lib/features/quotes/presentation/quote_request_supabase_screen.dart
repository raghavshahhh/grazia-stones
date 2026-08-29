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
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Comprehensive quote request screen with Supabase backend persistence
/// 
/// Features:
/// - Project details capture (name, type, area)
/// - Multi-stone selection from catalogue
/// - Contact information collection
/// - Backend persistence to quote_requests table
/// - Architectural project type options
class QuoteRequestSupabaseScreen extends ConsumerStatefulWidget {
  final Stone? preselectedStone;

  const QuoteRequestSupabaseScreen({super.key, this.preselectedStone});

  @override
  ConsumerState<QuoteRequestSupabaseScreen> createState() => _QuoteRequestSupabaseScreenState();
}

class _QuoteRequestSupabaseScreenState extends ConsumerState<QuoteRequestSupabaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _sqftController = TextEditingController();
  final _notesController = TextEditingController();
  
  final Set<String> _selectedStoneIds = {};
  String _projectType = 'Residential';
  bool _isSubmitting = false;
  bool _isLoadingStones = true;
  List<Stone> _stones = [];

  final List<String> _projectTypes = [
    'Residential',
    'Commercial',
    'Hospitality',
    'Retail',
    'Office',
    'Villa/Bungalow',
    'Apartment Complex',
  ];

  @override
  void initState() {
    super.initState();
    _loadStones();
    
    // Preselect stone if provided
    if (widget.preselectedStone != null) {
      _selectedStoneIds.add(widget.preselectedStone!.id);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _projectNameController.dispose();
    _sqftController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStones() async {
    try {
      final stoneRepo = ref.read(stoneRepositoryProvider);
      final stones = await stoneRepo.getAllStones();
      
      if (mounted) {
        setState(() {
          _stones = stones;
          _isLoadingStones = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStones = false);
      }
    }
  }

  Future<void> _submitQuote() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedStoneIds.isEmpty) {
      showErrorSnackbar(context, Exception('Please select at least one stone for quotation'));
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      
      // Get selected stone names
      final selectedStoneNames = _stones
          .where((s) => _selectedStoneIds.contains(s.id))
          .map((s) => s.name)
          .join(', ');
      
      // Submit quote for each selected stone (or combined)
      await orderRepo.submitQuote(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        company: _companyController.text.trim().isNotEmpty ? _companyController.text.trim() : null,
        stoneId: _selectedStoneIds.first, // Primary stone
        stoneName: selectedStoneNames,
        areaSqft: double.tryParse(_sqftController.text.trim()),
        message: '''
Project Type: $_projectType
Project Name: ${_projectNameController.text.trim()}
Selected Stones: $selectedStoneNames
Additional Notes: ${_notesController.text.trim()}
''',
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        HapticFeedback.mediumImpact();
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _buildSuccessDialog(context),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  Widget _buildSuccessDialog(BuildContext context) {
    final palette = ref.read(themePaletteProvider);
    
    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 36),
          ),
          const SizedBox(height: 20),
          Text(
            'Quote Request Submitted',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Our architectural stone consultants will review your project requirements and contact you within 24-48 hours with a detailed quotation.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.pop(); // Close quote screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text('Done', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ],
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
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Request Project Quote',
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
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.architecture_outlined, color: palette.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Architectural Quotation',
                            style: GoogleFonts.playfairDisplay(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Get detailed pricing for bulk commercial procurement.',
                            style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('CONTACT INFORMATION', palette),
              const SizedBox(height: 12),
              
              _buildTextField('Full Name', _nameController, palette, required: true),
              const SizedBox(height: 12),
              _buildTextField('Phone Number', _phoneController, palette, 
                  keyboardType: TextInputType.phone, required: true),
              const SizedBox(height: 12),
              _buildTextField('Email Address', _emailController, palette, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _buildTextField('Company / Firm Name', _companyController, palette),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('PROJECT DETAILS', palette),
              const SizedBox(height: 12),
              
              _buildTextField('Project Name', _projectNameController, palette),
              const SizedBox(height: 12),
              
              // Project Type Dropdown
              Text('Project Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textSecondary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _projectType,
                    isExpanded: true,
                    dropdownColor: palette.surface,
                    items: _projectTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type, style: TextStyle(color: palette.textPrimary)),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _projectType = v ?? _projectType),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              _buildTextField('Estimated Area (sq ft)', _sqftController, palette, 
                  keyboardType: TextInputType.number),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('STONE SELECTION', palette),
              const SizedBox(height: 12),
              
              if (_isLoadingStones)
                Center(child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: CircularProgressIndicator(color: palette.primary),
                ))
              else
                _buildStoneSelection(palette),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('ADDITIONAL NOTES', palette),
              const SizedBox(height: 12),
              
              _buildTextField(
                'Project specifications, timeline, or special requirements',
                _notesController,
                palette,
                maxLines: 4,
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitQuote,
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  'Submit Quote Request',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, LuxuryPalette palette) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: palette.textTertiary,
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    LuxuryPalette palette, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (required ? ' *' : ''),
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: required ? (v) => v == null || v.trim().isEmpty ? 'This field is required' : null : null,
          style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
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
        ),
      ],
    );
  }

  Widget _buildStoneSelection(LuxuryPalette palette) {
    return Column(
      children: [
        Text(
          'Select stones for this project (${_selectedStoneIds.length} selected)',
          style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _stones.take(20).length,
            itemBuilder: (context, i) {
              final stone = _stones[i];
              final isSelected = _selectedStoneIds.contains(stone.id);
              
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedStoneIds.remove(stone.id);
                    } else {
                      _selectedStoneIds.add(stone.id);
                    }
                  });
                  HapticFeedback.selectionClick();
                },
                child: Container(
                  width: 110,
                  margin: EdgeInsets.only(right: i < _stones.length - 1 ? 10 : 0),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? palette.primary : palette.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                            child: SizedBox(
                              height: 80,
                              width: double.infinity,
                              child: SmartStoneImage(
                                localAsset: stone.images.isNotEmpty ? stone.images.first : null,
                                imageUrl: stone.imageUrl,
                                fit: BoxFit.cover,
                                palette: palette,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: palette.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check, color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              stone.name,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              stone.collection,
                              style: GoogleFonts.inter(fontSize: 9, color: palette.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
}
