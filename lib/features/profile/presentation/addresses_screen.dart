import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key});

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _addresses = [];

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userRepo = ref.read(userRepositoryProvider);
      final addresses = await userRepo.getAddresses();

      if (mounted) {
        setState(() {
          _addresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addresses = [];
          _error = null;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.deleteAddress(addressId);

      if (mounted) {
        showSuccessSnackbar(context, 'Address deleted successfully');
        _loadAddresses();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
      }
    }
  }

  void _showAddressDialog({Map<String, dynamic>? address, required LuxuryPalette palette}) {
    final isEditing = address != null;
    final nameCtrl = TextEditingController(text: address?['name'] ?? '');
    final phoneCtrl = TextEditingController(text: address?['phone'] ?? '');
    final addr1Ctrl = TextEditingController(text: address?['address_line1'] ?? '');
    final addr2Ctrl = TextEditingController(text: address?['address_line2'] ?? '');
    final cityCtrl = TextEditingController(text: address?['city'] ?? '');
    final stateCtrl = TextEditingController(text: address?['state'] ?? 'Uttar Pradesh');
    final pinCtrl = TextEditingController(text: address?['pincode'] ?? '');
    String label = address?['label'] ?? 'Home';
    bool isDefault = address?['is_default'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            isEditing ? 'Edit Address' : 'New Delivery Address',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: palette.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(labelText: 'Contact Person / Name', labelStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneCtrl,
                  style: TextStyle(color: palette.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: 'Contact Phone Number', labelStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addr1Ctrl,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(labelText: 'Address Line 1 (Flat / Plot / Street)', labelStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addr2Ctrl,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(labelText: 'Address Line 2 (Landmark / Area)', labelStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: cityCtrl,
                        style: TextStyle(color: palette.textPrimary),
                        decoration: InputDecoration(labelText: 'City', labelStyle: TextStyle(color: palette.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: pinCtrl,
                        style: TextStyle(color: palette.textPrimary),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: 'Pincode', labelStyle: TextStyle(color: palette.textSecondary)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: stateCtrl,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(labelText: 'State', labelStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text('Set as Default Address', style: TextStyle(color: palette.textPrimary, fontSize: 13)),
                  value: isDefault,
                  activeColor: palette.primary,
                  onChanged: (v) => setDialogState(() => isDefault = v ?? false),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: palette.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty || addr1Ctrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                try {
                  final userRepo = ref.read(userRepositoryProvider);
                  if (isEditing) {
                    await userRepo.updateAddress(
                      addressId: address['id'] ?? '',
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      addressLine1: addr1Ctrl.text.trim(),
                      addressLine2: addr2Ctrl.text.trim(),
                      city: cityCtrl.text.trim(),
                      state: stateCtrl.text.trim(),
                      pincode: pinCtrl.text.trim(),
                      label: label,
                      isDefault: isDefault,
                    );
                  } else {
                    await userRepo.addAddress(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      addressLine1: addr1Ctrl.text.trim(),
                      addressLine2: addr2Ctrl.text.trim(),
                      city: cityCtrl.text.trim(),
                      state: stateCtrl.text.trim(),
                      pincode: pinCtrl.text.trim(),
                      label: label,
                      isDefault: isDefault,
                    );
                  }

                  if (mounted) {
                    showSuccessSnackbar(context, isEditing ? 'Address updated' : 'Address added');
                    _loadAddresses();
                  }
                } catch (e) {
                  if (mounted) showErrorSnackbar(context, e);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setDefaultAddress(String addressId) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.setDefaultAddress(addressId);

      if (mounted) {
        showSuccessSnackbar(context, 'Default address updated');
        _loadAddresses();
      }
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
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
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          'Delivery Addresses',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: _error != null
          ? ErrorHandlerWidget(
              error: Exception(_error),
              onRetry: _loadAddresses,
            )
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : _addresses.isEmpty
                  ? _buildEmptyState(palette)
                  : RefreshIndicator(
                      color: palette.primary,
                      backgroundColor: palette.surface,
                      onRefresh: _loadAddresses,
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          final address = _addresses[index];
                          return _buildAddressCard(palette, address);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressDialog(palette: palette),
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_location_alt_outlined, size: 18),
        label: Text('Add New Address', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: palette.surfaceDark,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.location_on_outlined, size: 40, color: palette.textTertiary),
          ),
          const SizedBox(height: 20),
          Text(
            'No Saved Addresses',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add site and office destinations for\nstreamlined sample and slab dispatch.',
            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddressDialog(palette: palette),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Delivery Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(LuxuryPalette palette, Map<String, dynamic> address) {
    final isDefault = address['is_default'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? palette.primary : palette.border,
          width: isDefault ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      address['name'] ?? 'Address',
                      style: GoogleFonts.inter(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'DEFAULT',
                          style: GoogleFonts.inter(
                            color: palette.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: palette.textTertiary, size: 20),
                color: palette.surface,
                onSelected: (value) {
                  if (value == 'edit') {
                    _showAddressDialog(address: address, palette: palette);
                  } else if (value == 'delete') {
                    _showDeleteDialog(address['id'] ?? '', palette);
                  } else if (value == 'default') {
                    _setDefaultAddress(address['id'] ?? '');
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: palette.textPrimary),
                        const SizedBox(width: 12),
                        Text('Edit', style: TextStyle(color: palette.textPrimary)),
                      ],
                    ),
                  ),
                  if (!isDefault)
                    PopupMenuItem(
                      value: 'default',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline, size: 18, color: palette.textPrimary),
                          const SizedBox(width: 12),
                          Text('Set as Default', style: TextStyle(color: palette.textPrimary)),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 12),
                        const Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${address['address_line1'] ?? ''}${address['address_line2'] != null && address['address_line2'] != '' ? ', ${address['address_line2']}' : ''}',
            style: GoogleFonts.inter(
              color: palette.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}',
            style: GoogleFonts.inter(
              color: palette.textSecondary,
              fontSize: 12,
            ),
          ),
          if (address['phone'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 14, color: palette.textTertiary),
                const SizedBox(width: 6),
                Text(
                  address['phone'],
                  style: GoogleFonts.inter(
                    color: palette.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(String addressId, LuxuryPalette palette) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Delete Address?',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this address? This action cannot be undone.',
          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAddress(addressId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

