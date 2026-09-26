import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

    // Send real OTP via Firebase / Auth provider
    final success = await ref
        .read(authRiverpodProvider.notifier)
        .sendOTP(_phoneController.text);

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
          fallbackMessage:
              'Unable to send OTP right now. Please verify your phone number.',
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

    // Verify OTP and register
    final success = await ref.read(authRiverpodProvider.notifier).verifyOTP(
          _otpController.text,
          name: _nameController.text,
          email: _emailController.text.isEmpty ? null : _emailController.text,
          isRegistration: true,
        );

    if (mounted) {
      setState(() => _isLoading = false);

      if (success) {
        final state = GoRouterState.of(context);
        final redirectPath = state.uri.queryParameters['redirect'];
        if (redirectPath != null && redirectPath.isNotEmpty) {
          context.go(redirectPath);
        } else {
          context.go('/home');
        }
      } else {
        final error = ref.read(authRiverpodProvider).error;
        final safeMsg = UserFriendlyError.from(
          error,
          fallbackMessage:
              'Registration could not be completed. Please check your details and try again.',
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
      backgroundColor: const Color(0xFF0D0D0C),
      body: Stack(
        children: [
          // ── 1. Architectural Luxury Stone Background Image ──
          Positioned.fill(
            child: Image.asset(
              'assets/images/auth_luxury_background.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF0D0D0C),
              ),
            ),
          ),

          // ── 2. Atmospheric Dark Luxury Gradient Overlay ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0D0D0C).withValues(alpha: 0.65),
                    const Color(0xFF0D0D0C).withValues(alpha: 0.85),
                    const Color(0xFF0D0D0C).withValues(alpha: 0.98),
                    const Color(0xFF0D0D0C),
                  ],
                  stops: const [0.0, 0.35, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // ── 3. Content ──
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // Back button
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15),
                              width: 0.8,
                            ),
                          ),
                          child: IconButton(
                            onPressed: () {
                              if (_otpSent) {
                                setState(() {
                                  _otpSent = false;
                                  _otpController.clear();
                                });
                              } else {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/home');
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Brand Logo
                    const Center(
                      child: GraziaLogo(
                        variant: GraziaLogoVariant.full,
                        height: 80,
                        enableGlow: true,
                      ),
                    ),

                    const SizedBox(height: 24),

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
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _otpSent
                                ? 'Enter the 6-digit code sent to +91 ${_phoneController.text}'
                                : 'Join Grazia Stones to access bespoke stone collections & projects',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    // ── Glassmorphic Form Card Container ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161514).withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.24),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.50),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Error Message
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: palette.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: palette.error.withValues(alpha: 0.45),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline_rounded,
                                        color: palette.error,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: GoogleFonts.inter(
                                            color: palette.error,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              if (!_otpSent) ...[
                                // Full Name
                                GraziaTextField(
                                  label: 'Full Name',
                                  controller: _nameController,
                                  focusNode: _nameFocusNode,
                                  prefixIcon: Icons.person_outline_rounded,
                                  validator: Validators.required('Name'),
                                ),
                                const SizedBox(height: 14),

                                // Phone Number
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
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFFD4AF37),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 1,
                                          height: 20,
                                          color: Colors.white24,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  ),
                                  validator: Validators.phone,
                                ),
                                const SizedBox(height: 14),

                                // Email (optional)
                                GraziaTextField(
                                  label: 'Email (optional)',
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                ),
                                const SizedBox(height: 14),

                                // Company (optional)
                                GraziaTextField(
                                  label: 'Company / Firm (optional)',
                                  controller: _companyController,
                                  focusNode: _companyFocusNode,
                                  prefixIcon: Icons.business_outlined,
                                ),
                                const SizedBox(height: 16),

                                // Architect Checkbox
                                Row(
                                  children: [
                                    Transform.scale(
                                      scale: 1.05,
                                      child: Checkbox(
                                        value: _isArchitect,
                                        onChanged: (v) => setState(
                                            () => _isArchitect = v ?? false),
                                        activeColor: const Color(0xFFD4AF37),
                                        checkColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        'I am an Architect / Interior Designer',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Terms Checkbox
                                Row(
                                  children: [
                                    Transform.scale(
                                      scale: 1.05,
                                      child: Checkbox(
                                        value: _agreedToTerms,
                                        onChanged: (v) => setState(
                                            () => _agreedToTerms = v ?? false),
                                        activeColor: const Color(0xFFD4AF37),
                                        checkColor: Colors.black,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            'I agree to the ',
                                            style: GoogleFonts.inter(
                                              color: Colors.white54,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => context.push('/terms'),
                                            child: Text(
                                              'Terms & Conditions',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFD4AF37),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11.5,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            ' and ',
                                            style: GoogleFonts.inter(
                                              color: Colors.white54,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                context.push('/privacy'),
                                            child: Text(
                                              'Privacy Policy',
                                              style: GoogleFonts.inter(
                                                color: const Color(0xFFD4AF37),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 11.5,
                                                decoration:
                                                    TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
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
                                const SizedBox(height: 10),

                                // Resend OTP
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isLoading ? null : _sendOTP,
                                    child: Text(
                                      'Resend OTP',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFFD4AF37),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 22),

                              // CTA Button
                              GraziaButton(
                                label: _otpSent
                                    ? 'Verify & Create Account'
                                    : 'Send OTP',
                                icon: _otpSent
                                    ? Icons.check_circle_outline_rounded
                                    : Icons.arrow_forward_rounded,
                                onPressed: _isLoading
                                    ? null
                                    : (_otpSent
                                        ? _verifyAndRegister
                                        : _sendOTP),
                                isLoading: _isLoading,
                              ),

                              const SizedBox(height: 14),

                              // Login Link
                              if (!_otpSent)
                                Center(
                                  child: TextButton(
                                    onPressed: () => context.pop(),
                                    child: RichText(
                                      text: TextSpan(
                                        text: 'Already have an account? ',
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Log In',
                                            style: GoogleFonts.inter(
                                              color: const Color(0xFFD4AF37),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 36),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
