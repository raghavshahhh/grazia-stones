import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/shared/widgets/grazia_logo.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';

/// Opened by the password-reset email link (graziastones:///reset-password?code=...). supabase_flutter exchanges
/// the code for a recovery session; this screen then sets the new password with updateUser.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (SupabaseService.instance.currentUser == null) {
      showErrorSnackbar(
        context,
        null,
        customMessage:
            'This reset link is invalid or has expired. Please request a new one.',
      );
      return;
    }
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(authRiverpodProvider.notifier)
          .updatePassword(_passwordController.text);
      if (!mounted) return;
      showSuccessSnackbar(context, 'Your password has been updated.');
      context.go(
        ref.read(authRiverpodProvider).isLoggedIn ? '/home' : '/login',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dark screen: light status-bar icons (they were dark on near-black).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D0C),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: GraziaLogo(
                      variant: GraziaLogoVariant.full,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Set a New Password',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose a new password for your Grazia Stones account.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  GraziaTextField(
                    label: 'New Password (min. 6 characters)',
                    controller: _passwordController,
                    obscure: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please enter a password';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  GraziaTextField(
                    label: 'Confirm Password',
                    controller: _confirmController,
                    obscure: true,
                    prefixIcon: Icons.lock_reset_rounded,
                    validator: (v) => v != _passwordController.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 22),
                  GraziaButton(
                    label: 'Update Password',
                    icon: Icons.check_rounded,
                    onPressed: _isLoading ? null : _submit,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      child: Text(
                        'Link expired? Request a new one',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
