import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/repositories/admin_product_repository.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/features/admin/presentation/admin_product_form.dart';
import 'package:grazia_stones/features/admin/presentation/admin_products_screen.dart' show confirmProductDelete, ProductDeleteChoice;
import 'package:grazia_stones/features/admin/presentation/widgets/admin_module_switcher.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';
import 'package:grazia_stones/shared/widgets/smart_stone_image.dart';

/// One photo in the gallery: either already stored ([url]) or picked and waiting for Save ([bytes]).
class _Photo {
  final String? url;
  final Uint8List? bytes;
  final String name;
  _Photo.stored(String this.url) : bytes = null, name = '';
  _Photo.picked(Uint8List this.bytes, this.name) : url = null;
}

class AdminProductEditScreen extends ConsumerStatefulWidget {
  final String? stoneId;
  final Stone? stone; // kept for the router's `extra`; the form always reloads the full row

  const AdminProductEditScreen({super.key, this.stoneId, this.stone});

  @override
  ConsumerState<AdminProductEditScreen> createState() => _AdminProductEditScreenState();
}

class _AdminProductEditScreenState extends ConsumerState<AdminProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _c = {
    for (final k in const [
      'name', 'code', 'slug', 'category', 'short', 'description', 'price', 'length', 'width',
      'thickness', 'coverage', 'finish', 'material', 'colors', 'tags', 'sort',
    ])
      k: TextEditingController(),
  };

  String? _collectionId;
  bool _featured = false;
  bool _active = false;
  final List<_Photo> _photos = [];
  final List<String> _originalImages = [];

  List<Map<String, dynamic>> _collections = [];
  List<String> _categories = [], _finishes = [], _materials = [];

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _photoError;

  bool get _isEditing => widget.stoneId != null && widget.stoneId != 'add';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final client = SupabaseService.instance.client;
      final repo = ref.read(adminProductRepositoryProvider);
      final results = await Future.wait<dynamic>([
        client.from('collections').select('id, name, active').order('name'),
        client.from('stones').select('category, finish, material'),
        if (_isEditing) repo.getProductRow(widget.stoneId!),
      ]);
      _collections = List<Map<String, dynamic>>.from(results[0]);
      List<String> distinct(String k) => {
            for (final r in results[1] as List)
              if ((r[k] ?? '').toString().trim().isNotEmpty) r[k].toString().trim(),
          }.toList()
            ..sort();
      _categories = distinct('category');
      _finishes = distinct('finish');
      _materials = distinct('material');

      if (_isEditing) {
        _applyRow(results[2] as Map<String, dynamic>);
      } else {
        _c['sort']!.text = '0';
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  void _applyRow(Map<String, dynamic> row) {
    String s(String k) => (row[k] ?? '').toString();
    String list(String k) => (row[k] is List) ? (row[k] as List).join(', ') : '';
    _c['name']!.text = s('name');
    _c['code']!.text = s('product_code');
    _c['slug']!.text = s('slug');
    _c['category']!.text = s('category');
    _c['short']!.text = s('short_description');
    _c['description']!.text = s('description');
    final price = (row['price_per_sqft'] as num?) ?? 0;
    _c['price']!.text = price > 0 ? ProductForm.text(price) : '';
    _c['length']!.text = ProductForm.text(row['length_cm']);
    _c['width']!.text = ProductForm.text(row['width_cm']);
    _c['thickness']!.text = ProductForm.text(row['thickness_mm']);
    _c['coverage']!.text = ProductForm.text(row['coverage_sqft']);
    _c['finish']!.text = s('finish');
    _c['material']!.text = s('material');
    _c['colors']!.text = list('colors');
    _c['tags']!.text = list('tags');
    _c['sort']!.text = ((row['sort_order'] as num?) ?? 0).toInt().toString();
    final cid = row['collection_id']?.toString();
    _collectionId = _collections.any((c) => c['id'] == cid) ? cid : null;
    _featured = row['featured'] == true;
    _active = row['active'] == true;
    final images = List<String>.from(row['images'] ?? const []);
    _originalImages.addAll(images);
    _photos.addAll(images.map(_Photo.stored));
  }

  Future<void> _addPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 88, maxWidth: 2400);
    if (picked.isEmpty) return;
    final added = <_Photo>[];
    for (final x in picked) {
      final bytes = await x.readAsBytes();
      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        if (mounted) LuxuryToast.show(context, message: '${x.name} is over 8 MB, pick a smaller photo', isError: true);
        continue;
      }
      added.add(_Photo.picked(bytes, x.name));
    }
    if (!mounted) return;
    setState(() {
      _photos.addAll(added);
      _photoError = null;
    });
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    final photoErr = ProductForm.images(_photos.length, active: _active);
    setState(() => _photoError = photoErr);
    if (!formOk || photoErr != null) {
      LuxuryToast.show(context, message: 'Fix the highlighted fields', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();
    final repo = ref.read(adminProductRepositoryProvider);
    final uploaded = <String>[];
    try {
      final images = <String>[];
      for (final p in _photos) {
        if (p.url != null) {
          images.add(p.url!);
        } else {
          final url = await repo.uploadProductImage(p.bytes!, p.name.isEmpty ? 'photo.jpg' : p.name);
          uploaded.add(url);
          images.add(url);
        }
      }

      final row = ProductForm.row(
        name: _c['name']!.text,
        slug: _c['slug']!.text,
        code: _c['code']!.text,
        collectionId: _collectionId!,
        category: _c['category']!.text,
        shortDescription: _c['short']!.text,
        description: _c['description']!.text,
        price: _c['price']!.text,
        lengthCm: _c['length']!.text,
        widthCm: _c['width']!.text,
        thicknessMm: _c['thickness']!.text,
        coverageSqft: _c['coverage']!.text,
        finish: _c['finish']!.text,
        material: _c['material']!.text,
        colors: _c['colors']!.text,
        tags: _c['tags']!.text,
        sortOrder: _c['sort']!.text,
        featured: _featured,
        active: _active,
        images: images,
      );
      await repo.saveProductRow(row, stoneId: _isEditing ? widget.stoneId : null);

      // Photos removed in this edit: delete only the ones admins uploaded (shared catalogue files stay).
      for (final url in _originalImages.where((u) => !images.contains(u) && AdminProductRepository.isAdminUpload(u))) {
        await repo.deleteProductImage(url);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      LuxuryToast.show(context, message: _isEditing ? 'Product saved' : 'Product added');
      context.pop(true);
    } catch (e) {
      for (final url in uploaded) {
        await repo.deleteProductImage(url); // don't leave orphans behind a failed save
      }
      if (!mounted) return;
      setState(() => _isSaving = false);
      LuxuryToast.show(context, message: _friendlyError(e), isError: true);
    }
  }

  String _friendlyError(Object e) {
    final m = e.toString();
    if (m.contains('stones_slug_key')) return 'Another product already has this name (URL key). Use a different name.';
    if (m.contains('stones_product_code_key')) return 'Another product already uses this product code.';
    if (m.contains('row-level security') || m.contains('permission')) return 'Your account is not allowed to change products.';
    return m.replaceFirst('Exception: ', '');
  }

  Future<void> _delete() async {
    final palette = ref.read(themePaletteProvider);
    final choice = await confirmProductDelete(context, palette, _c['name']!.text, isActive: _active);
    if (choice == null || !mounted) return;
    final repo = ref.read(adminProductRepositoryProvider);
    try {
      if (choice == ProductDeleteChoice.hide) {
        await repo.setActive(widget.stoneId!, false);
      } else {
        await repo.permanentlyDeleteProduct(widget.stoneId!);
      }
      if (!mounted) return;
      LuxuryToast.show(context, message: choice == ProductDeleteChoice.hide ? 'Hidden from catalogue' : 'Product deleted');
      context.pop(true);
    } catch (e) {
      if (mounted) LuxuryToast.show(context, message: _friendlyError(e), isError: true);
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
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/admin/products'),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
        ),
        title: Text(
          _isEditing ? 'Edit product' : 'New product',
          style: GoogleFonts.playfairDisplay(fontSize: 20, fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        actions: [
          if (_isEditing && !_isLoading && _loadError == null)
            IconButton(
              tooltip: 'Hide or delete',
              onPressed: _isSaving ? null : _delete,
              icon: Icon(Icons.delete_outline_rounded, color: palette.error),
            ),
          AdminQuickNavButton(currentRoute: '/admin/products', palette: palette),
          const SizedBox(width: 6),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.primary))
          : _loadError != null
              ? _LoadError(palette: palette, message: _loadError!, onRetry: () {
                  setState(() {
                    _isLoading = true;
                    _loadError = null;
                  });
                  _loadData();
                })
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          _section(palette, 'Photos', [
                            _photoStrip(palette),
                            if (_photoError != null) ...[
                              const SizedBox(height: 6),
                              Text(_photoError!, style: GoogleFonts.inter(fontSize: 12, color: palette.error)),
                            ],
                          ], note: 'First photo is the cover. Long-press and drag to reorder.'),
                          _section(palette, 'Basics', [
                            _field(palette, 'Name', 'name', validator: ProductForm.name),
                            _row([
                              _field(palette, 'Product code', 'code', hint: 'e.g. GL-TA02', validator: ProductForm.code),
                              _field(palette, 'Sort order', 'sort', number: true, integer: true, validator: ProductForm.sortOrder),
                            ]),
                            _collectionField(palette),
                            _field(palette, 'Category', 'category', validator: ProductForm.category, options: _categories),
                          ]),
                          _section(palette, 'Description', [
                            _field(palette, 'Short description', 'short', maxLines: 2,
                                validator: (v) => ProductForm.maxLength(v, ProductForm.shortDescriptionMax)),
                            _field(palette, 'Full description', 'description', maxLines: 5,
                                validator: (v) => ProductForm.maxLength(v, ProductForm.descriptionMax)),
                          ]),
                          _section(palette, 'Size & coverage', [
                            _row([
                              _field(palette, 'Length (cm)', 'length', number: true,
                                  validator: (v) => ProductForm.optionalPositive(v, max: 1000, unit: 'cm')),
                              _field(palette, 'Width (cm)', 'width', number: true,
                                  validator: (v) => ProductForm.optionalPositive(v, max: 1000, unit: 'cm')),
                              _field(palette, 'Thick (mm)', 'thickness', number: true,
                                  validator: (v) => ProductForm.optionalPositive(v, max: 500, unit: 'mm')),
                            ]),
                            _row([
                              _field(palette, 'Coverage (sq ft / box)', 'coverage', number: true,
                                  validator: (v) => ProductForm.optionalPositive(v, max: 1000)),
                              _field(palette, 'Price / sq ft (₹)', 'price', number: true, hint: 'On request',
                                  validator: ProductForm.price),
                            ]),
                          ], note: 'Leave empty what you don\'t know. Empty price shows "Price on request".'),
                          _section(palette, 'Look & search', [
                            _row([
                              _field(palette, 'Finish', 'finish', options: _finishes,
                                  validator: (v) => ProductForm.maxLength(v, 80)),
                              _field(palette, 'Material', 'material', options: _materials,
                                  validator: (v) => ProductForm.maxLength(v, 120)),
                            ]),
                            _field(palette, 'Colours', 'colors', hint: 'Beige, Grey, Gold'),
                            _field(palette, 'Tags', 'tags', hint: 'living room, exterior, feature wall'),
                          ], note: 'Separate colours and tags with commas.'),
                          _section(palette, 'Visibility', [
                            _switch(palette, 'Show in catalogue', 'Off keeps it as a hidden draft', _active,
                                (v) => setState(() {
                                      _active = v;
                                      if (_photoError != null) _photoError = ProductForm.images(_photos.length, active: v);
                                    })),
                            _switch(palette, 'Featured', 'Shown first on the home screen', _featured,
                                (v) => setState(() => _featured = v)),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
      bottomNavigationBar: _isLoading || _loadError != null
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: Center(
                heightFactor: 1,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_isSaving ? 'Saving…' : (_isEditing ? 'Save changes' : 'Add product'),
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: palette.primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // ─── building blocks ───

  Widget _section(LuxuryPalette palette, String title, List<Widget> children, {String? note}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.playfairDisplay(fontSize: 16, fontWeight: FontWeight.w700, color: palette.textPrimary)),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note, style: GoogleFonts.inter(fontSize: 11.5, color: palette.textTertiary)),
          ],
          const SizedBox(height: 10),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _row(List<Widget> fields) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: fields[i]),
          ],
        ],
      );

  InputDecoration _decoration(LuxuryPalette palette, String label, {String? hint, Widget? suffix}) {
    OutlineInputBorder b(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));
    return InputDecoration(
      labelText: label,
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: palette.surface,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary),
      floatingLabelStyle: GoogleFonts.inter(fontSize: 13, color: palette.primary, fontWeight: FontWeight.w600),
      hintStyle: GoogleFonts.inter(fontSize: 13, color: palette.textTertiary),
      errorStyle: GoogleFonts.inter(fontSize: 11, color: palette.error),
      errorMaxLines: 2,
      suffixIcon: suffix,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      border: b(palette.border),
      enabledBorder: b(palette.border),
      focusedBorder: b(palette.primary, 1.5),
      errorBorder: b(palette.error),
      focusedErrorBorder: b(palette.error, 1.5),
    );
  }

  Widget _field(
    LuxuryPalette palette,
    String label,
    String key, {
    String? hint,
    int maxLines = 1,
    bool number = false,
    bool integer = false,
    String? Function(String?)? validator,
    List<String> options = const [],
  }) {
    final c = _c[key]!;
    return TextFormField(
      key: ValueKey('field_$key'),
      controller: c,
      maxLines: maxLines,
      minLines: 1,
      keyboardType: number ? TextInputType.numberWithOptions(decimal: !integer) : TextInputType.text,
      textCapitalization: number ? TextCapitalization.none : TextCapitalization.sentences,
      inputFormatters: number ? [FilteringTextInputFormatter.allow(RegExp(integer ? r'[0-9]' : r'[0-9.,]'))] : null,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
      decoration: _decoration(
        palette,
        label,
        hint: hint,
        suffix: options.isEmpty
            ? null
            : PopupMenuButton<String>(
                tooltip: 'Pick existing $label',
                icon: Icon(Icons.expand_more_rounded, color: palette.textTertiary, size: 20),
                color: palette.surface,
                constraints: const BoxConstraints(maxHeight: 360),
                onSelected: (v) => setState(() => c.text = v),
                itemBuilder: (_) => [
                  for (final o in options)
                    PopupMenuItem(value: o, child: Text(o, style: GoogleFonts.inter(fontSize: 13, color: palette.textPrimary))),
                ],
              ),
      ),
    );
  }

  Widget _collectionField(LuxuryPalette palette) {
    return DropdownButtonFormField<String>(
      key: const ValueKey('field_collection'),
      initialValue: _collectionId,
      isExpanded: true,
      dropdownColor: palette.surface,
      menuMaxHeight: 420,
      validator: ProductForm.collection,
      decoration: _decoration(palette, 'Collection'),
      style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary),
      items: [
        for (final c in _collections)
          DropdownMenuItem(
            value: c['id'] as String,
            child: Text(
              c['active'] == false ? '${c['name']} (hidden)' : '${c['name']}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (v) => setState(() => _collectionId = v),
    );
  }

  Widget _switch(LuxuryPalette palette, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: palette.border)),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile.adaptive(
        dense: true,
        value: value,
        onChanged: onChanged,
        activeTrackColor: palette.primary,
        title: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: palette.textPrimary)),
        subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11.5, color: palette.textTertiary)),
      ),
    );
  }

  Widget _photoStrip(LuxuryPalette palette) {
    const size = 92.0;
    Widget thumb(int i) {
      final p = _photos[i];
      return Padding(
        key: ObjectKey(p),
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: p.bytes != null
                      ? Image.memory(p.bytes!, fit: BoxFit.cover)
                      : SmartStoneImage(imageUrl: p.url, localAsset: p.url, width: size, height: size, palette: palette),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: i == 0 ? palette.primary : palette.border, width: i == 0 ? 2 : 1),
                    ),
                  ),
                ),
              ),
              if (i == 0)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: palette.primary, borderRadius: BorderRadius.circular(6)),
                    child: Text('Cover', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              if (p.bytes != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: Text('New', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: Semantics(
                  button: true,
                  label: 'Remove photo ${i + 1}',
                  child: InkResponse(
                    onTap: () => setState(() => _photos.removeAt(i)),
                    radius: 18,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: size,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Add photos',
            child: InkWell(
              onTap: _isSaving ? null : _addPhotos,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: size * 0.8,
                height: size,
                decoration: BoxDecoration(
                  color: palette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.primary.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, color: palette.primary, size: 24),
                    const SizedBox(height: 4),
                    Text('Add', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: palette.primary)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _photos.isEmpty
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No photos yet', style: GoogleFonts.inter(fontSize: 12.5, color: palette.textTertiary)),
                  )
                : ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    itemCount: _photos.length,
                    proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
                    onReorder: (from, to) => setState(() {
                      if (to > from) to--;
                      _photos.insert(to, _photos.removeAt(from));
                    }),
                    itemBuilder: (_, i) => ReorderableDelayedDragStartListener(
                      key: ObjectKey(_photos[i]),
                      index: i,
                      child: thumb(i),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  final LuxuryPalette palette;
  final String message;
  final VoidCallback onRetry;
  const _LoadError({required this.palette, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Could not load this product', style: GoogleFonts.playfairDisplay(fontSize: 17, fontWeight: FontWeight.w700, color: palette.textPrimary)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center, maxLines: 4, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ),
        ),
      );
}
