import 'dart:async';
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
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/utils/user_friendly_error.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';
import 'package:grazia_stones/features/auth/providers/auth_riverpod_provider.dart';

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

  Timer? _resendTimer;
  int _resendCountdown = 0;

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

  bool _isEmailMode = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerShake() {
    _shakeController.forward().then((_) => _shakeController.reverse());
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown <= 1) {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _sendOTP() async {
    if (_resendCountdown > 0 && _otpSent) return;

    if (!_formKey.currentState!.validate()) {
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    final success = await ref.read(authRiverpodProvider.notifier).sendOTP(_phoneController.text);

    if (mounted) {
      if (success) {
        setState(() {
          _isLoading = false;
          _otpSent = true;
        });
        _startResendTimer();
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

  void _navigateAfterAuth() {
    final state = GoRouterState.of(context);
    final redirectPath = state.uri.queryParameters['redirect'];
    if (redirectPath != null && redirectPath.isNotEmpty) {
      context.go(redirectPath);
    } else {
      context.go('/home');
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

    final success = await ref.read(authRiverpodProvider.notifier).verifyOTP(
      _otpController.text,
      name: 'User ${_phoneController.text.substring(0, 3)}',
    );

    if (mounted) {
      setState(() => _isLoading = false);
      
      if (success) {
        _navigateAfterAuth();
      } else {
        final error = ref.read(authRiverpodProvider).error;
        final safeMsg = UserFriendlyError.from(
          error,
          fallbackMessage: 'Invalid verification code. Please check the 6-digit OTP and try again.',
        ).message;
        setState(() => _errorMessage = safeMsg);
        _triggerShake();
      }
    }
  }

  Future<void> _loginWithEmailPassword() async {
    if (!_formKey.currentState!.validate()) {
      _triggerShake();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    HapticFeedback.mediumImpact();

    try {
      await ref.read(authRiverpodProvider.notifier).loginWithApi(
        _emailController.text.trim(),
        _passwordController.text,
      );

      final state = ref.read(authRiverpodProvider);
      if (mounted) {
        setState(() => _isLoading = false);
        if (state.isLoggedIn) {
          _navigateAfterAuth();
        } else if (state.error != null) {
          setState(() => _errorMessage = state.error);
          _triggerShake();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = UserFriendlyError.from(e, fallbackMessage: 'Invalid email or password').message;
        });
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
    _navigateAfterAuth();
  }

  Future<void> _signInWithGoogle() async {
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);
    
    try {
      await ref.read(authRiverpodProvider.notifier).signInWithGoogle();
      if (mounted) {
        _navigateAfterAuth();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = UserFriendlyError.from(
            e,
            fallbackMessage: 'Google sign-in failed. Please try again.',
          ).message;
        });
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
                const Center(
                  child: GraziaLogo(
                    variant: GraziaLogoVariant.full,
                    height: 86,
                    enableGlow: true,
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

                // Mode toggle (Phone OTP vs Email & Password)
                if (!_otpSent) ...[
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEmailMode = false;
                                _errorMessage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !_isEmailMode ? palette.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: Text(
                                  'Phone OTP',
                                  style: GLuxuryTypography.labelMedium.copyWith(
                                    color: !_isEmailMode ? Colors.white : palette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isEmailMode = true;
                                _errorMessage = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _isEmailMode ? palette.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Center(
                                child: Text(
                                  'Email & Password',
                                  style: GLuxuryTypography.labelMedium.copyWith(
                                    color: _isEmailMode ? Colors.white : palette.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GLuxurySpacing.gapLg,
                ],

                // Phone Input or Email Input or OTP Input
                if (!_otpSent) ...[
                  if (!_isEmailMode) ...[
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
                      label: 'Email Address',
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      validator: Validators.email,
                    ),
                    GLuxurySpacing.gapBase,
                    GraziaTextField(
                      label: 'Password',
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      obscure: _obscurePassword,
                      prefixIcon: Icons.lock_outline_rounded,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: palette.textTertiary,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
                    ),

                    GLuxurySpacing.gapBase,
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : () => context.push('/forgot-password'),
                        child: Text(
                          'Forgot Password?',
                          style: GLuxuryTypography.labelMedium.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
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
                      onPressed: (_isLoading || _resendCountdown > 0) ? null : _sendOTP,
                      child: Text(
                        _resendCountdown > 0
                            ? 'Resend OTP in ${_resendCountdown}s'
                            : 'Resend OTP',
                        style: GLuxuryTypography.labelMedium.copyWith(
                          color: _resendCountdown > 0
                              ? palette.textTertiary
                              : palette.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],

                GLuxurySpacing.gapXl,

                // CTA Button
                GraziaButton(
                  label: _otpSent
                      ? 'Verify & Login'
                      : (_isEmailMode ? 'Sign In' : 'Send OTP'),
                  icon: _otpSent || _isEmailMode
                      ? Icons.check_circle_outline_rounded
                      : Icons.arrow_forward_rounded,
                  onPressed: _isLoading
                      ? null
                      : (_otpSent
                          ? _verifyOTP
                          : (_isEmailMode ? _loginWithEmailPassword : _sendOTP)),
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

                  // Google Sign-In
                  GraziaButton(
                    label: 'Continue with Google',
                    variant: GraziaButtonVariant.outline,
                    icon: Icons.g_mobiledata,
                    onPressed: _signInWithGoogle,
                  ),
                  GLuxurySpacing.gapBase,

                  // Guest Login
                  GraziaButton(
                    label: 'Continue as Guest',
                    variant: GraziaButtonVariant.outline,
                    icon: Icons.person_outline_rounded,
                    onPressed: _loginAsGuest,
                  ),
                ],

                GLuxurySpacing.gapXxl,

                // Legal & Concierge Footer
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: Text(
                          'Privacy Policy',
                          style: GLuxuryTypography.bodySmall.copyWith(
                            color: palette.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 11)),
                      GestureDetector(
                        onTap: () => context.push('/terms'),
                        child: Text(
                          'Terms of Service',
                          style: GLuxuryTypography.bodySmall.copyWith(
                            color: palette.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Text('•', style: TextStyle(color: palette.textTertiary, fontSize: 11)),
                      GestureDetector(
                        onTap: () => context.push('/help'),
                        child: Text(
                          'Concierge Help',
                          style: GLuxuryTypography.bodySmall.copyWith(
                            color: palette.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
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

