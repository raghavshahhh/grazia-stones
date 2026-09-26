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
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/core/services/location_service.dart';
import 'package:grazia_stones/core/widgets/animated_widgets.dart';

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
  bool _isEditingDetails = false;
  bool _isDetectingLocation = false;
  String? _detectedLocationLabel;
  List<Stone> _stones = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.preSelectedStoneId != null) {
      _selectedStones.add(widget.preSelectedStoneId!);
    }
    _loadStones();
    _prefillUserData();
  }

  Future<void> _prefillUserData() async {
    // 1. Check local persistent profile
    final localProfile = StorageService.instance.getClientProfile();
    if (localProfile['name']?.isNotEmpty == true && _nameController.text.isEmpty) {
      _nameController.text = localProfile['name']!;
    }
    if (localProfile['phone']?.isNotEmpty == true && _phoneController.text.isEmpty) {
      _phoneController.text = localProfile['phone']!;
    }
    if (localProfile['email']?.isNotEmpty == true && _emailController.text.isEmpty) {
      _emailController.text = localProfile['email']!;
    }
    if (localProfile['address']?.isNotEmpty == true && _addressController.text.isEmpty) {
      _addressController.text = localProfile['address']!;
    }
    if (localProfile['city']?.isNotEmpty == true && _cityController.text.isEmpty) {
      _cityController.text = localProfile['city']!;
    }
    if (localProfile['pincode']?.isNotEmpty == true && _pincodeController.text.isEmpty) {
      _pincodeController.text = localProfile['pincode']!;
    }

    final authState = ref.read(authRiverpodProvider);
    if (authState.userName != null && authState.userName!.isNotEmpty && _nameController.text.isEmpty) {
      _nameController.text = authState.userName!;
    }
    if (authState.userPhone != null && authState.userPhone!.isNotEmpty && _phoneController.text.isEmpty) {
      _phoneController.text = authState.userPhone!;
    }
    if (authState.userEmail != null && authState.userEmail!.isNotEmpty && _emailController.text.isEmpty) {
      _emailController.text = authState.userEmail!;
    }
    try {
      final userRepo = ref.read(userRepositoryProvider);
      final addresses = await userRepo.getAddresses();
      if (mounted && addresses.isNotEmpty) {
        final def = addresses.firstWhere((a) => a['is_default'] == true, orElse: () => addresses.first);
        if (_addressController.text.isEmpty && def['address_line1'] != null) {
          _addressController.text = def['address_line1'];
        }
        if (_cityController.text.isEmpty && def['city'] != null) {
          _cityController.text = def['city'];
        }
        if (_pincodeController.text.isEmpty && def['pincode'] != null) {
          _pincodeController.text = def['pincode'];
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isEditingDetails = _nameController.text.isEmpty ||
            _phoneController.text.isEmpty ||
            _addressController.text.isEmpty;
      });
    }
  }

  Future<void> _autoDetectLocation() async {
    setState(() => _isDetectingLocation = true);
    HapticFeedback.lightImpact();

    try {
      final loc = await detectCurrentLocation();
      if (loc != null && mounted) {
        setState(() {
          if (loc.addressLine1 != null && loc.addressLine1!.isNotEmpty) {
            _addressController.text = loc.addressLine1!;
          }
          if (loc.city != null && loc.city!.isNotEmpty) {
            _cityController.text = loc.city!;
          }
          if (loc.pincode != null && loc.pincode!.isNotEmpty) {
            _pincodeController.text = loc.pincode!;
          }
          _detectedLocationLabel = <String?>[
            loc.city,
            loc.state,
            loc.pincode,
          ].where((e) => e != null && e.isNotEmpty).join(', ');
        });
        if (mounted) {
          showSuccessSnackbar(context, 'Location detected: $_detectedLocationLabel');
        }
      } else if (mounted) {
        showErrorSnackbar(context, Exception('Could not determine location. Please enter manually.'));
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, Exception('Location access failed. Please enter address manually.'));
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
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

      // Save client profile to universal storage so user is NEVER asked again
      await StorageService.instance.saveClientProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        pincode: _pincodeController.text.trim(),
      );

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

                        if (!_isEditingDetails && _nameController.text.isNotEmpty && _addressController.text.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: palette.primary.withValues(alpha: 0.35)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.verified_user_rounded, color: palette.primary, size: 16),
                                        const SizedBox(width: 6),
                                        Text(
                                          'VERIFIED RECIPIENT & SITE',
                                          style: GoogleFonts.inter(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.2,
                                            color: palette.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ApplePressable(
                                          onTap: _isDetectingLocation ? null : _autoDetectLocation,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: palette.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (_isDetectingLocation)
                                                  SizedBox(
                                                    width: 11,
                                                    height: 11,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 1.5,
                                                      color: palette.primary,
                                                    ),
                                                  )
                                                else
                                                  Icon(Icons.my_location_rounded, size: 11, color: palette.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'GPS',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: palette.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        ApplePressable(
                                          onTap: () => setState(() => _isEditingDetails = true),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: palette.primary.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.edit_outlined, size: 11, color: palette.primary),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Change',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: palette.primary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _nameController.text,
                                  style: GoogleFonts.playfairDisplay(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.phone_outlined, size: 13, color: palette.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _phoneController.text,
                                      style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                                    ),
                                    if (_emailController.text.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text('•', style: TextStyle(color: palette.textTertiary)),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _emailController.text,
                                          style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 13, color: palette.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        [
                                          _addressController.text,
                                          _cityController.text,
                                          _pincodeController.text.isNotEmpty ? 'PIN: ${_pincodeController.text}' : null,
                                        ].where((e) => e != null && e.isNotEmpty).join(', '),
                                        style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        else ...[
                          // Auto-Detect Current GPS Location Action Card
                          Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _detectedLocationLabel != null
                                    ? palette.primary
                                    : palette.primary.withValues(alpha: 0.35),
                                width: _detectedLocationLabel != null ? 1.5 : 1,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isDetectingLocation ? null : _autoDetectLocation,
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: palette.primary.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: _isDetectingLocation
                                            ? SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: palette.primary,
                                                ),
                                              )
                                            : Icon(Icons.my_location_rounded, color: palette.primary, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isDetectingLocation
                                                  ? 'Detecting current location...'
                                                  : 'Auto-Detect Current Location',
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: palette.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _detectedLocationLabel != null
                                                  ? '📍 Detected: $_detectedLocationLabel'
                                                  : 'Tap to fetch city & pincode via phone GPS',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                color: _detectedLocationLabel != null
                                                    ? palette.primary
                                                    : palette.textSecondary,
                                                fontWeight: _detectedLocationLabel != null
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, color: palette.textTertiary, size: 20),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

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
                          if (_nameController.text.isNotEmpty && _addressController.text.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => setState(() => _isEditingDetails = false),
                                icon: const Icon(Icons.check_rounded, size: 15),
                                label: Text(
                                  'Done Editing',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ],
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
