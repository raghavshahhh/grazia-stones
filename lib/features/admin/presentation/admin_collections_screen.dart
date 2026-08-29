import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/collection.dart';
import 'package:grazia_stones/core/services/supabase_service.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';

class AdminCollectionsScreen extends ConsumerStatefulWidget {
  const AdminCollectionsScreen({super.key});

  @override
  ConsumerState<AdminCollectionsScreen> createState() => _AdminCollectionsScreenState();
}

class _AdminCollectionsScreenState extends ConsumerState<AdminCollectionsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Collection> _collections = [];

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final stoneRepo = ref.read(stoneRepositoryProvider);
      final collections = await stoneRepo.getCollections();

      if (mounted) {
        setState(() {
          _collections = collections;
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

  void _showCollectionDialog({Collection? collection, required LuxuryPalette palette}) {
    final nameCtrl = TextEditingController(text: collection?.name ?? '');
    final slugCtrl = TextEditingController(text: collection?.id ?? '');
    final descCtrl = TextEditingController(text: collection?.description ?? '');
    final imgCtrl = TextEditingController(text: collection?.imageUrl ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text(
          collection != null ? 'Edit Collection' : 'New Collection',
          style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.w700, color: palette.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Collection Name',
                  labelStyle: TextStyle(color: palette.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: slugCtrl,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Slug / Key',
                  labelStyle: TextStyle(color: palette.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descCtrl,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: palette.textSecondary),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imgCtrl,
                style: TextStyle(color: palette.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Banner Image URL',
                  labelStyle: TextStyle(color: palette.textSecondary),
                ),
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
                final adminRepo = ref.read(adminProductRepositoryProvider);
                final slug = slugCtrl.text.trim().isNotEmpty
                    ? slugCtrl.text.trim().toLowerCase().replaceAll(' ', '-')
                    : nameCtrl.text.trim().toLowerCase().replaceAll(' ', '-');

                if (collection != null) {
                  await adminRepo.updateCollection(
                    collectionId: collection.id,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    imageUrl: imgCtrl.text.trim().isNotEmpty ? imgCtrl.text.trim() : null,
                  );
                } else {
                  await adminRepo.createCollection(
                    slug: slug,
                    name: nameCtrl.text.trim(),
                    description: descCtrl.text.trim(),
                    imageUrl: imgCtrl.text.trim().isNotEmpty ? imgCtrl.text.trim() : null,
                  );
                }


                if (mounted) {
                  showSuccessSnackbar(context, 'Collection saved successfully');
                  _loadCollections();
                }
              } catch (e) {
                if (mounted) showErrorSnackbar(context, e);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCollection(String id) async {
    try {
      final adminRepo = ref.read(adminProductRepositoryProvider);
      await adminRepo.deleteCollection(id);

      if (mounted) {
        showSuccessSnackbar(context, 'Collection deleted');
        _loadCollections();
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
          'Manage Collections (${_collections.length})',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: _error != null
          ? ErrorHandlerWidget(error: Exception(_error), onRetry: _loadCollections)
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : RefreshIndicator(
                  color: palette.primary,
                  backgroundColor: palette.surface,
                  onRefresh: _loadCollections,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    itemCount: _collections.length,
                    itemBuilder: (context, i) {
                      final c = _collections[i];
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
                              child: Icon(Icons.category_outlined, color: palette.primary),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.name,
                                    style: GoogleFonts.playfairDisplay(
                                      color: palette.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    c.description.isNotEmpty ? c.description : 'No description',
                                    style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_outlined, color: palette.primary, size: 18),
                              onPressed: () => _showCollectionDialog(collection: c, palette: palette),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                              onPressed: () => _deleteCollection(c.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCollectionDialog(palette: palette),
        backgroundColor: palette.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add, size: 20),
        label: Text('New Collection', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    );
  }
}
