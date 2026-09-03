import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/stone.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class AdminProductEditScreen extends ConsumerStatefulWidget {
  final String? stoneId;
  final Stone? stone;

  const AdminProductEditScreen({super.key, this.stoneId, this.stone});

  @override
  ConsumerState<AdminProductEditScreen> createState() => _AdminProductEditScreenState();
}

class _AdminProductEditScreenState extends ConsumerState<AdminProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _lengthController = TextEditingController();
  final _widthController = TextEditingController();
  final _thicknessController = TextEditingController();
  final _coverageController = TextEditingController();
  final _materialController = TextEditingController();
  final _colorsController = TextEditingController();
  final _tagsController = TextEditingController();
  final _stockController = TextEditingController();

  String _category = 'Ledge Stone';
  String _finish = 'Natural';
  String? _selectedCollectionId;
  bool _featured = false;
  bool _active = true;
  String? _imageUrl;
  Uint8List? _newImageBytes;
  String? _newImageExt;

  bool _isLoading = true;
  bool _isSaving = false;
  List<Collection> _collections = [];

  final List<String> _categories = [
    'Ledge Stone',
    'Cultured Stone',
    '3D Wall Panel',
    'Heritage Stone',
    'Modern Cladding',
    'Vintage Brick',
    'Granite Slab',
  ];

  final List<String> _finishes = [
    'Natural',
    'Polished',
    'Honed',
    'Brushed',
    'Flamed',
    'Leathered',
    'Textured',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _lengthController.dispose();
    _widthController.dispose();
    _thicknessController.dispose();
    _coverageController.dispose();
    _materialController.dispose();
    _colorsController.dispose();
    _tagsController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final stoneRepo = ref.read(stoneRepositoryProvider);
      final collections = await stoneRepo.getCollections();
      _collections = collections;

      if (widget.stone != null) {
        _populateFields(widget.stone!);
      } else if (widget.stoneId != null && widget.stoneId != 'add') {
        final stone = await stoneRepo.getStoneById(widget.stoneId!);
        _populateFields(stone);
      }

      if (_selectedCollectionId == null && _collections.isNotEmpty) {
        _selectedCollectionId = _collections.first.id;
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _populateFields(Stone s) {
    _nameController.text = s.name;
    _slugController.text = s.id;
    _descriptionController.text = s.description;
    _priceController.text = s.pricePerSqFt.toStringAsFixed(0);
    _lengthController.text = s.lengthCm?.toString() ?? '60';
    _widthController.text = s.widthCm?.toString() ?? '15';
    _thicknessController.text = s.thicknessMm?.toString() ?? '25';
    _coverageController.text = s.coverageSqft?.toString() ?? '0.97';
    _materialController.text = s.material;
    _colorsController.text = s.colors.join(', ');
    _tagsController.text = s.tags.join(', ');
    _stockController.text = s.stockQuantity.toString();
    _category = s.category;
    _finish = s.finish;
    _featured = s.isFeatured;
    _selectedCollectionId = s.collectionId;
    _imageUrl = s.imageUrl;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last;
      setState(() {
        _newImageBytes = bytes;
        _newImageExt = ext;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final client = SupabaseService.instance.client;
      String? uploadedUrl = _imageUrl;

      // 1. Upload new image if selected
      if (_newImageBytes != null) {
        final fileName = 'stone_${DateTime.now().millisecondsSinceEpoch}.${_newImageExt ?? 'jpg'}';
        await client.storage.from('stones').uploadBinary(fileName, _newImageBytes!);
        uploadedUrl = client.storage.from('stones').getPublicUrl(fileName);
      }

      // 2. Preserve the existing gallery — only replace/add the primary
      // image. Previously saving an edit wiped the whole images[] down
      // to a single photo, destroying multi-image products.
      List<String> gallery = [];
      if (widget.stone?.images.isNotEmpty == true) {
        gallery = [...widget.stone!.images];
      } else if (widget.stoneId != null && widget.stoneId != 'add') {
        try {
          final existing = await client
              .from('stones')
              .select('images')
              .eq('id', widget.stoneId!)
              .single();
          gallery = List<String>.from(existing['images'] ?? []);
        } catch (_) {}
      }
      if (uploadedUrl != null) {
        if (gallery.contains(uploadedUrl)) {
          gallery.remove(uploadedUrl);
        }
        gallery.insert(0, uploadedUrl);
      }

      final slug = _slugController.text.trim().isNotEmpty
          ? _slugController.text.trim().toLowerCase().replaceAll(' ', '-')
          : _nameController.text.trim().toLowerCase().replaceAll(' ', '-');

      final stoneData = {
        'name': _nameController.text.trim(),
        'slug': slug,
        'product_code': _codeController.text.trim().isNotEmpty ? _codeController.text.trim() : slug.toUpperCase(),
        'collection_id': _selectedCollectionId,
        'category': _category,
        'description': _descriptionController.text.trim(),
        'price_per_sqft': double.tryParse(_priceController.text.trim()) ?? 0,
        'length_cm': double.tryParse(_lengthController.text.trim()) ?? 60,
        'width_cm': double.tryParse(_widthController.text.trim()) ?? 15,
        'thickness_mm': double.tryParse(_thicknessController.text.trim()) ?? 25,
        'coverage_sqft': double.tryParse(_coverageController.text.trim()) ?? 0.97,
        'finish': _finish,
        'material': _materialController.text.trim().isNotEmpty ? _materialController.text.trim() : 'Natural Stone',
        'colors': _colorsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'tags': _tagsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
        'stock_quantity': int.tryParse(_stockController.text.trim()) ?? 100,
        'stock_status': (int.tryParse(_stockController.text.trim()) ?? 100) > 0 ? 'in_stock' : 'out_of_stock',
        'featured': _featured,
        'active': _active,
        'thumbnail_url': uploadedUrl,
        'images': gallery,
      };

      if (widget.stoneId != null && widget.stoneId != 'add') {
        await client.from('stones').update(stoneData).eq('id', widget.stoneId!);
      } else {
        await client.from('stones').insert(stoneData);
      }

      if (mounted) {
        setState(() => _isSaving = false);
        showSuccessSnackbar(context, 'Product saved successfully!');
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        showErrorSnackbar(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isEditing = widget.stoneId != null && widget.stoneId != 'add';

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
          isEditing ? 'Edit Stone' : 'Add New Stone',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: palette.primary))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image picker card
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: palette.border),
                        ),
                        child: _newImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(17),
                                child: Image.memory(_newImageBytes!, fit: BoxFit.cover),
                              )
                            : _imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(17),
                                    child: Image.network(_imageUrl!, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_photo_alternate_outlined, size: 40, color: palette.primary),
                                      const SizedBox(height: 8),
                                      Text('Tap to Upload Slab Image',
                                          style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, fontWeight: FontWeight.w600)),
                                      Text('Stored securely in Supabase bucket',
                                          style: GoogleFonts.inter(fontSize: 11, color: palette.textTertiary)),
                                    ],
                                  ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('BASIC SPECIFICATIONS', palette),
                    const SizedBox(height: 12),

                    _buildField('Stone Name', _nameController, palette, required: true),
                    const SizedBox(height: 12),
                    _buildField('Slug / URL Key (Optional)', _slugController, palette),
                    const SizedBox(height: 12),
                    _buildField('Product Code (e.g. GL-TA02)', _codeController, palette),
                    const SizedBox(height: 12),

                    // Collection selector
                    Text('Collection', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCollectionId,
                          isExpanded: true,
                          dropdownColor: palette.surface,
                          items: _collections
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: TextStyle(color: palette.textPrimary))))
                              .toList(),
                          onChanged: (v) => setState(() => _selectedCollectionId = v),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Category
                    Text('Category', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _category,
                          isExpanded: true,
                          dropdownColor: palette.surface,
                          items: _categories
                              .map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: palette.textPrimary))))
                              .toList(),
                          onChanged: (v) => setState(() => _category = v ?? _category),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Finish
                    Text('Surface Finish', style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: palette.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _finish,
                          isExpanded: true,
                          dropdownColor: palette.surface,
                          items: _finishes
                              .map((f) => DropdownMenuItem(value: f, child: Text(f, style: TextStyle(color: palette.textPrimary))))
                              .toList(),
                          onChanged: (v) => setState(() => _finish = v ?? _finish),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildSectionHeader('PRICING & DIMENSIONS', palette),
                    const SizedBox(height: 12),

                    _buildField('Price Per Sq Ft (₹)', _priceController, palette, keyboardType: TextInputType.number, required: true),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(child: _buildField('Length (cm)', _lengthController, palette, keyboardType: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField('Width (cm)', _widthController, palette, keyboardType: TextInputType.number)),
                        const SizedBox(width: 10),
                        Expanded(child: _buildField('Thickness (mm)', _thicknessController, palette, keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    _buildField('Coverage (sq ft / piece)', _coverageController, palette, keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    _buildField('Stock Quantity', _stockController, palette, keyboardType: TextInputType.number),

                    const SizedBox(height: 24),

                    _buildSectionHeader('METADATA & DESCRIPTION', palette),
                    const SizedBox(height: 12),

                    _buildField('Colors (comma-separated, e.g. Beige, Grey, Gold)', _colorsController, palette),
                    const SizedBox(height: 12),
                    _buildField('Tags (comma-separated, e.g. luxury, living room, exterior)', _tagsController, palette),
                    const SizedBox(height: 12),
                    _buildField('Architectural Description', _descriptionController, palette, maxLines: 3),

                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: Text('Featured in Showroom', style: GoogleFonts.inter(color: palette.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                      value: _featured,
                      activeColor: palette.primary,
                      onChanged: (v) => setState(() => _featured = v),
                      contentPadding: EdgeInsets.zero,
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 14,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border(top: BorderSide(color: palette.border)),
        ),
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveProduct,
          icon: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 18),
          label: Text(_isSaving ? 'Saving to Database...' : 'Save Stone to Catalog'),
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, LuxuryPalette palette) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 11,
        color: palette.textTertiary,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller,
    LuxuryPalette palette, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: palette.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: required ? (v) => v == null || v.trim().isEmpty ? '$label is required' : null : null,
          style: GoogleFonts.inter(fontSize: 14, color: palette.textPrimary, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: palette.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
