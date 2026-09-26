import 'dart:async';
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
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/utils/user_friendly_error.dart';
import 'package:grazia_stones/core/services/storage_service.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';

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

  bool _isEmailMode = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  bool _obscurePassword = true;

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

    final success = await ref
        .read(authRiverpodProvider.notifier)
        .sendOTP(_phoneController.text);

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
        final phone = _phoneController.text.trim();
        unawaited(StorageService.instance.saveClientProfile(phone: phone));
        _navigateAfterAuth();
      } else {
        final error = ref.read(authRiverpodProvider).error;
        final safeMsg = UserFriendlyError.from(
          error,
          fallbackMessage:
              'Invalid verification code. Please check the 6-digit OTP and try again.',
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
          unawaited(StorageService.instance.saveClientProfile(
            email: _emailController.text.trim(),
            name: state.userName != 'Guest User' ? state.userName : null,
          ));
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
          _errorMessage = UserFriendlyError.from(e,
                  fallbackMessage: 'Invalid email or password')
              .message;
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
      final state = ref.read(authRiverpodProvider);
      if (state.isLoggedIn) {
        unawaited(StorageService.instance.saveClientProfile(
          email: (state.userEmail?.isNotEmpty ?? false) ? state.userEmail : null,
          name: state.userName != 'Guest User' ? state.userName : null,
        ));
      }
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

          // ── 2. Atmospheric Dark Luxury Vignette & Gradient Overlay ──
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0D0D0C).withValues(alpha: 0.65),
                    const Color(0xFF0D0D0C).withValues(alpha: 0.82),
                    const Color(0xFF0D0D0C).withValues(alpha: 0.96),
                    const Color(0xFF0D0D0C),
                  ],
                  stops: const [0.0, 0.35, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // ── 3. Subtle Golden Ambient Glow Behind Form ──
          Positioned(
            top: 60,
            left: MediaQuery.of(context).size.width / 2 - 120,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFD4AF37).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── 4. Main Scrollable Content ──
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

                    // Top Bar: Back Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
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
                        // Guest Direct Bypass Button on top right
                        if (!_otpSent)
                          TextButton(
                            onPressed: _loginAsGuest,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD4AF37),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Explore as Guest',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFFD4AF37),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 11,
                                  color: Color(0xFFD4AF37),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Centered Brand Logo
                    const Center(
                      child: GraziaLogo(
                        variant: GraziaLogoVariant.full,
                        height: 80,
                        enableGlow: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Title & Subtitle with Shake
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
                                : 'Sign in to access architectural spaces, 3D stones & quotes',
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

                    // ── Glassmorphic Auth Card Container ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161514).withValues(alpha: 0.76),
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
                              // Error Message banner
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: palette.error.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color:
                                          palette.error.withValues(alpha: 0.45),
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

                              // Mode toggle: Phone OTP vs Email & Password
                              if (!_otpSent) ...[
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              _isEmailMode = false;
                                              _errorMessage = null;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 9),
                                            decoration: BoxDecoration(
                                              color: !_isEmailMode
                                                  ? const Color(0xFFD4AF37)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Phone OTP',
                                                style: GoogleFonts.inter(
                                                  color: !_isEmailMode
                                                      ? Colors.black
                                                      : Colors.white70,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              _isEmailMode = true;
                                              _errorMessage = null;
                                            });
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 250),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 9),
                                            decoration: BoxDecoration(
                                              color: _isEmailMode
                                                  ? const Color(0xFFD4AF37)
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            child: Center(
                                              child: Text(
                                                'Email & Password',
                                                style: GoogleFonts.inter(
                                                  color: _isEmailMode
                                                      ? Colors.black
                                                      : Colors.white70,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],

                              // Fields: Phone vs Email vs OTP
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
                                ] else ...[
                                  GraziaTextField(
                                    label: 'Email Address',
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    keyboardType: TextInputType.emailAddress,
                                    prefixIcon: Icons.email_outlined,
                                    validator: Validators.email,
                                  ),
                                  const SizedBox(height: 14),
                                  GraziaTextField(
                                    label: 'Password',
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    obscure: _obscurePassword,
                                    prefixIcon: Icons.lock_outline_rounded,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_outlined
                                            : Icons.visibility_outlined,
                                        color: Colors.white54,
                                        size: 18,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Password required'
                                        : null,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => context
                                              .push('/forgot-password'),
                                      child: Text(
                                        'Forgot Password?',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFFD4AF37),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
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
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed:
                                        (_isLoading || _resendCountdown > 0)
                                            ? null
                                            : _sendOTP,
                                    child: Text(
                                      _resendCountdown > 0
                                          ? 'Resend OTP in ${_resendCountdown}s'
                                          : 'Resend OTP',
                                      style: GoogleFonts.inter(
                                        color: _resendCountdown > 0
                                            ? Colors.white38
                                            : const Color(0xFFD4AF37),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Primary CTA Button
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
                                        : (_isEmailMode
                                            ? _loginWithEmailPassword
                                            : _sendOTP)),
                                isLoading: _isLoading,
                              ),

                              const SizedBox(height: 14),

                              // Register Link
                              if (!_otpSent)
                                Center(
                                  child: TextButton(
                                    onPressed: () => context.push('/register'),
                                    child: RichText(
                                      text: TextSpan(
                                        text: "Don't have an account? ",
                                        style: GoogleFonts.inter(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Register',
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

                    const SizedBox(height: 24),

                    // ── Alternative Sign In Divider & Social Buttons ──
                    if (!_otpSent) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 0.5,
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text(
                              'or continue with',
                              style: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.55),
                                fontSize: 11.5,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              height: 0.5,
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Google Sign-In Luxury Button
                      _buildSocialAuthButton(
                        label: 'Continue with Google',
                        iconWidget: const Icon(
                          Icons.g_mobiledata,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: _signInWithGoogle,
                      ),

                      const SizedBox(height: 12),

                      // Guest Login Luxury Button
                      _buildSocialAuthButton(
                        label: 'Continue as Guest',
                        iconWidget: const Icon(
                          Icons.person_outline_rounded,
                          color: Color(0xFFD4AF37),
                          size: 20,
                        ),
                        onPressed: _loginAsGuest,
                      ),
                    ],

                    const SizedBox(height: 28),

                    // Legal & Concierge Footer
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/privacy'),
                            child: Text(
                              'Privacy Policy',
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Text('•',
                              style: TextStyle(color: Colors.white38, fontSize: 11)),
                          GestureDetector(
                            onTap: () => context.push('/terms'),
                            child: Text(
                              'Terms of Service',
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const Text('•',
                              style: TextStyle(color: Colors.white38, fontSize: 11)),
                          GestureDetector(
                            onTap: () => context.push('/help'),
                            child: Text(
                              'Concierge Help',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFD4AF37),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialAuthButton({
    required String label,
    required Widget iconWidget,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1D1B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                iconWidget,
                const SizedBox(width: 10),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
