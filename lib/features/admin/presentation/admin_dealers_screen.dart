import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/dealer.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/admin/presentation/widgets/admin_module_switcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDealersScreen extends ConsumerStatefulWidget {
  const AdminDealersScreen({super.key});

  @override
  ConsumerState<AdminDealersScreen> createState() => _AdminDealersScreenState();
}

class _AdminDealersScreenState extends ConsumerState<AdminDealersScreen> {
  bool _isLoading = true;
  String? _error;
  List<Dealer> _dealers = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDealers();
  }

  Future<void> _launchCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final url = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        if (mounted) LuxuryToast.show(context, message: 'Could not place call to $phone', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not place call', isError: true);
    }
  }

  Future<void> _openMap(Dealer dealer) async {
    final query = Uri.encodeComponent('${dealer.name}, ${dealer.address}, ${dealer.city}');
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) LuxuryToast.show(context, message: 'Could not open Maps', isError: true);
      }
    } catch (_) {
      if (mounted) LuxuryToast.show(context, message: 'Could not open Maps', isError: true);
    }
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
        builder: (dContext, setDialogState) => AlertDialog(
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
                    LuxuryToast.show(context, message: 'Dealer saved successfully');
                    _loadDealers();
                  }
                } catch (e) {
                  if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDealer(Dealer dealer, LuxuryPalette palette) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          'Delete Dealer',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${dealer.name}" from authorized dealers?',
          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteDealer(dealer.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDealer(String id) async {
    try {
      final client = SupabaseService.instance.client;
      await client.from('dealers').delete().eq('id', id);

      if (mounted) {
        LuxuryToast.show(context, message: 'Dealer removed');
        _loadDealers();
      }
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString(), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final query = _searchQuery.trim().toLowerCase();

    final filteredDealers = _dealers.where((d) {
      if (query.isEmpty) return true;
      return d.name.toLowerCase().contains(query) ||
          d.city.toLowerCase().contains(query) ||
          d.state.toLowerCase().contains(query) ||
          d.address.toLowerCase().contains(query) ||
          d.phone.toLowerCase().contains(query) ||
          d.email.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/admin/dashboard');
            }
          },
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
        actions: [
          IconButton(
            tooltip: 'Refresh Dealers',
            onPressed: () {
              HapticFeedback.lightImpact();
              _loadDealers();
            },
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
          AdminQuickNavButton(
            currentRoute: '/admin/dealers',
            palette: palette,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadDealers)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Column(
                      children: [
                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            style: GoogleFonts.inter(color: palette.textPrimary, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search dealers by name, city, state, or phone...',
                              hintStyle: GoogleFonts.inter(color: palette.textTertiary, fontSize: 13),
                              prefixIcon: Icon(Icons.search_rounded, color: palette.textSecondary, size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear_rounded, color: palette.textSecondary, size: 18),
                                      onPressed: () => setState(() => _searchQuery = ''),
                                    )
                                  : null,
                              filled: true,
                              fillColor: palette.surface,
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: palette.primary, width: 1.5),
                              ),
                            ),
                          ),
                        ),

                        Expanded(
                          child: filteredDealers.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.storefront_outlined, color: palette.textTertiary, size: 48),
                                      const SizedBox(height: 12),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No dealers matching "$_searchQuery"'
                                            : 'No dealers registered yet',
                                        style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  color: palette.primary,
                                  backgroundColor: palette.surface,
                                  onRefresh: _loadDealers,
                                  child: ListView.builder(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                    itemCount: filteredDealers.length,
                                    itemBuilder: (context, i) {
                                      final d = filteredDealers[i];
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        decoration: BoxDecoration(
                                          color: palette.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: palette.border),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () => _showDealerDialog(dealer: d, palette: palette),
                                            child: Padding(
                                              padding: const EdgeInsets.all(14),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Container(
                                                        width: 44,
                                                        height: 44,
                                                        decoration: BoxDecoration(
                                                          color: palette.primary.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Icon(Icons.storefront_outlined, color: palette.primary),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    d.name,
                                                                    style: GoogleFonts.playfairDisplay(
                                                                      color: palette.textPrimary,
                                                                      fontWeight: FontWeight.w700,
                                                                      fontSize: 16,
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow: TextOverflow.ellipsis,
                                                                  ),
                                                                ),
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                  decoration: BoxDecoration(
                                                                    color: (d.isExclusive ? palette.primary : palette.textTertiary)
                                                                        .withValues(alpha: 0.15),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: Text(
                                                                    d.isExclusive ? 'Exclusive Center' : 'Partner',
                                                                    style: GoogleFonts.inter(
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.w700,
                                                                      color: d.isExclusive ? palette.primary : palette.textSecondary,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Text(
                                                              '${d.address}, ${d.city}, ${d.state} ${d.pincode.isNotEmpty ? "- ${d.pincode}" : ""}',
                                                              style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              children: [
                                                                Text(
                                                                  '★ ${d.rating}',
                                                                  style: GoogleFonts.inter(
                                                                    color: Colors.amber.shade700,
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                                if (d.phone.isNotEmpty) ...[
                                                                  Text(' • ', style: TextStyle(color: palette.textTertiary)),
                                                                  Text(
                                                                    d.phone,
                                                                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 11),
                                                                  ),
                                                                ],
                                                                if (d.email.isNotEmpty) ...[
                                                                  Text(' • ', style: TextStyle(color: palette.textTertiary)),
                                                                  Expanded(
                                                                    child: Text(
                                                                      d.email,
                                                                      maxLines: 1,
                                                                      overflow: TextOverflow.ellipsis,
                                                                      style: GoogleFonts.inter(color: palette.textTertiary, fontSize: 11),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  const Divider(height: 1),
                                                  const SizedBox(height: 6),
                                                  // Quick Action Toolbar
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      if (d.phone.isNotEmpty)
                                                        OutlinedButton.icon(
                                                          style: OutlinedButton.styleFrom(
                                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                            side: BorderSide(color: palette.border),
                                                          ),
                                                          onPressed: () => _launchCall(d.phone),
                                                          icon: const Icon(Icons.phone_rounded, size: 13, color: Colors.blue),
                                                          label: Text('Call', style: GoogleFonts.inter(fontSize: 11, color: palette.textPrimary)),
                                                        ),
                                                      const SizedBox(width: 8),
                                                      OutlinedButton.icon(
                                                        style: OutlinedButton.styleFrom(
                                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                          side: BorderSide(color: palette.border),
                                                        ),
                                                        onPressed: () => _openMap(d),
                                                        icon: Icon(Icons.map_outlined, size: 13, color: palette.primary),
                                                        label: Text('Directions', style: GoogleFonts.inter(fontSize: 11, color: palette.textPrimary)),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      IconButton(
                                                        icon: Icon(Icons.edit_outlined, color: palette.primary, size: 18),
                                                        tooltip: 'Edit Dealer',
                                                        visualDensity: VisualDensity.compact,
                                                        onPressed: () => _showDealerDialog(dealer: d, palette: palette),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 18),
                                                        tooltip: 'Delete Dealer',
                                                        visualDensity: VisualDensity.compact,
                                                        onPressed: () => _confirmDeleteDealer(d, palette),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
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
