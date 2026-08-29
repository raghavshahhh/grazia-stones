import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// Sample request screen with Supabase backend persistence
/// 
/// Features:
/// - Physical sample ordering for selected stone
/// - Delivery address collection
/// - Backend persistence to sample_requests table
/// - Order tracking integration
class SampleRequestScreen extends ConsumerStatefulWidget {
  final Stone stone;

  const SampleRequestScreen({super.key, required this.stone});

  @override
  ConsumerState<SampleRequestScreen> createState() => _SampleRequestScreenState();
}

class _SampleRequestScreenState extends ConsumerState<SampleRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _notesController = TextEditingController();
  
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitSampleRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      
      final order = await orderRepo.requestSample(
        stoneId: widget.stone.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        pincode: _pincodeController.text.trim(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        HapticFeedback.mediumImpact();
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => _buildSuccessDialog(order.id),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorSnackbar(e);
      }
    }
  }

  void _showErrorSnackbar(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error.toString().replaceAll('Exception: ', ''),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSuccessDialog(String orderId) {
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
            'Sample Request Confirmed',
            style: GoogleFonts.playfairDisplay(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Order #${orderId.substring(0, 8).toUpperCase()}',
            style: GoogleFonts.inter(
              color: palette.primary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your physical sample will be dispatched within 2-3 business days. You will receive tracking details via SMS.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: palette.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.go('/orders');
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.primary,
                    side: BorderSide(color: palette.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Track Order', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  child: Text('Done', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
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
          'Request Physical Sample',
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
              // Stone Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 80,
                        height: 80,
                        child: SmartStoneImage(
                          localAsset: widget.stone.images.isNotEmpty ? widget.stone.images.first : null,
                          imageUrl: widget.stone.imageUrl,
                          fit: BoxFit.cover,
                          palette: palette,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.stone.name,
                            style: GoogleFonts.playfairDisplay(
                              color: palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.stone.collection} • ${widget.stone.finish}',
                            style: GoogleFonts.inter(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'FREE Physical Sample',
                              style: GoogleFonts.inter(
                                color: Colors.green,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: palette.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Physical samples help you evaluate texture, finish, and color before bulk ordering.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: palette.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('DELIVERY DETAILS', palette),
              const SizedBox(height: 12),
              
              _buildTextField('Full Name', _nameController, palette, required: true),
              const SizedBox(height: 12),
              _buildTextField('Phone Number', _phoneController, palette, 
                  keyboardType: TextInputType.phone, required: true),
              const SizedBox(height: 12),
              _buildTextField('Delivery Address', _addressController, palette, 
                  maxLines: 2, required: true),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: _buildTextField('City', _cityController, palette, required: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField('Pincode', _pincodeController, palette, 
                        keyboardType: TextInputType.number, required: true),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              _buildSectionTitle('ADDITIONAL NOTES (OPTIONAL)', palette),
              const SizedBox(height: 12),
              
              _buildTextField(
                'Project details or special delivery instructions',
                _notesController,
                palette,
                maxLines: 3,
              ),
              
              const SizedBox(height: 24),
              
              // Delivery Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.local_shipping_outlined, 'Dispatch', '2-3 Business Days', palette),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.payment_outlined, 'Cost', 'FREE (No Charges)', palette),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.inventory_2_outlined, 'Sample Size', '6" x 6" Approx', palette),
                  ],
                ),
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
          onPressed: _isSubmitting ? null : _submitSampleRequest,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline, size: 20),
          label: Text(
            _isSubmitting ? 'Processing...' : 'Confirm Sample Request',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
          ),
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

  Widget _buildInfoRow(IconData icon, String label, String value, LuxuryPalette palette) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary),
        ),
      ],
    );
  }
}
