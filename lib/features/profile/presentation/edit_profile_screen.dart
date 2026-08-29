import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authState = ref.read(authRiverpodProvider);

    _nameController.text = authState.userName ?? 'Guest Architect';
    _emailController.text = authState.userEmail ?? 'guest@graziastones.com';
    _phoneController.text = authState.userPhone ?? '';
    _avatarUrl = authState.avatarUrl;

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final profile = await userRepo.getProfile();

      if (mounted) {
        setState(() {
          if (profile.name.isNotEmpty) _nameController.text = profile.name;
          if (profile.email.isNotEmpty) _emailController.text = profile.email;
          if (profile.phone != null && profile.phone!.isNotEmpty) _phoneController.text = profile.phone!;
          if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) _avatarUrl = profile.avatarUrl;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('ℹ️ Profile fetch info (guest/unauthenticated): $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      HapticFeedback.mediumImpact();

      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      final userRepo = ref.read(userRepositoryProvider);
      final publicUrl = await userRepo.uploadAvatar(bytes, ext);

      if (mounted) {
        setState(() {
          _avatarUrl = publicUrl;
          _isUploadingAvatar = false;
        });
        showSuccessSnackbar(context, 'Profile picture updated');
        ref.read(authRiverpodProvider.notifier).loadProfile();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarUrl: _avatarUrl,
      );

      await ref.read(authRiverpodProvider.notifier).updateProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        showSuccessSnackbar(context, 'Profile updated successfully!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
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
          'Edit Profile',
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
              onRetry: _loadProfile,
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
                        // Profile Avatar
                        Center(
                          child: GestureDetector(
                            onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  width: 88,
                                  height: 88,
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: palette.primary.withValues(alpha: 0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: _isUploadingAvatar
                                      ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary))
                                      : _avatarUrl != null && _avatarUrl!.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                _avatarUrl!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Center(
                                                  child: Text(
                                                    _nameController.text.isNotEmpty
                                                        ? _nameController.text.substring(0, 1).toUpperCase()
                                                        : 'A',
                                                    style: GoogleFonts.playfairDisplay(
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.w700,
                                                      color: palette.primary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                _nameController.text.isNotEmpty
                                                    ? _nameController.text.substring(0, 1).toUpperCase()
                                                    : 'A',
                                                style: GoogleFonts.playfairDisplay(
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w700,
                                                  color: palette.primary,
                                                ),
                                              ),
                                            ),
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: palette.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: palette.background,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),


                        const SizedBox(height: 28),

                        Text(
                          'ARCHITECT DETAILS',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            color: palette.textTertiary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          palette,
                          'Full Name',
                          _nameController,
                          Validators.validateName,
                          Icons.person_outline,
                          hint: 'Enter your full name',
                        ),
                        const SizedBox(height: 14),

                        _buildTextField(
                          palette,
                          'Email Address',
                          _emailController,
                          Validators.validateEmail,
                          Icons.email_outlined,
                          hint: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 14),

                        _buildTextField(
                          palette,
                          'Phone Number',
                          _phoneController,
                          Validators.validatePhone,
                          Icons.phone_outlined,
                          hint: 'Enter your phone number',
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 14),

                        _buildTextField(
                          palette,
                          'Company / Firm Name (Optional)',
                          _addressController,
                          null,
                          Icons.business_outlined,
                          hint: 'e.g. Studio Architectura',
                        ),

                        const SizedBox(height: 24),

                        // Info Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.verified_user_outlined,
                                color: palette.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your professional profile ensures priority concierge support and seamless quote requests.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: palette.textSecondary,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(_isSaving ? 'Saving Changes...' : 'Save Profile Changes'),
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
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: palette.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: palette.textTertiary),
            prefixIcon: Icon(icon, color: palette.primary, size: 20),
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1.5),
            ),
            filled: true,
            fillColor: palette.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
