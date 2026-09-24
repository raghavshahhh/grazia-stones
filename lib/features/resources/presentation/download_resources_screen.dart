import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:grazia_stones/shared/theme/theme_provider.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';

/// Screen 16: Download Resources (Download CAD / Textures)
/// Matches Client Reference Sheet Screen 16:
/// - "Download Resources"
/// - Tabs: CAD Files, Textures, Images
/// - List of DWG/Texture downloads with icons & download buttons:
///     • Desert Stone CAD File (DWG)
///     • Ivory Waves CAD File (DWG)
///     • Grey Texture CAD File (DWG)
///     • Fluted Classic CAD File (DWG)
///     • Mosaic Art CAD File (DWG)
class DownloadResourcesScreen extends ConsumerStatefulWidget {
  const DownloadResourcesScreen({super.key});

  @override
  ConsumerState<DownloadResourcesScreen> createState() => _DownloadResourcesScreenState();
}

class _DownloadResourcesScreenState extends ConsumerState<DownloadResourcesScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['CAD Files', 'Textures', 'Images'];

  final List<Map<String, String>> _cadFiles = [
    {'title': 'Desert Stone CAD File (DWG)', 'format': 'AutoCAD 2024 DWG', 'size': '4.2 MB'},
    {'title': 'Ivory Waves CAD File (DWG)', 'format': 'AutoCAD 2024 DWG', 'size': '3.8 MB'},
    {'title': 'Grey Texture CAD File (DWG)', 'format': 'AutoCAD 2024 DWG', 'size': '4.9 MB'},
    {'title': 'Fluted Classic CAD File (DWG)', 'format': 'AutoCAD 2024 DWG', 'size': '3.1 MB'},
    {'title': 'Mosaic Art CAD File (DWG)', 'format': 'AutoCAD 2024 DWG', 'size': '5.6 MB'},
  ];

  final List<Map<String, String>> _textureFiles = [
    {'title': 'Desert Stone 4K Seamless Map', 'format': 'Diffuse + Bump + Normal', 'size': '24.5 MB'},
    {'title': 'Verona Marble 4K PBR Set', 'format': 'High Res Texture Pack', 'size': '32.1 MB'},
    {'title': 'Athena 3D Panel Material', 'format': 'Substance 3D Shader', 'size': '18.4 MB'},
  ];

  final List<Map<String, String>> _imageFiles = [
    {'title': 'Complete 2026 Architect Lookbook', 'format': 'PDF Print Ready', 'size': '14.8 MB'},
    {'title': 'High-Res Project Portfolio', 'format': 'JPEG 300 DPI Collection', 'size': '45.0 MB'},
  ];

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(themePaletteProvider);
    final isDark = ref.watch(themePaletteProvider.notifier).isDarkMode;

    final currentList = _selectedTab == 0
        ? _cadFiles
        : (_selectedTab == 1 ? _textureFiles : _imageFiles);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: palette.textPrimary, size: 18),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Text(
          'Download Resources',
          style: GoogleFonts.playfairDisplay(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1C19) : const Color(0xFFEFEBE4),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final isSelected = _selectedTab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _selectedTab = i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFD4AF37) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            _tabs[i],
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.black : palette.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Download List
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: currentList.length,
              itemBuilder: (context, i) {
                final file = currentList[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Square CAD Icon Container
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: const Icon(
                          Icons.architecture_rounded,
                          color: Color(0xFFD4AF37),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Title & Format
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file['title']!,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${file['format']} • ${file['size']}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: palette.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Download Button
                      IconButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          LuxuryToast.show(
                            context,
                            message: 'Downloading ${file['title']}...',
                          );
                        },
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF22201C) : const Color(0xFFF2ECE1),
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.border),
                          ),
                          child: const Icon(
                            Icons.download_rounded,
                            size: 18,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
