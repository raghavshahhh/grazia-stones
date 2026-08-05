import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/typography.dart';
import 'package:grazia_stones/shared/theme/spacing.dart';

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
          _error = e.toString();
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
        _loadAddresses(); // Reload list
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = GLuxuryPalettes.gold;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new, color: palette.textPrimary),
        ),
        title: Text(
          'Saved Addresses',
          style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
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
                        padding: const EdgeInsets.all(16),
                        itemCount: _addresses.length,
                        itemBuilder: (context, index) {
                          final address = _addresses[index];
                          return _buildAddressCard(palette, address);
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to add address screen
          showInfoSnackbar(context, 'Add address screen coming soon');
        },
        backgroundColor: palette.primary,
        icon: const Icon(Icons.add),
        label: const Text('Add Address'),
      ),
    );
  }

  Widget _buildEmptyState(LuxuryPalette palette) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_on_outlined,
            size: 80,
            color: palette.textTertiary.withValues(alpha: 0.3),
          ),
          GLuxurySpacing.gapBase,
          Text(
            'No saved addresses',
            style: GLuxuryTypography.h2.copyWith(color: palette.textPrimary),
          ),
          GLuxurySpacing.gapSm,
          Text(
            'Add your delivery addresses for faster checkout',
            style: GLuxuryTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          GLuxurySpacing.gapXl,
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to add address screen
              showInfoSnackbar(context, 'Add address screen coming soon');
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: palette.background,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          width: isDefault ? 2 : 1,
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
                      style: GLuxuryTypography.h3.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Default',
                          style: GLuxuryTypography.labelSmall.copyWith(
                            color: palette.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: palette.textTertiary),
                color: palette.surface,
                onSelected: (value) {
                  if (value == 'edit') {
                    // TODO: Navigate to edit address screen
                    showInfoSnackbar(context, 'Edit address coming soon');
                  } else if (value == 'delete') {
                    _showDeleteDialog(address['id'] ?? '');
                  } else if (value == 'default') {
                    // TODO: Set as default
                    showInfoSnackbar(context, 'Set default coming soon');
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
                          Icon(Icons.check_circle_outline,
                              size: 18, color: palette.textPrimary),
                          const SizedBox(width: 12),
                          Text('Set as Default',
                              style: TextStyle(color: palette.textPrimary)),
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
            '${address['address_line1'] ?? ''}${address['address_line2'] != null ? ', ${address['address_line2']}' : ''}',
            style: GLuxuryTypography.bodyMedium.copyWith(
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${address['city'] ?? ''}, ${address['state'] ?? ''} - ${address['pincode'] ?? ''}',
            style: GLuxuryTypography.bodySmall.copyWith(
              color: palette.textSecondary,
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
                  style: GLuxuryTypography.bodySmall.copyWith(
                    color: palette.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(String addressId) {
    final palette = GLuxuryPalettes.gold;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Delete Address?',
          style: GLuxuryTypography.h3.copyWith(color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this address? This action cannot be undone.',
          style: GLuxuryTypography.bodyMedium.copyWith(
            color: palette.textSecondary,
          ),
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
