import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/core/di.dart';
import 'package:grazia_stones/core/models/saved_design.dart';
import 'package:grazia_stones/core/widgets/error_handler_widget.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

class SavedDesignsScreen extends ConsumerStatefulWidget {
  const SavedDesignsScreen({super.key});

  @override
  ConsumerState<SavedDesignsScreen> createState() => _SavedDesignsScreenState();
}

class _SavedDesignsScreenState extends ConsumerState<SavedDesignsScreen> {
  bool _isLoading = true;
  String? _error;
  List<SavedDesign> _designs = [];
  String _sortBy = 'recent'; // recent, oldest, name

  @override
  void initState() {
    super.initState();
    _loadDesigns();
  }

  Future<void> _loadDesigns() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userRepo = ref.read(userRepositoryProvider);
      final data = await userRepo.getSavedDesigns();
      
      final designs = data.map((json) => SavedDesign.fromJson(json)).toList();
      _sortDesigns(designs);

      if (mounted) {
        setState(() {
          _designs = designs;
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

  void _sortDesigns(List<SavedDesign> designs) {
    switch (_sortBy) {
      case 'oldest':
        designs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'name':
        designs.sort((a, b) => a.stoneName.compareTo(b.stoneName));
        break;
      case 'recent':
      default:
        designs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  Future<void> _deleteDesign(String designId) async {
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.deleteSavedDesign(designId);

      if (mounted) {
        showSuccessSnackbar(context, 'Visualization removed');
        _loadDesigns();
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, e);
      }
    }
  }

  Future<void> _shareDesign(SavedDesign design) async {
    HapticFeedback.lightImpact();
    
    try {
      // Download image first for better sharing experience
      final response = await http.get(Uri.parse(design.generatedImageUrl));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/grazia_design_${design.id}.jpg');
        await file.writeAsBytes(response.bodyBytes);
        
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Check out my custom architectural concept with Grazia Stones (${design.stoneName})',
        );
      } else {
        // Fallback to URL sharing
        await Share.share(
          'Check out my custom architectural concept with Grazia Stones (${design.stoneName}): ${design.generatedImageUrl}',
        );
      }
    } catch (e) {
      // Fallback to URL sharing
      await Share.share(
        'Check out my custom architectural concept with Grazia Stones (${design.stoneName}): ${design.generatedImageUrl}',
      );
    }
  }

  Future<void> _downloadDesign(SavedDesign design) async {
    HapticFeedback.lightImpact();
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );

      final response = await http.get(Uri.parse(design.generatedImageUrl));
      if (response.statusCode == 200) {
        // For mobile, save to downloads
        final directory = Platform.isAndroid
            ? Directory('/storage/emulated/0/Download')
            : await getApplicationDocumentsDirectory();
            
        final fileName = 'grazia_design_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          showSuccessSnackbar(context, 'Image saved to ${Platform.isAndroid ? "Downloads" : "Documents"}');
        }
      } else {
        throw Exception('Failed to download image');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        showErrorSnackbar(context, Exception('Failed to download: ${e.toString()}'));
      }
    }
  }

  void _showSortOptions(LuxuryPalette palette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sort By',
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            _buildSortOption('Recent First', 'recent', palette),
            _buildSortOption('Oldest First', 'oldest', palette),
            _buildSortOption('Stone Name', 'name', palette),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String label, String value, LuxuryPalette palette) {
    final isSelected = _sortBy == value;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? palette.primary : palette.textTertiary,
      ),
      title: Text(
        label,
        style: GoogleFonts.inter(
          color: isSelected ? palette.primary : palette.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        setState(() {
          _sortBy = value;
          _sortDesigns(_designs);
        });
      },
    );
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
          'Saved AI Visualizations',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        actions: [
          if (_designs.isNotEmpty)
            IconButton(
              onPressed: () => _showSortOptions(palette),
              icon: Icon(Icons.sort_rounded, color: palette.primary, size: 22),
            ),
        ],
      ),
      body: _error != null
          ? ErrorHandlerWidget(
              error: Exception(_error),
              onRetry: _loadDesigns,
            )
          : _isLoading
              ? Center(child: CircularProgressIndicator(color: palette.primary))
              : _designs.isEmpty
                  ? _buildEmptyState(palette)
                  : RefreshIndicator(
                      color: palette.primary,
                      backgroundColor: palette.surface,
                      onRefresh: _loadDesigns,
                      child: GridView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _designs.length,
                        itemBuilder: (context, i) {
                          final design = _designs[i];
                          return _buildDesignCard(palette, design);
                        },
                      ),
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
            child: Icon(Icons.auto_awesome_outlined, size: 40, color: palette.textTertiary),
          ),
          const SizedBox(height: 20),
          Text(
            'No Saved Visualizations',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create photorealistic stone visual concepts in\nAI Studio to preview here.',
            style: GoogleFonts.inter(fontSize: 13, color: palette.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/ai-viz'),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('Open AI Studio'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignCard(LuxuryPalette palette, SavedDesign design) {
    return GestureDetector(
      onLongPress: () => _showDesignOptions(palette, design),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
                    child: Image.network(
                      design.generatedImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: palette.surfaceDark,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_outlined, color: palette.textTertiary, size: 32),
                            const SizedBox(height: 8),
                            Text(
                              'Image unavailable',
                              style: GoogleFonts.inter(
                                color: palette.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        design.getFormattedDate(),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    design.stoneName,
                    style: GoogleFonts.playfairDisplay(
                      color: palette.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (design.finish != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      design.finish!,
                      style: GoogleFonts.inter(
                        color: palette.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _shareDesign(design),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: palette.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.share_outlined, size: 14, color: palette.primary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _downloadDesign(design),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: palette.surfaceDark,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.download_outlined, size: 14, color: palette.primary),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (design.hasStone) {
                            context.push('/stone/${design.stoneId}');
                          } else {
                            context.push('/quotes');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Quote',
                            style: GoogleFonts.inter(
                              color: palette.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDesignOptions(LuxuryPalette palette, SavedDesign design) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.share_outlined, color: palette.primary),
              title: Text('Share Design', style: TextStyle(color: palette.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _shareDesign(design);
              },
            ),
            ListTile(
              leading: Icon(Icons.download_outlined, color: palette.primary),
              title: Text('Download Image', style: TextStyle(color: palette.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _downloadDesign(design);
              },
            ),
            if (design.hasStone)
              ListTile(
                leading: Icon(Icons.info_outline, color: palette.primary),
                title: Text('View Stone Details', style: TextStyle(color: palette.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/stone/${design.stoneId}');
                },
              ),
            ListTile(
              leading: Icon(Icons.request_quote_outlined, color: palette.primary),
              title: Text('Request Quote', style: TextStyle(color: palette.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/quotes');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Delete Design', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(design);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(SavedDesign design) {
    final palette = ref.read(themePaletteProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Delete Design?', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary)),
        content: Text(
          'This will permanently remove this visualization from your saved designs.',
          style: GoogleFonts.inter(color: palette.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: palette.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteDesign(design.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
