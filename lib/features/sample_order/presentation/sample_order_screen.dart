import 'package:flutter/material.dart';
import 'package:grazia_stones/core/constants/app_colors.dart';
import 'package:grazia_stones/core/constants/app_dimensions.dart';
import 'package:grazia_stones/core/theme/text_styles.dart';
import 'package:grazia_stones/shared/widgets/grazia_button.dart';
import 'package:grazia_stones/shared/widgets/luxury_bottom_sheet.dart';

class SampleOrderScreen extends StatefulWidget {
  const SampleOrderScreen({super.key});

  @override
  State<SampleOrderScreen> createState() => _SampleOrderScreenState();
}

class _SampleOrderScreenState extends State<SampleOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedStone = '';
  bool _isSubmitting = false;

  final List<String> _stones = [
    'Charcoal Black',
    'Ivory Travertine',
    'Nero Marquina',
    'Walnut Brown',
    'Matte White',
    'Slate Grey',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoal,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Request Sample',
          style: GraziaTextStyles.titleMedium.copyWith(color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.goldWarm.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.goldWarm.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.goldWarm, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Get free physical samples delivered to your address. Select up to 3 stones per request.',
                      style: GraziaTextStyles.bodySmall
                          .copyWith(color: AppColors.silver),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stone selection
            Text(
              'Select Stone',
              style: GraziaTextStyles.bodyLarge
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _stones.map((stone) {
                final isSelected = _selectedStone == stone;
                return GestureDetector(
                  onTap: () => setState(() => _selectedStone = stone),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.goldWarm.withValues(alpha: 0.2)
                          : AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppColors.goldWarm : AppColors.slate,
                      ),
                    ),
                    child: Text(
                      stone,
                      style: GraziaTextStyles.bodyMedium.copyWith(
                        color: isSelected ? AppColors.goldWarm : AppColors.silver,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Form fields
            _buildField('Full Name', _nameController, Icons.person_outline),
            const SizedBox(height: 16),
            _buildField(
                'Phone Number', _phoneController, Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildField('Delivery Address', _addressController,
                Icons.location_on_outlined,
                maxLines: 2),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildField(
                      'City', _cityController, Icons.location_city_outlined),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                      'Pincode', _pincodeController, Icons.pin_drop_outlined,
                      keyboardType: TextInputType.number),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildField('Additional Notes', _notesController,
                Icons.note_outlined,
                maxLines: 3, optional: true),
            const SizedBox(height: 24),

            // Submit
            GraziaButton(
              label: _isSubmitting ? 'Submitting...' : 'Request Sample',
              icon: Icons.local_shipping_outlined,
              onPressed: _isSubmitting ? null : _submitForm,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Samples typically arrive within 5-7 business days',
                style:
                    GraziaTextStyles.bodySmall.copyWith(color: AppColors.slate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool optional = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: AppColors.goldWarm),
            const SizedBox(width: 8),
            Text(label,
                style: GraziaTextStyles.bodyMedium
                    .copyWith(color: AppColors.silver)),
            if (optional) ...[
              const SizedBox(width: 4),
              Text('(Optional)',
                  style: GraziaTextStyles.bodySmall
                      .copyWith(color: AppColors.slate)),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GraziaTextStyles.bodyMedium.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: GraziaTextStyles.bodyMedium
                .copyWith(color: AppColors.slate),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.slate),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.goldWarm, width: 1.5),
            ),
          ),
          validator: optional
              ? null
              : (v) =>
                  (v == null || v.isEmpty) ? 'Required field' : null,
        ),
      ],
    );
  }

  Future<void> _submitForm() async {
    if (_selectedStone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a stone')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isSubmitting = false);

    if (mounted) {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => LuxuryBottomSheet(
          title: 'Sample Requested!',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline,
                  color: AppColors.success, size: 64),
              const SizedBox(height: 16),
              Text(
                'Your sample of $_selectedStone has been requested.',
                textAlign: TextAlign.center,
                style: GraziaTextStyles.bodyMedium
                    .copyWith(color: AppColors.silver),
              ),
              const SizedBox(height: 8),
              Text(
                'Estimated delivery: 5-7 business days',
                style: GraziaTextStyles.bodySmall
                    .copyWith(color: AppColors.slate),
              ),
              const SizedBox(height: 24),
              GraziaButton(
                label: 'Done',
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }
  }
}
