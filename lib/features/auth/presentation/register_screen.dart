import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/utils/user_friendly_error.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _otpController = TextEditingController();
  
  final _nameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _companyFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  
  bool _otpSent = false;
  bool _isArchitect = false;
  bool _isLoading = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _otpController.dispose();
    _nameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    _companyFocusNode.dispose();
    _otpFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward().then((_) => _shakeController.reverse());
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) {
      _triggerShake();
      return;
    }

    if (!_agreedToTerms) {
      setState(() => _errorMessage = 'Please agree to Terms & Conditions');
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    // Send real OTP via Firebase
    final success = await ref.read(authRiverpodProvider.notifier).sendOTP(_phoneController.text);

    if (mounted) {
      if (success) {
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });
        _otpFocusNode.requestFocus();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to +91 ${_phoneController.text}'),
            backgroundColor: GLuxuryPalettes.gold.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final error = ref.read(authRiverpodProvider).error;
        final safeMsg = UserFriendlyError.from(
          error,
          fallbackMessage: 'Unable to send OTP right now. Please verify your phone number.',
        ).message;
        setState(() {
          _isLoading = false;
          _errorMessage = safeMsg;
        });
        _triggerShake();
      }
    }
  }

  Future<void> _verifyAndRegister() async {
    if (_otpController.text.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit OTP');
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    // Verify OTP and register via Firebase
    final success = await ref.read(authRiverpodProvider.notifier).verifyOTP(
      _otpController.text,
      name: _nameController.text,
      email: _emailController.text.isEmpty ? null : _emailController.text,
      isRegistration: true,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        // Navigate to home
        context.go('/home');
      } else {
        final error = ref.read(authRiverpodProvider).error;
        final safeMsg = UserFriendlyError.from(
          error,
          fallbackMessage: 'Registration could not be completed. Please check your details and try again.',
        ).message;
        setState(() => _errorMessage = safeMsg);
        _triggerShake();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: GLuxurySpacing.horizontalXl,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GLuxurySpacing.gapXl,
                
                // Back button
                IconButton(
                  onPressed: () {
                    if (_otpSent) {
                      setState(() {
                        _otpSent = false;
                        _otpController.clear();
                      });
                    } else {
                      context.pop();
                    }
                  },
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: palette.textSecondary,
                    size: 20,
                  ),
                ),
                
                GLuxurySpacing.gapLg,

                // Brand Logo
                const Center(
                  child: GraziaLogo(
                    variant: GraziaLogoVariant.full,
                    height: 80,
                    enableGlow: true,
                  ),
                ),
                
                GLuxurySpacing.gapXl,
                GLuxurySpacing.gapLg,

                // Title & Subtitle
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: child,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _otpSent ? 'Verify OTP' : 'Create Account',
                        style: GLuxuryTypography.h1.copyWith(
                          fontSize: 32,
                          color: palette.textPrimary,
                        ),
                      ),
                      GLuxurySpacing.gapSm,
                      Text(
                        _otpSent
                            ? 'Enter the 6-digit OTP sent to\n+91 ${_phoneController.text}'
                            : 'Join Grazia Stones to explore premium natural stones',
                        style: GLuxuryTypography.bodyLarge.copyWith(
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                GLuxurySpacing.gapXl,

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: GLuxurySpacing.paddingBase,
                    decoration: BoxDecoration(
                      color: palette.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.error.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: palette.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: GLuxuryTypography.bodyMedium.copyWith(
                              color: palette.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GLuxurySpacing.gapBase,
                ],

                // Registration Form or OTP Input
                if (!_otpSent) ...[
                  // Name
                  GraziaTextField(
                    label: 'Full Name',
                    controller: _nameController,
                    focusNode: _nameFocusNode,
                    prefixIcon: Icons.person_outline_rounded,
                    validator: Validators.required('Name'),
                  ),
                  GLuxurySpacing.gapBase,

                  // Phone
                  GraziaTextField(
                    label: 'Phone Number',
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    prefix: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+91',
                            style: GLuxuryTypography.bodyMedium.copyWith(
                              color: palette.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 20,
                            color: palette.border,
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                    validator: Validators.phone,
                  ),
                  GLuxurySpacing.gapBase,

                  // Email (optional)
                  GraziaTextField(
                    label: 'Email (optional)',
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                  ),
                  GLuxurySpacing.gapBase,

                  // Company (optional)
                  GraziaTextField(
                    label: 'Company / Firm (optional)',
                    controller: _companyController,
                    focusNode: _companyFocusNode,
                    prefixIcon: Icons.business_outlined,
                  ),
                  GLuxurySpacing.gapBase,

                  // Architect Checkbox
                  Row(
                    children: [
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: _isArchitect,
                          onChanged: (v) =>
                              setState(() => _isArchitect = v ?? false),
                          activeColor: palette.primary,
                          checkColor: palette.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'I am an Architect / Interior Designer',
                          style: GLuxuryTypography.bodyMedium.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GLuxurySpacing.gapSm,

                  // Terms Checkbox
                  Row(
                    children: [
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: _agreedToTerms,
                          onChanged: (v) =>
                              setState(() => _agreedToTerms = v ?? false),
                          activeColor: palette.primary,
                          checkColor: palette.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _agreedToTerms = !_agreedToTerms);
                          },
                          child: RichText(
                            text: TextSpan(
                              text: 'I agree to the ',
                              style: GLuxuryTypography.bodySmall.copyWith(
                                color: palette.textTertiary,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: GLuxuryTypography.bodySmall.copyWith(
                                    color: palette.primary,
                                    fontWeight: FontWeight.w600,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // OTP Input
                  GraziaTextField(
                    label: 'OTP Code',
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    prefixIcon: Icons.lock_outline_rounded,
                  ),
                  GLuxurySpacing.gapBase,
                  
                  // Resend OTP
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _sendOTP,
                      child: Text(
                        'Resend OTP',
                        style: GLuxuryTypography.labelMedium.copyWith(
                          color: palette.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                GLuxurySpacing.gapXl,

                // CTA Button
                GraziaButton(
                  label: _otpSent ? 'Verify & Create Account' : 'Send OTP',
                  icon: _otpSent
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: _isLoading
                      ? null
                      : (_otpSent ? _verifyAndRegister : _sendOTP),
                  isLoading: _isLoading,
                ),

                GLuxurySpacing.gapLg,

                // Login Link
                if (!_otpSent)
                  Center(
                    child: TextButton(
                      onPressed: () => context.pop(),
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? ',
                          style: GLuxuryTypography.bodyMedium.copyWith(
                            color: palette.textTertiary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Log In',
                              style: GLuxuryTypography.bodyMedium.copyWith(
                                color: palette.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                GLuxurySpacing.gapXxl,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
