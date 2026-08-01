import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_strings.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // ── Brand Header ──
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.goldGradient.createShader(bounds),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                _otpSent ? 'Verify OTP' : AppStrings.loginTitle,
                style: GraziaTextStyles.h3,
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter the OTP sent to ${_phoneController.text}'
                    : AppStrings.loginSubtitle,
                style: GraziaTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              // ── Phone Input ──
              if (!_otpSent) ...[
                GraziaTextField(
                  label: AppStrings.phoneLabel,
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  prefix: Text(
                    '+91 ',
                    style: GraziaTextStyles.bodyMedium
                        .copyWith(color: AppColors.goldWarm),
                  ),
                  validator: (v) =>
                      (v == null || v.length != 10) ? 'Enter valid phone' : null,
                ),
                const SizedBox(height: 32),
                // ── Login Button ──
                GraziaButton(
                  label: AppStrings.loginButton,
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (_phoneController.text.length == 10) {
                      setState(() => _otpSent = true);
                    }
                  },
                ),
              ] else ...[
                // ── OTP Input ──
                GraziaTextField(
                  label: AppStrings.otpLabel,
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 32),
                GraziaButton(
                  label: AppStrings.verifyButton,
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    // TODO: Verify OTP, navigate to home
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _otpSent = false),
                    child: Text(
                      AppStrings.changeNumber,
                      style: GraziaTextStyles.bodySmall.copyWith(
                        color: AppColors.goldWarm,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 48),
              // ── Guest Access ──
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/home');
                  },
                  child: Text(
                    'Continue as Guest',
                    style: GraziaTextStyles.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
