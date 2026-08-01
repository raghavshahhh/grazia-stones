import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_text_field.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/config/routes.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();
  final _otpController = TextEditingController();
  bool _otpSent = false;
  bool _isArchitect = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
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
              const SizedBox(height: 40),
              // ── Brand Header ──
              Center(
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.goldGradient.createShader(bounds),
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                _otpSent ? 'Verify OTP' : 'Create Account',
                style: GraziaTextStyles.h3,
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter the OTP sent to +91 ${_phoneController.text}'
                    : 'Join Grazia Stones to explore premium natural stones',
                style: GraziaTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              if (!_otpSent) ...[
                // ── Name ──
                GraziaTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  prefix: const Icon(Icons.person_outline, size: 20),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name required' : null,
                ),
                const SizedBox(height: 20),

                // ── Phone ──
                GraziaTextField(
                  label: 'Phone Number',
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
                const SizedBox(height: 20),

                // ── Email ──
                GraziaTextField(
                  label: 'Email (optional)',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefix: const Icon(Icons.email_outlined, size: 20),
                ),
                const SizedBox(height: 20),

                // ── Company ──
                GraziaTextField(
                  label: 'Company / Firm (optional)',
                  controller: _companyController,
                  prefix: const Icon(Icons.business_outlined, size: 20),
                ),
                const SizedBox(height: 20),

                // ── Architect toggle ──
                Row(
                  children: [
                    Checkbox(
                      value: _isArchitect,
                      onChanged: (v) => setState(() => _isArchitect = v ?? false),
                      activeColor: AppColors.gold,
                      checkColor: AppColors.charcoal,
                    ),
                    Expanded(
                      child: Text(
                        'I am an Architect / Interior Designer',
                        style: GraziaTextStyles.bodyMedium.copyWith(
                          color: AppColors.silver,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Register Button ──
                GraziaButton(
                  label: 'Send OTP',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () {
                    if (_phoneController.text.length == 10 &&
                        _nameController.text.trim().isNotEmpty) {
                      setState(() => _otpSent = true);
                    }
                  },
                ),
              ] else ...[
                // ── OTP Input ──
                GraziaTextField(
                  label: 'Enter 6-digit OTP',
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 28),
                GraziaButton(
                  label: 'Verify & Create Account',
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    // TODO: Verify OTP, create account
                    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
                  },
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => _otpSent = false),
                    child: Text(
                      'Change Number',
                      style: GraziaTextStyles.bodySmall.copyWith(
                        color: AppColors.goldWarm,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Login link ──
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: GraziaTextStyles.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      children: [
                        TextSpan(
                          text: 'Log In',
                          style: GraziaTextStyles.bodyMedium.copyWith(
                            color: AppColors.goldWarm,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
