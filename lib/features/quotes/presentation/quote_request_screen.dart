import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/providers/stone_providers.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

class QuoteRequestScreen extends ConsumerStatefulWidget {
  const QuoteRequestScreen({super.key});

  @override
  ConsumerState<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends ConsumerState<QuoteRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _projectNameController = TextEditingController();
  final _sqftController = TextEditingController();
  final _notesController = TextEditingController();
  
  final Set<String> _selectedStones = {};
  String _projectType = 'Residential';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _projectNameController.dispose();
    _sqftController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submitQuote() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one stone', style: GoogleFonts.inter()),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote request submitted! We will contact you soon.', style: GoogleFonts.inter()),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final stonesAsync = ref.watch(allStonesProvider);
    final stones = stonesAsync.valueOrNull ?? [];

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
          'Project Quote Request',
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
                            'Architectural Procurement',
                            style: GoogleFonts.playfairDisplay(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Detailed project takeoff & volume commercial quotation.',
                            style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Contact Details
              Text(
                'CONTACT INFORMATION',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: palette.textTertiary),
              ),
              const SizedBox(height: 12),
              
              _buildTextField(palette, 'Full Name', _nameController, Validators.validateName, Icons.person_outline),
              const SizedBox(height: 14),
              
              _buildTextField(palette, 'Phone Number', _phoneController, Validators.validatePhone, Icons.phone_outlined, keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              
              _buildTextField(palette, 'Email Address', _emailController, Validators.validateEmail, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              
              const SizedBox(height: 24),
              
              // Project Details
              Text(
                'PROJECT SPECIFICATIONS',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: palette.textTertiary),
              ),
              const SizedBox(height: 12),
              
              _buildTextField(palette, 'Project Name', _projectNameController, (v) => v?.isEmpty ?? true ? 'Project name is required' : null, Icons.business_outlined),
              const SizedBox(height: 14),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _projectType,
                  decoration: InputDecoration(
                    labelText: 'Project Type',
                    labelStyle: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                    prefixIcon: Icon(Icons.category_outlined, color: palette.primary, size: 20),
                    border: InputBorder.none,
                  ),
                  items: ['Residential', 'Commercial', 'Hotel', 'Restaurant', 'Office', 'Other']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type, style: GoogleFonts.inter(color: palette.textPrimary))))
                      .toList(),
                  onChanged: (v) => setState(() => _projectType = v!),
                ),
              ),
              const SizedBox(height: 14),
              
              _buildTextField(palette, 'Approx. Area (sq ft)', _sqftController, (v) => v?.isEmpty ?? true ? 'Area is required' : null, Icons.square_foot_outlined, keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              
              _buildTextField(palette, 'Additional Notes & Edge Details', _notesController, null, Icons.notes_outlined, maxLines: 3),
              
              const SizedBox(height: 24),
              
              // Stone selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'SELECT STONE SLABS',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6, color: palette.textTertiary),
                  ),
                  Text(
                    '${_selectedStones.length} selected',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stones.length,
                itemBuilder: (context, i) {
                  final stone = stones[i];
                  final isSelected = _selectedStones.contains(stone.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isSelected ? palette.primary : palette.border, width: isSelected ? 1.5 : 1),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selectedStones.add(stone.id);
                          } else {
                            _selectedStones.remove(stone.id);
                          }
                        });
                        HapticFeedback.selectionClick();
                      },
                      title: Text(stone.name, style: GoogleFonts.playfairDisplay(color: palette.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                      subtitle: Text(stone.collection, style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12)),
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: SmartStoneImage(
                            imageUrl: stone.imageUrl,
                            width: 48,
                            height: 48,
                            palette: palette,
                          ),
                        ),
                      ),
                      activeColor: palette.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    ),
                  );
                },
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
        child: ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitQuote,
          icon: _isSubmitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(_isSubmitting ? 'Submitting Quote...' : 'Submit Quote Request', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    LuxuryPalette palette,
    String label,
    TextEditingController controller,
    String? Function(String?)? validator,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
        prefixIcon: Icon(icon, color: palette.primary, size: 20),
        filled: true,
        fillColor: palette.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.primary, width: 1.5)),
      ),
    );
  }
}
