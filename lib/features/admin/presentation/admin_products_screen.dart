import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/utils/formatters.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/features/admin/presentation/admin_product_form.dart';
import 'package:grazia_stones/features/admin/presentation/widgets/admin_module_switcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

enum ProductDeleteChoice { hide, delete }

/// Hide (preferred, reversible) or permanently delete. Permanent delete asks a second time.
Future<ProductDeleteChoice?> confirmProductDelete(
  BuildContext context,
  LuxuryPalette palette,
  String name, {
  required bool isActive,
}) async {
  final choice = await showDialog<ProductDeleteChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surface,
      title: Text('Remove "$name"?',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 18, color: palette.textPrimary)),
      content: Text(
        isActive
            ? 'Hiding takes it out of the catalogue but keeps it here, so you can show it again later. Deleting removes it and its uploaded photos for good.'
            : 'It is already hidden from the catalogue. Deleting removes it and its uploaded photos for good.',
        style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: palette.textSecondary),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: GoogleFonts.inter(color: palette.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, ProductDeleteChoice.delete),
          child: Text('Delete', style: GoogleFonts.inter(color: palette.error, fontWeight: FontWeight.w600)),
        ),
        if (isActive)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, ProductDeleteChoice.hide),
            child: const Text('Hide'),
          ),
      ],
    ),
  );
  if (choice != ProductDeleteChoice.delete || !context.mounted) return choice;
  final sure = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: palette.surface,
      title: Text('Delete permanently?',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, fontSize: 18, color: palette.textPrimary)),
      content: Text('"$name" will be removed from the database. This cannot be undone.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.45, color: palette.textSecondary)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep', style: GoogleFonts.inter(color: palette.textSecondary))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: palette.error, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete forever'),
        ),
      ],
    ),
  );
  return sure == true ? ProductDeleteChoice.delete : null;
}

class AdminProductsScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const AdminProductsScreen({super.key, this.initialStatus});

  @override
  ConsumerState<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends ConsumerState<AdminProductsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Stone> _stones = [];
  String _query = '';
  String? _collection; // null = all collections
  late String _status; // 'all' | 'active' | 'archived'
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _status = const {'active', 'archived'}.contains(widget.initialStatus) ? widget.initialStatus! : 'all';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _stones.isEmpty;
      _error = null;
    });
    try {
      // Admin listing includes hidden (active=false) rows; RLS still hides them from customers.
      final stones = await ref.read(adminProductRepositoryProvider).getAllProductsAdmin();
      if (mounted) {
        setState(() {
          _stones = stones;
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

  Future<void> _open(String? id, [Stone? stone]) async {
    HapticFeedback.lightImpact();
    final changed = await context.push(id == null ? '/admin/products/add' : '/admin/products/edit/$id', extra: stone);
    if (changed == true) _load();
  }

  Future<void> _toggleActive(Stone s, bool active) async {
    final err = ProductForm.images(s.images.length, active: active);
    if (err != null) {
      LuxuryToast.show(context, message: err, isError: true);
      return;
    }
    setState(() => _busy.add(s.id));
    try {
      await ref.read(adminProductRepositoryProvider).setActive(s.id, active);
      if (!mounted) return;
      LuxuryToast.show(context, message: active ? '${s.name} is live' : '${s.name} hidden from catalogue');
      await _load();
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  Future<void> _remove(Stone s, LuxuryPalette palette) async {
    final choice = await confirmProductDelete(context, palette, s.name, isActive: s.isActive);
    if (choice == null) return;
    if (choice == ProductDeleteChoice.hide) return _toggleActive(s, false);
    setState(() => _busy.add(s.id));
    try {
      await ref.read(adminProductRepositoryProvider).permanentlyDeleteProduct(s.id);
      if (!mounted) return;
      LuxuryToast.show(context, message: '${s.name} deleted');
      await _load();
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _busy.remove(s.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final live = _stones.where((s) => s.isActive).length;
    final collections = {for (final s in _stones) if (s.collection.isNotEmpty) s.collection}.toList()..sort();
    final q = _query.trim().toLowerCase();
    final shown = _stones.where((s) {
      if (_status == 'active' && !s.isActive) return false;
      if (_status == 'archived' && s.isActive) return false;
      if (_collection != null && s.collection != _collection) return false;
      if (q.isEmpty) return true;
      return '${s.name} ${s.productCode} ${s.collection} ${s.category}'.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin/dashboard'),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text('Products',
            style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary)),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: Icon(Icons.refresh_rounded, color: palette.primary),
          ),
          AdminQuickNavButton(currentRoute: '/admin/products', palette: palette),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(null),
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text('Add product', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _load)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                          child: TextField(
                            onChanged: (v) => setState(() => _query = v),
                            style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
                            decoration: _inputDecoration(palette, 'Search name, code, collection',
                                prefix: Icon(Icons.search_rounded, color: palette.textTertiary, size: 20)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              _statusChip(palette, 'All', 'all', _stones.length),
                              const SizedBox(width: 6),
                              _statusChip(palette, 'Live', 'active', live),
                              const SizedBox(width: 6),
                              _statusChip(palette, 'Hidden', 'archived', _stones.length - live),
                              const SizedBox(width: 8),
                              Expanded(child: _collectionMenu(palette, collections)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: RefreshIndicator(
                            color: palette.primary,
                            backgroundColor: palette.surface,
                            onRefresh: _load,
                            child: shown.isEmpty
                                ? ListView(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    children: [_empty(palette)],
                                  )
                                : ListView.separated(
                                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                                    itemCount: shown.length,
                                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) => _tile(palette, shown[i]),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  InputDecoration _inputDecoration(LuxuryPalette palette, String hint, {Widget? prefix}) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 13, color: palette.textTertiary),
      prefixIcon: prefix,
      isDense: true,
      filled: true,
      fillColor: palette.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: b(palette.border),
      enabledBorder: b(palette.border),
      focusedBorder: b(palette.primary, 1.5),
    );
  }

  Widget _statusChip(LuxuryPalette palette, String label, String value, int count) {
    final sel = _status == value;
    return Semantics(
      selected: sel,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _status = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? palette.primary : palette.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: sel ? palette.primary : palette.border),
          ),
          child: Text('$label $count',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w500, color: sel ? Colors.white : palette.textSecondary)),
        ),
      ),
    );
  }

  Widget _collectionMenu(LuxuryPalette palette, List<String> collections) {
    final label = _collection ?? 'All collections';
    return PopupMenuButton<String>(
      tooltip: 'Filter by collection',
      color: palette.surface,
      constraints: const BoxConstraints(maxHeight: 420, minWidth: 220),
      onSelected: (v) => setState(() => _collection = v.isEmpty ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem(value: '', child: Text('All collections', style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary))),
        for (final c in collections)
          PopupMenuItem(
            value: c,
            child: Text(c, style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary, fontWeight: c == _collection ? FontWeight.w700 : FontWeight.w400)),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _collection == null ? palette.surface : palette.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _collection == null ? palette.border : palette.primary),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.textPrimary)),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: palette.textTertiary),
          ],
        ),
      ),
    );
  }

  Widget _empty(LuxuryPalette palette) {
    final filtered = _query.isNotEmpty || _collection != null || _status != 'all';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
      child: Column(
        children: [
          Icon(Icons.diamond_outlined, size: 40, color: palette.textTertiary),
          const SizedBox(height: 10),
          Text(filtered ? 'No products match these filters' : 'No products yet',
              style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          const SizedBox(height: 12),
          if (filtered)
            OutlinedButton(
              onPressed: () => setState(() {
                _query = '';
                _collection = null;
                _status = 'all';
              }),
              child: const Text('Clear filters'),
            )
          else
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: palette.primary),
              onPressed: () => _open(null),
              child: const Text('Add the first product'),
            ),
        ],
      ),
    );
  }

  Widget _tile(LuxuryPalette palette, Stone s) {
    final busy = _busy.contains(s.id);
    final sub = [if (s.productCode.isNotEmpty) s.productCode, if (s.collection.isNotEmpty) s.collection].join('  ·  ');
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _open(s.id, s),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: s.isActive ? 1 : 0.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SmartStoneImage(
                    localAsset: s.images.isNotEmpty ? s.images.first : null,
                    imageUrl: s.imageUrl,
                    width: 52,
                    height: 52,
                    palette: palette,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontSize: 14, fontWeight: FontWeight.w700, color: s.isActive ? palette.textPrimary : palette.textTertiary)),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5, color: palette.textSecondary)),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(s.hasPrice ? '${Formatters.priceTag(s.pricePerSqFt)}/sq ft' : 'Price on request',
                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.primary)),
                        if (s.isFeatured) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star_rounded, size: 13, color: palette.primary),
                        ],
                        if (!s.isActive) ...[
                          const SizedBox(width: 6),
                          Text('Hidden', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.warning)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              busy
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: palette.primary)),
                    )
                  : Tooltip(
                      message: s.isActive ? 'Live — tap to hide' : 'Hidden — tap to show',
                      child: Switch.adaptive(
                        value: s.isActive,
                        activeTrackColor: palette.primary,
                        onChanged: (v) => _toggleActive(s, v),
                      ),
                    ),
              PopupMenuButton<String>(
                tooltip: 'More',
                color: palette.surface,
                icon: Icon(Icons.more_vert_rounded, color: palette.textTertiary, size: 20),
                onSelected: (v) => v == 'edit' ? _open(s.id, s) : _remove(s, palette),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary))),
                  PopupMenuItem(value: 'remove', child: Text('Hide or delete…', style: GoogleFonts.inter(fontSize: 13, color: palette.error))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
