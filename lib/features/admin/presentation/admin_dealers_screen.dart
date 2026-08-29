import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/dealer.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class AdminDealersScreen extends ConsumerStatefulWidget {
  const AdminDealersScreen({super.key});

  @override
  ConsumerState<AdminDealersScreen> createState() => _AdminDealersScreenState();
}

class _AdminDealersScreenState extends ConsumerState<AdminDealersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Dealer> _dealers = [];

  @override
  void initState() {
    super.initState();
    _loadDealers();
  }

  Future<void> _loadDealers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final dealerRepo = ref.read(dealerRepositoryProvider);
      final dealers = await dealerRepo.getDealers();

      if (mounted) {
        setState(() {
          _dealers = dealers;
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

  void _showDealerDialog({Dealer? dealer, required LuxuryPalette palette}) {
    final nameCtrl = TextEditingController(text: dealer?.name ?? '');
    final addrCtrl = TextEditingController(text: dealer?.address ?? '');
    final cityCtrl = TextEditingController(text: dealer?.city ?? '');
    final stateCtrl = TextEditingController(text: dealer?.state ?? 'Maharashtra');
    final pinCtrl = TextEditingController(text: dealer?.pincode ?? '');
    final phoneCtrl = TextEditingController(text: dealer?.phone ?? '');
    final emailCtrl = TextEditingController(text: dealer?.email ?? '');
    final ratingCtrl = TextEditingController(text: dealer?.rating.toString() ?? '4.8');
    bool isExclusive = dealer?.isExclusive ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            dealer != null ? 'Edit Dealer / Showroom' : 'New Dealer',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: palette.textPrimary),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(labelText: 'Dealer Name', labelStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addrCtrl,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(labelText: 'Full Address', labelStyle: TextStyle(color: palette.textSecondary)),
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
                        decoration: InputDecoration(labelText: 'Pincode', labelStyle: TextStyle(color: palette.textSecondary)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: phoneCtrl,
                        style: TextStyle(color: palette.textPrimary),
                        decoration: InputDecoration(labelText: 'Phone', labelStyle: TextStyle(color: palette.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ratingCtrl,
                        style: TextStyle(color: palette.textPrimary),
                        decoration: InputDecoration(labelText: 'Rating (0-5)', labelStyle: TextStyle(color: palette.textSecondary)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  style: TextStyle(color: palette.textPrimary),
                  decoration: InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: palette.textSecondary)),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  title: Text('Exclusive Experience Center', style: TextStyle(color: palette.textPrimary, fontSize: 13)),
                  value: isExclusive,
                  activeColor: palette.primary,
                  onChanged: (v) => setDialogState(() => isExclusive = v ?? true),
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
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                try {
                  final client = SupabaseService.instance.client;
                  final data = {
                    'name': nameCtrl.text.trim(),
                    'address': addrCtrl.text.trim(),
                    'city': cityCtrl.text.trim(),
                    'state': stateCtrl.text.trim(),
                    'pincode': pinCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null,
                    'rating': double.tryParse(ratingCtrl.text.trim()) ?? 4.8,
                    'is_exclusive': isExclusive,
                    'active': true,
                  };

                  if (dealer != null) {
                    await client.from('dealers').update(data).eq('id', dealer.id);
                  } else {
                    await client.from('dealers').insert(data);
                  }

                  if (mounted) {
                    showSuccessSnackbar(context, 'Dealer saved successfully');
                    _loadDealers();
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

  Future<void> _deleteDealer(String id) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('dealers').delete().eq('id', id);

      if (mounted) {
        showSuccessSnackbar(context, 'Dealer removed');
        _loadDealers();
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
          'Manage Dealers (${_dealers.length})',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadDealers)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : RefreshIndicator(
                  color: palette.primary,
                  backgroundColor: palette.surface,
                  onRefresh: _loadDealers,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    itemCount: _dealers.length,
                    itemBuilder: (context, i) {
                      final d = _dealers[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: palette.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.storefront_outlined, color: palette.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name,
                                    style: GoogleFonts.playfairDisplay(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${d.city}, ${d.state} • ${d.phone}',
                                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '★ ${d.rating} • ${d.isExclusive ? "Exclusive Experience Center" : "Partner Store"}',
                                    style: GoogleFonts.inter(color: palette.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: palette.primary, size: 18),
                              onPressed: () => _showDealerDialog(dealer: d, palette: palette),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              onPressed: () => _deleteDealer(d.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDealerDialog(palette: palette),
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('New Dealer', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
