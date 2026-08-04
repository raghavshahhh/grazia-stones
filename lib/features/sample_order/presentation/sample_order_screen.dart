import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/services/mock_data_service.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

class SampleOrderScreen extends StatefulWidget {
  const SampleOrderScreen({super.key});

  @override
  State<SampleOrderScreen> createState() => _SampleOrderScreenState();
}

class _SampleOrderScreenState extends State<SampleOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  final Set<String> _selectedStones = {};
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _submitOrder() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one stone')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    // Simulate API call
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample order submitted successfully!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;
    final stones = MockDataService.getAllStones().take(6).toList();

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
          'Order Samples',
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
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: palette.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Get free samples delivered to your doorstep',
                        style: GLuxuryTypography.bodyMedium.copyWith(color: palette.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              
              GLuxurySpacing.gapXl,
              
              // Stone selection
              Text('Select Stones', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
              GLuxurySpacing.gapSm,
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: stones.length,
                itemBuilder: (context, i) {
                  final stone = stones[i];
                  final isSelected = _selectedStones.contains(stone.id);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedStones.remove(stone.id);
                        } else {
                          _selectedStones.add(stone.id);
                        }
                      });
                      HapticFeedback.selectionClick();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? palette.primary : palette.border,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  child: Image.network(
                                    stone.imageUrl ?? '',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: palette.surfaceDark,
                                      child: Icon(Icons.image, color: palette.textTertiary),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  stone.name,
                                  style: GLuxuryTypography.labelSmall.copyWith(color: palette.textPrimary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: palette.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.check, color: palette.background, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              GLuxurySpacing.gapXl,
              
              // Shipping details
              Text('Shipping Details', style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary)),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Full Name', _nameController, Validators.validateName, Icons.person_outline),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Phone', _phoneController, Validators.validatePhone, Icons.phone_outlined, keyboardType: TextInputType.phone),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Email (Optional)', _emailController, null, Icons.email_outlined, keyboardType: TextInputType.emailAddress),
              GLuxurySpacing.gapBase,
              
              _buildTextField(palette, 'Address', _addressController, (v) => v?.isEmpty ?? true ? 'Address is required' : null, Icons.location_on_outlined, maxLines: 3),
              GLuxurySpacing.gapBase,
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(palette, 'City', _cityController, (v) => v?.isEmpty ?? true ? 'City is required' : null, Icons.location_city_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(palette, 'Pincode', _pincodeController, (v) {
                      if (v?.isEmpty ?? true) return 'Pincode is required';
                      if (v!.length != 6) return 'Invalid pincode';
                      return null;
                    }, Icons.pin_outlined, keyboardType: TextInputType.number),
                  ),
                ],
              ),
              
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
          onPressed: _isSubmitting ? null : _submitOrder,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(_isSubmitting ? 'Submitting...' : 'Submit Order'),
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
          borderSide: BorderSide(color: palette.primary, width: 2),
        ),
        filled: true,
        fillColor: palette.surface,
      ),
    );
  }
}
