import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';

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

  Future<String?> _showAddressSheet({Map<String, dynamic>? address, required LuxuryPalette palette}) async {
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
    bool isSaving = false;
    String? validationError;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.88,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: palette.border),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grab handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEditing ? 'Edit Address' : 'New Delivery Address',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: palette.textSecondary, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Scrollable form
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (validationError != null) ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: palette.error.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: palette.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, color: palette.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      validationError!,
                                      style: GoogleFonts.inter(color: palette.error, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          TextField(
                            controller: nameCtrl,
                            style: TextStyle(color: palette.textPrimary, fontSize: 14),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'Contact Person / Site Name *',
                              labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phoneCtrl,
                            style: TextStyle(color: palette.textPrimary, fontSize: 14),
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: 'Contact Phone Number *',
                              labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: addr1Ctrl,
                            style: TextStyle(color: palette.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Address Line 1 (Flat / Plot / Street) *',
                              labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: addr2Ctrl,
                            style: TextStyle(color: palette.textPrimary, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Address Line 2 (Landmark / Area)',
                              labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: cityCtrl,
                                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                                  textCapitalization: TextCapitalization.words,
                                  decoration: InputDecoration(
                                    labelText: 'City *',
                                    labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: pinCtrl,
                                  style: TextStyle(color: palette.textPrimary, fontSize: 14),
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Pincode *',
                                    labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: stateCtrl,
                            style: TextStyle(color: palette.textPrimary, fontSize: 14),
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: 'State',
                              labelStyle: TextStyle(color: palette.textSecondary, fontSize: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            title: Text('Set as Default Destination', style: TextStyle(color: palette.textPrimary, fontSize: 13)),
                            value: isDefault,
                            activeColor: palette.primary,
                            onChanged: (v) => setSheetState(() => isDefault = v ?? false),
                            contentPadding: EdgeInsets.zero,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    side: BorderSide(color: palette.border),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text('Cancel', style: TextStyle(color: palette.textSecondary, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (nameCtrl.text.trim().isEmpty ||
                                              phoneCtrl.text.trim().isEmpty ||
                                              addr1Ctrl.text.trim().isEmpty ||
                                              cityCtrl.text.trim().isEmpty ||
                                              pinCtrl.text.trim().isEmpty) {
                                            setSheetState(() => validationError = 'Please fill all required (*) fields.');
                                            return;
                                          }
                                          setSheetState(() {
                                            isSaving = true;
                                            validationError = null;
                                          });

                                          try {
                                            final userRepo = ref.read(userRepositoryProvider);
                                            String savedId = address?['id'] ?? '';
                                            if (isEditing) {
                                              await userRepo.updateAddress(
                                                addressId: savedId,
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
                                              final created = await userRepo.addAddress(
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
                                              savedId = created['id']?.toString() ?? '';
                                            }

                                            if (!mounted) return;
                                            if (ctx.mounted) {
                                              Navigator.pop(ctx, savedId);
                                            }
                                            LuxuryToast.show(
                                              context,
                                              message: isEditing ? 'Address updated' : 'Address added successfully',
                                            );
                                            await _loadAddresses();
                                          } catch (e) {
                                            if (sheetContext.mounted) {
                                              setSheetState(() {
                                                isSaving = false;
                                                validationError = e.toString();
                                              });
                                            }
                                          }
                                        },
                                  child: isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text('Save Address', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
      floatingActionButton: _addresses.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showAddressSheet(palette: palette),
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: Text('Add New Address', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            )
          : null,
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
            onPressed: () async {
              final newId = await _showAddressSheet(palette: palette);
              if (newId != null && mounted) {
                context.pop(newId);
              }
            },
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
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDefault ? palette.primary : palette.border,
          width: isDefault ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Return selected address ID to caller
            context.pop(address['id']?.toString());
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                    _showAddressSheet(address: address, palette: palette);
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
    ),
  ),
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

