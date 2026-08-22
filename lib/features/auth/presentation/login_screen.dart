import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/core/utils/validators.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final _otpFocusNode = FocusNode();
  
  bool _otpSent = false;
  bool _isLoading = false;
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
    _phoneController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
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
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OTP sent to +91 ${_phoneController.text}'),
            backgroundColor: GLuxuryPalettes.gold.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // Error handled by provider, show it
        final error = ref.read(authRiverpodProvider).error;
        setState(() {
          _isLoading = false;
          _errorMessage = error ?? 'Failed to send OTP';
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
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

    // Verify OTP via Firebase
    final success = await ref.read(authRiverpodProvider.notifier).verifyOTP(
      _otpController.text,
      name: 'User ${_phoneController.text.substring(0, 3)}',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        // Navigate to home
        context.go('/home');
      } else {
        // Show error
        final error = ref.read(authRiverpodProvider).error;
        setState(() => _errorMessage = error ?? 'Invalid OTP');
        _triggerShake();
      }
    }
  }

  Future<void> _loginAsGuest() async {
    HapticFeedback.lightImpact();
    ref.read(authRiverpodProvider.notifier).login(
          'guest',
          'Guest User',
          '',
        );
    context.go('/home');
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
                GLuxurySpacing.gapXxl,
                GLuxurySpacing.gapXl,
                
                // Back button (if onboarding completed, show back)
                if (!_otpSent)
                  IconButton(
                    onPressed: () => context.go('/onboarding'),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                  )
                else
                  IconButton(
                    onPressed: () => setState(() {
                      _otpSent = false;
                      _otpController.clear();
                    }),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: palette.textSecondary,
                      size: 20,
                    ),
                  ),
                
                GLuxurySpacing.gapLg,

                // Brand Logo
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: palette.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: palette.primary.withValues(alpha: 0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: palette.background,
                      ),
                      child: Center(
                        child: ShaderMask(
                          shaderCallback: (bounds) =>
                              palette.primaryGradient.createShader(bounds),
                          child: const Text(
                            'G',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                GLuxurySpacing.gapXxl,
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
                        _otpSent ? 'Verify OTP' : 'Welcome Back',
                        style: GLuxuryTypography.h1.copyWith(
                          fontSize: 36,
                          color: palette.textPrimary,
                        ),
                      ),
                      GLuxurySpacing.gapSm,
                      Text(
                        _otpSent
                            ? 'Enter the 6-digit OTP sent to\n+91 ${_phoneController.text}'
                            : 'Login to explore premium stones',
                        style: GLuxuryTypography.bodyLarge.copyWith(
                          color: palette.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                GLuxurySpacing.gapXxl,

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
                  GLuxurySpacing.gapLg,
                ],

                // Phone Input or OTP Input
                if (!_otpSent) ...[
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
                ] else ...[
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
                  label: _otpSent ? 'Verify & Login' : 'Send OTP',
                  icon: _otpSent
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: _isLoading
                      ? null
                      : (_otpSent ? _verifyOTP : _sendOTP),
                  isLoading: _isLoading,
                ),

                GLuxurySpacing.gapLg,

                // Register Link
                if (!_otpSent)
                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/register'),
                      child: RichText(
                        text: TextSpan(
                          text: 'Don\'t have an account? ',
                          style: GLuxuryTypography.bodyMedium.copyWith(
                            color: palette.textTertiary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Register',
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

                // Divider
                if (!_otpSent) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 0.5,
                          color: palette.border,
                        ),
                      ),
                      Padding(
                        padding: GLuxurySpacing.horizontalBase,
                        child: Text(
                          'or',
                          style: GLuxuryTypography.labelSmall.copyWith(
                            color: palette.textTertiary,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 0.5,
                          color: palette.border,
                        ),
                      ),
                    ],
                  ),
                  GLuxurySpacing.gapXl,

                  // Guest Login
                  GraziaButton(
                    label: 'Continue as Guest',
                    variant: GraziaButtonVariant.outline,
                    icon: Icons.person_outline_rounded,
                    onPressed: _loginAsGuest,
                  ),
                ],

                GLuxurySpacing.gapXxl,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
