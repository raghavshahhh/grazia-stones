import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/core/di.dart';

class SampleOrderScreen extends ConsumerStatefulWidget {
  final String? preSelectedStoneId;
  
  const SampleOrderScreen({super.key, this.preSelectedStoneId});

  @override
  ConsumerState<SampleOrderScreen> createState() => _SampleOrderScreenState();
}

class _SampleOrderScreenState extends ConsumerState<SampleOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _notesController = TextEditingController();
  
  final Set<String> _selectedStones = {};
  bool _isSubmitting = false;
  bool _isLoading = true;
  List<Stone> _stones = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedStoneId != null) {
      _selectedStones.add(widget.preSelectedStoneId!);
    }
    _loadStones();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadStones() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      
      final stoneRepo = ref.read(stoneRepositoryProvider);
      final stones = await stoneRepo.getTrendingStones();
      
      setState(() {
        _stones = stones.take(12).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStones.isEmpty) {
      showErrorSnackbar(context, Exception('Please select at least one stone'));
      return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      
      // Submit sample request for each selected stone
      for (final stoneId in _selectedStones) {
        await orderRepo.requestSample(
          stoneId: stoneId,
          addressId: 'default', // TODO: Use actual address ID when user addresses are implemented
          notes: '''
Name: ${_nameController.text}
Phone: ${_phoneController.text}
Email: ${_emailController.text.isNotEmpty ? _emailController.text : 'N/A'}
Address: ${_addressController.text}, ${_cityController.text} - ${_pincodeController.text}
${_notesController.text.isNotEmpty ? 'Notes: ${_notesController.text}' : ''}
          '''.trim(),
        );
      }
      
      if (mounted) {
        setState(() => _isSubmitting = false);
        showSuccessSnackbar(
          context,
          'Sample order for ${_selectedStones.length} stone(s) submitted successfully!',
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

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
      body: _error != null
          ? ErrorHandlerWidget(
              error: Exception(_error),
              onRetry: _loadStones,
            )
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : SingleChildScrollView(
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
                            gradient: LinearGradient(
                              colors: [
                                palette.primary.withValues(alpha: 0.1),
                                palette.primary.withValues(alpha: 0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.local_shipping_outlined, color: palette.primary, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Free Sample Delivery',
                                      style: GLuxuryTypography.h4.copyWith(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Get samples delivered to your doorstep at no cost',
                                      style: GLuxuryTypography.bodySmall.copyWith(
                                        color: palette.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        GLuxurySpacing.gapXl,
                        
                        // Stone selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Select Stones',
                              style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                            ),
                            if (_selectedStones.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_selectedStones.length} selected',
                                  style: GLuxuryTypography.labelSmall.copyWith(
                                    color: palette.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
                          itemCount: _stones.length,
                          itemBuilder: (context, i) {
                            final stone = _stones[i];
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
                                            borderRadius: const BorderRadius.vertical(
                                              top: Radius.circular(12),
                                            ),
                                            child: Image.network(
                                              stone.imageUrl ?? '',
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                color: palette.surfaceDark,
                                                child: Icon(
                                                  Icons.image,
                                                  color: palette.textTertiary,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Text(
                                            stone.name,
                                            style: GLuxuryTypography.labelSmall.copyWith(
                                              color: palette.textPrimary,
                                            ),
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
                                            boxShadow: [
                                              BoxShadow(
                                                color: palette.primary.withValues(alpha: 0.4),
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            Icons.check,
                                            color: palette.background,
                                            size: 16,
                                          ),
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
                        Text(
                          'Shipping Details',
                          style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
                        ),
                        GLuxurySpacing.gapBase,
                        
                        _buildTextField(
                          palette,
                          'Full Name',
                          _nameController,
                          Validators.validateName,
                          Icons.person_outline,
                        ),
                        GLuxurySpacing.gapBase,
                        
                        _buildTextField(
                          palette,
                          'Phone',
                          _phoneController,
                          Validators.validatePhone,
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        GLuxurySpacing.gapBase,
                        
                        _buildTextField(
                          palette,
                          'Email (Optional)',
                          _emailController,
                          null,
                          Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        GLuxurySpacing.gapBase,
                        
                        _buildTextField(
                          palette,
                          'Address',
                          _addressController,
                          (v) => v?.isEmpty ?? true ? 'Address is required' : null,
                          Icons.location_on_outlined,
                          maxLines: 3,
                        ),
                        GLuxurySpacing.gapBase,
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                palette,
                                'City',
                                _cityController,
                                (v) => v?.isEmpty ?? true ? 'City is required' : null,
                                Icons.location_city_outlined,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                palette,
                                'Pincode',
                                _pincodeController,
                                (v) {
                                  if (v?.isEmpty ?? true) return 'Pincode is required';
                                  if (v!.length != 6) return 'Invalid pincode';
                                  return null;
                                },
                                Icons.pin_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        GLuxurySpacing.gapBase,
                        
                        _buildTextField(
                          palette,
                          'Additional Notes (Optional)',
                          _notesController,
                          null,
                          Icons.note_outlined,
                          maxLines: 3,
                        ),
                        
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: palette.background,
                border: Border(top: BorderSide(color: palette.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitOrder,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Order'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  disabledBackgroundColor: palette.surfaceDark,
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
