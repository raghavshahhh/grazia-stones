import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final email = _emailController.text.trim();
      await ref.read(authRiverpodProvider.notifier).sendPasswordReset(email);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });
        showSuccessSnackbar(context, 'Password reset link sent to $email');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackbar(context, e);
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

          // ── 2. Vignette & Dark Overlay ──
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

                    // Back Button
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
                            onPressed: () => context.pop(),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Centered Brand Logo
                    const Center(
                      child: GraziaLogo(
                        variant: GraziaLogoVariant.full,
                        height: 80,
                        enableGlow: true,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Glassmorphic Card Container
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF161514).withValues(alpha: 0.80),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.25),
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
                              Text(
                                _emailSent
                                    ? 'Check Your Inbox'
                                    : 'Reset Password',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _emailSent
                                    ? 'We sent a secure password recovery link to ${_emailController.text}. Please check your email to continue.'
                                    : 'Enter your registered architectural account email to receive recovery instructions.',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.75),
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (!_emailSent) ...[
                                GraziaTextField(
                                  label: 'Email Address',
                                  controller: _emailController,
                                  focusNode: _emailFocusNode,
                                  keyboardType: TextInputType.emailAddress,
                                  prefixIcon: Icons.email_outlined,
                                  validator: Validators.email,
                                ),
                                const SizedBox(height: 22),
                                GraziaButton(
                                  label: 'Send Recovery Email',
                                  icon: Icons.send_rounded,
                                  onPressed:
                                      _isLoading ? null : _sendResetEmail,
                                  isLoading: _isLoading,
                                ),
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1D1B),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFD4AF37)
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.mark_email_read_outlined,
                                        color: Color(0xFFD4AF37),
                                        size: 26,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          'Follow the link in your email to choose a new password, then return here to log in.',
                                          style: GoogleFonts.inter(
                                            color: Colors.white70,
                                            fontSize: 12.5,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                GraziaButton(
                                  label: 'Back to Login',
                                  icon: Icons.login_rounded,
                                  onPressed: () => context.go('/login'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Help Concierge
                    Center(
                      child: TextButton.icon(
                        onPressed: () => context.push('/help'),
                        icon: const Icon(Icons.headset_mic_outlined,
                            size: 16, color: Color(0xFFD4AF37)),
                        label: Text(
                          'Need help recovering your account? Contact Concierge',
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),
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
