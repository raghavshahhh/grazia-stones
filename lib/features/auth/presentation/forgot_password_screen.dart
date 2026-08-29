import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/utils/validators.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
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
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: palette.textSecondary,
            size: 20,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: GLuxurySpacing.horizontalXl,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GLuxurySpacing.gapXl,
                const Center(
                  child: GraziaLogo(
                    variant: GraziaLogoVariant.full,
                    height: 80,
                    enableGlow: true,
                  ),
                ),
                GLuxurySpacing.gapXxl,
                Text(
                  _emailSent ? 'Check Your Inbox' : 'Reset Password',
                  style: GLuxuryTypography.h1.copyWith(
                    fontSize: 32,
                    color: palette.textPrimary,
                  ),
                ),
                GLuxurySpacing.gapSm,
                Text(
                  _emailSent
                      ? 'We have sent a secure password recovery link to ${_emailController.text}. Please check your email.'
                      : 'Enter your registered architectural account email to receive recovery instructions.',
                  style: GLuxuryTypography.bodyLarge.copyWith(
                    color: palette.textSecondary,
                    height: 1.5,
                  ),
                ),
                GLuxurySpacing.gapXxl,
                if (!_emailSent) ...[
                  GraziaTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: Validators.email,
                  ),
                  GLuxurySpacing.gapXl,
                  GraziaButton(
                    label: 'Send Recovery Email',
                    icon: Icons.send_rounded,
                    onPressed: _isLoading ? null : _sendResetEmail,
                    isLoading: _isLoading,
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mark_email_read_outlined, color: palette.primary, size: 28),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Follow the instructions in the email to set a new password, then return here to log in.',
                            style: GLuxuryTypography.bodyMedium.copyWith(
                              color: palette.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  GLuxurySpacing.gapXl,
                  GraziaButton(
                    label: 'Back to Login',
                    icon: Icons.login_rounded,
                    onPressed: () => context.go('/login'),
                  ),
                ],
                GLuxurySpacing.gapXl,
                Center(
                  child: TextButton.icon(
                    onPressed: () => context.push('/help'),
                    icon: Icon(Icons.headset_mic_outlined, size: 16, color: palette.textTertiary),
                    label: Text(
                      'Need help recovering your account? Contact Concierge',
                      style: GLuxuryTypography.bodySmall.copyWith(
                        color: palette.textTertiary,
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

