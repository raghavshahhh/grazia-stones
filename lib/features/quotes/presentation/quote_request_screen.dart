import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

class QuoteRequestScreen extends StatefulWidget {
  const QuoteRequestScreen({super.key});

  @override
  State<QuoteRequestScreen> createState() => _QuoteRequestScreenState();
}

class _QuoteRequestScreenState extends State<QuoteRequestScreen> {
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
        const SnackBar(content: Text('Please select at least one stone')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote request submitted! We\'ll contact you soon.'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final stones = MockDataService.getAllStones();

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
          'Request Quote',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: palette.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.description_outlined, color: palette.background, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Get customized pricing for your project',
                        style: GLuxuryTypography.bodyMedium.copyWith(color: palette.background),
                      ),
                    ),
                  ],
                ),
              ),
              
              GLuxurySpacing.gapXl,
              
              // Contact Details
              Text('Contact Details', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Full Name', _nameController, Validators.validateName, Icons.person_outline),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Phone', _phoneController, Validators.validatePhone, Icons.phone_outlined, keyboardType: TextInputType.phone),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Email', _emailController, Validators.validateEmail, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              
              GLuxurySpacing.gapXl,
              
              // Project Details
              Text('Project Details', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Project Name', _projectNameController, (v) => v?.isEmpty ?? true ? 'Project name is required' : null, Icons.business_outlined),
              GLuxurySpacing.gapBase,
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: DropdownButtonFormField<String>(
                  initialValue: _projectType,
                  decoration: InputDecoration(
                    labelText: 'Project Type',
                    prefixIcon: Icon(Icons.category_outlined, color: palette.textTertiary),
                    border: InputBorder.none,
                  ),
                  items: ['Residential', 'Commercial', 'Hotel', 'Restaurant', 'Office', 'Other']
                      .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                      .toList(),
                  onChanged: (v) => setState(() => _projectType = v!),
                ),
              ),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Approx. Area (sq ft)', _sqftController, (v) => v?.isEmpty ?? true ? 'Area is required' : null, Icons.square_foot_outlined, keyboardType: TextInputType.number),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Additional Notes (Optional)', _notesController, null, Icons.notes_outlined, maxLines: 4),
              
              GLuxurySpacing.gapXl,
              
              // Stone selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Select Stones', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
                  Text('${_selectedStones.length} selected', style: GLuxuryTypography.bodySmall.copyWith(color: palette.textTertiary)),
                ],
              ),
              GLuxurySpacing.gapSm,
              
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stones.length,
                itemBuilder: (context, i) {
                  final stone = stones[i];
                  final isSelected = _selectedStones.contains(stone.id);
                  return CheckboxListTile(
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
                    title: Text(stone.name, style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary)),
                    subtitle: Text(stone.collection, style: GLuxuryTypography.bodySmall.copyWith(color: palette.textSecondary)),
                    secondary: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        stone.imageUrl ?? '',
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 50,
                          height: 50,
                          color: palette.surfaceDark,
                          child: Icon(Icons.image, color: palette.textTertiary, size: 20),
                        ),
                      ),
                    ),
                    activeColor: palette.primary,
                    tileColor: palette.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: isSelected ? palette.primary : palette.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  );
                },
              ).separated(const SizedBox(height: 12)),
              
              const SizedBox(height: 100),
            ],
          ),
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
          onPressed: _isSubmitting ? null : _submitQuote,
          icon: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send_outlined),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit Request'),
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
      style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: palette.textTertiary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: palette.primary, width: 2)),
        filled: true,
        fillColor: palette.surface,
      ),
    );
  }
}

extension _ListSeparated<T extends Widget> on ListView {
  ListView separated(Widget separator) {
    return this;
  }
}
