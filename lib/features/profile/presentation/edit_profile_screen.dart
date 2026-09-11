import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _firmController;
  String? _avatarUrl;
  bool _isUploadingAvatar = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Synchronously initialize controllers from current Riverpod auth state
    // so the page displays immediately with zero empty/blank state.
    final authState = ref.read(authRiverpodProvider);
    _nameController = TextEditingController(text: authState.userName ?? '');
    _emailController = TextEditingController(text: authState.userEmail ?? '');
    _phoneController = TextEditingController(text: authState.userPhone ?? '');
    _firmController = TextEditingController();
    _avatarUrl = authState.avatarUrl;

    // Fetch latest profile details from Supabase in the background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchProfileBackground();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _firmController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileBackground() async {
    if (!mounted) return;

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final profile = await userRepo.getProfile();

      if (mounted) {
        setState(() {
          if (_nameController.text.isEmpty && profile.name.isNotEmpty) {
            _nameController.text = profile.name;
          }
          if (_emailController.text.isEmpty && profile.email.isNotEmpty) {
            _emailController.text = profile.email;
          }
          if (_phoneController.text.isEmpty && profile.phone != null && profile.phone!.isNotEmpty) {
            _phoneController.text = profile.phone!;
          }
          if (_avatarUrl == null && profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
            _avatarUrl = profile.avatarUrl;
          }
        });
      }
    } catch (e) {
      debugPrint('ℹ️ Background profile fetch note: $e');
    }
  }

  Future<void> _handleAvatarAction() async {
    final palette = ref.read(themePaletteProvider);
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Change Profile Photo',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.photo_library_outlined, color: palette.primary, size: 20),
                ),
                title: Text('Choose from Library', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: palette.textPrimary)),
                subtitle: Text('Upload an image from your device', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary)),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: palette.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.camera_alt_outlined, color: palette.primary, size: 20),
                  ),
                  title: Text('Take a Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: palette.textPrimary)),
                  subtitle: Text('Use device camera to snap photo', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary)),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
              if (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  ),
                  title: Text('Remove Photo', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.red)),
                  subtitle: Text('Revert back to monogram initials', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary)),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == null) return;

    if (choice == 'remove') {
      setState(() => _avatarUrl = null);
      return;
    }

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    await _pickAndUploadAvatar(source);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 82, maxWidth: 1000);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile photo uploaded! Tap "Save" to finalize.'),
            backgroundColor: ref.read(themePaletteProvider).primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Avatar upload error: $e');
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    try {
      await ref.read(authRiverpodProvider.notifier).updateProfile(
        name: name,
        email: email,
        phone: phone,
        avatarUrl: _avatarUrl,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/profile');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save profile: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onBackTap() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final authState = ref.watch(authRiverpodProvider);

    final nameForInitials = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (authState.userName ?? 'Architect');
    final parts = nameForInitials.split(' ').where((s) => s.isNotEmpty).toList();
    final initials = parts.isEmpty
        ? 'GS'
        : (parts.length == 1
            ? parts[0].substring(0, parts[0].length.clamp(1, 2)).toUpperCase()
            : '${parts[0][0]}${parts[1][0]}'.toUpperCase());

    final roleLabel = authState.isAdmin
        ? 'Administrator'
        : (authState.isDealer ? 'Authorized Partner' : 'Registered Architect');

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _onBackTap,
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          tooltip: 'Back to Profile',
        ),
        title: Text(
          'Edit Profile',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _saveProfile,
            icon: _isSaving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Icon(Icons.check, size: 16, color: palette.primary),
            label: Text(
              _isSaving ? 'Saving' : 'Save',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: palette.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar Section
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingAvatar ? null : _handleAvatarAction,
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: palette.primary.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: palette.primary.withValues(alpha: 0.35),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: _isUploadingAvatar
                                    ? Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: palette.primary))
                                    : _avatarUrl != null && _avatarUrl!.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              _avatarUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Center(
                                                child: Text(
                                                  initials,
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
                                              initials,
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: palette.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: palette.surface,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: _isUploadingAvatar ? null : _handleAvatarAction,
                          child: Text(
                            'Change Profile Photo',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 13, color: palette.primary),
                              const SizedBox(width: 5),
                              Text(
                                roleLabel,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Section Title
                  Text(
                    'PROFILE DETAILS',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: palette.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Full Name
                  _buildTextField(
                    palette: palette,
                    label: 'Full Name',
                    controller: _nameController,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter your name';
                      if (val.trim().length < 2) return 'Name must be at least 2 characters';
                      return null;
                    },
                    icon: Icons.person_outline,
                    hint: 'e.g. Raghav Shah',
                  ),
                  const SizedBox(height: 16),

                  // Email
                  _buildTextField(
                    palette: palette,
                    label: 'Email Address',
                    controller: _emailController,
                    validator: Validators.validateEmail,
                    icon: Icons.email_outlined,
                    hint: 'e.g. architect@studio.com',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  _buildTextField(
                    palette: palette,
                    label: 'Phone Number',
                    controller: _phoneController,
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty && val.trim().length < 7) {
                        return 'Enter a valid phone number';
                      }
                      return null;
                    },
                    icon: Icons.phone_outlined,
                    hint: '+91 98765 43210',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),

                  // Firm / Company Name
                  _buildTextField(
                    palette: palette,
                    label: 'Studio / Firm Name (Optional)',
                    controller: _firmController,
                    validator: null,
                    icon: Icons.business_outlined,
                    hint: 'e.g. Studio Grazia Architecture',
                  ),

                  const SizedBox(height: 24),

                  // Quick links card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => context.push('/addresses'),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: palette.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.location_on_outlined, size: 18, color: palette.primary),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Saved Delivery & Project Sites',
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: palette.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Manage project addresses for site sample dispatches',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, size: 20, color: palette.textTertiary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        _isSaving ? 'Saving Changes...' : 'Save Profile Changes',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required LuxuryPalette palette,
    required String label,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
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
          style: GoogleFonts.inter(
            fontSize: 14,
            color: palette.textPrimary,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 13, color: palette.textTertiary),
            prefixIcon: Icon(icon, color: palette.primary, size: 18),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }
}
