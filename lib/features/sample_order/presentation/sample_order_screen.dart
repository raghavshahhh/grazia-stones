import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';
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
      // Sample requests go to the `sample_requests` table — the same
      // table the Admin Samples dashboard reads. (They previously
      // went to `orders` with is_sample=true, which admin never saw.)
      final sampleRepo = ref.read(sampleOrderRepositoryProvider);

      // Resolve names so the admin dashboard and notification show the
      // actual product, not a generic fallback label.
      for (final stoneId in _selectedStones) {
        final stone = _stones.where((s) => s.id == stoneId).firstOrNull;
        await sampleRepo.requestSample(
          stoneId: stoneId,
          name: _nameController.text,
          phone: _phoneController.text,
          address: _addressController.text,
          city: _cityController.text,
          pincode: _pincodeController.text,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          stoneName: stone?.name,
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
          'Sample Dispatch',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Luxury Delivery Banner
                        Container(
                          padding: const EdgeInsets.all(18),
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
                                child: Icon(Icons.inventory_2_outlined, color: palette.primary, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Complimentary 4x4" Swatches',
                                      style: GoogleFonts.playfairDisplay(
                                        color: palette.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Delivered to your architectural studio or project site in premium sample boxes.',
                                      style: GoogleFonts.inter(
                                        color: palette.textSecondary,
                                        fontSize: 12,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Stone selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SELECT STONE SWATCHES',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.6,
                                color: palette.textTertiary,
                              ),
                            ),
                            if (_selectedStones.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${_selectedStones.length} SELECTED',
                                  style: GoogleFonts.inter(
                                    color: palette.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 0.72,
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
                                  color: palette.surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected ? palette.primary : palette.border,
                                    width: isSelected ? 2 : 1,
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
                                              top: Radius.circular(13),
                                            ),
                                            child: SmartStoneImage(
                                               imageUrl: stone.imageUrl,
                                               fit: BoxFit.cover,
                                               palette: palette,
                                             ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          child: Text(
                                            stone.name,
                                            style: GoogleFonts.playfairDisplay(
                                              color: palette.textPrimary,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
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
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            color: palette.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 13,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        
                        const SizedBox(height: 28),
                        
                        // Shipping details
                        Text(
                          'STUDIO / SITE DISPATCH ADDRESS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            color: palette.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        _buildTextField(
                          palette,
                          'Recipient / Architect Name',
                          _nameController,
                          Validators.validateName,
                          Icons.person_outline,
                        ),
                        const SizedBox(height: 14),
                        
                        _buildTextField(
                          palette,
                          'Phone Number',
                          _phoneController,
                          Validators.validatePhone,
                          Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),
                        
                        _buildTextField(
                          palette,
                          'Email (Optional)',
                          _emailController,
                          null,
                          Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),
                        
                        _buildTextField(
                          palette,
                          'Studio / Project Address',
                          _addressController,
                          (v) => v?.isEmpty ?? true ? 'Address is required' : null,
                          Icons.location_on_outlined,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        
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
                                  if (v?.isEmpty ?? true) return 'Pincode required';
                                  if (v!.length != 6) return 'Invalid pincode';
                                  return null;
                                },
                                Icons.pin_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        
                        _buildTextField(
                          palette,
                          'Special Instructions (Optional)',
                          _notesController,
                          null,
                          Icons.note_outlined,
                          maxLines: 2,
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
                onPressed: _isSubmitting ? null : _submitOrder,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: Text(_isSubmitting ? 'Dispatching Samples...' : 'Request Free Sample Kit', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
