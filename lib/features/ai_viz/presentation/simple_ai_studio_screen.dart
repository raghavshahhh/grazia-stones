import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:grazia_stones/shared/theme/colors.dart';
import 'package:grazia_stones/core/services/ai_endpoint_client.dart';

/// Simple, 2-step AI Room Studio: upload a photo of your room, upload a
/// photo of the design/stone you want, tap Generate. No catalog browsing,
/// no finish/lighting pickers, no 4-variant gallery — just the two photos
/// the user actually has in mind, composited by the real generate-
/// visualization endpoint (which now accepts an actual design image
/// instead of only a text stone name — see api/generate-visualization.js).
class SimpleAIStudioScreen extends StatefulWidget {
  const SimpleAIStudioScreen({super.key});

  @override
  State<SimpleAIStudioScreen> createState() => _SimpleAIStudioScreenState();
}

class _SimpleAIStudioScreenState extends State<SimpleAIStudioScreen> {
  final ImagePicker _picker = ImagePicker();
  final palette = GLuxuryPalettes.gold;

  Uint8List? _roomBytes;
  Uint8List? _designBytes;
  String? _resultImage; // data URL
  bool _generating = false;
  String? _error;

  Future<void> _pick(bool isRoom) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: palette.background,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('Take Photo', style: GoogleFonts.inter(color: palette.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: palette.textPrimary)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    HapticFeedback.mediumImpact();
    setState(() {
      if (isRoom) {
        _roomBytes = bytes;
      } else {
        _designBytes = bytes;
      }
      _resultImage = null;
      _error = null;
    });
  }

  Future<void> _generate() async {
    if (_roomBytes == null || _designBytes == null) return;
    setState(() {
      _generating = true;
      _error = null;
      _resultImage = null;
    });

    try {
      final roomDataUrl = 'data:image/jpeg;base64,${base64Encode(_roomBytes!)}';
      final designDataUrl = 'data:image/jpeg;base64,${base64Encode(_designBytes!)}';

      final data = await AIEndpointClient.post('/api/generate-visualization', {
        'image': roomDataUrl,
        'designImage': designDataUrl,
        'variantIndex': 0,
      });

      if (!mounted) return;
      setState(() {
        _resultImage = data['resultImage'] as String?;
        _generating = false;
      });
      if (_resultImage == null) {
        setState(() => _error = 'Could not generate a result. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = 'Something went wrong. Please check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = _roomBytes != null && _designBytes != null && !_generating;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        title: Text(
          'AI Room Studio',
          style: GoogleFonts.playfairDisplay(
            color: palette.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Two photos, one realistic result.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: palette.textPrimary.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              _ImageSlot(
                palette: palette,
                label: '1. Your Room',
                subtitle: 'Photo of the wall you want to redesign',
                bytes: _roomBytes,
                onTap: () => _pick(true),
              ),
              const SizedBox(height: 16),
              _ImageSlot(
                palette: palette,
                label: '2. Your Design',
                subtitle: 'Photo of the stone/design you want applied',
                bytes: _designBytes,
                onTap: () => _pick(false),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: canGenerate ? _generate : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: palette.accent.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _generating
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : Text(
                          'Generate',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: GoogleFonts.inter(color: Colors.red.shade400, fontSize: 13)),
              ],
              if (_resultImage != null) ...[
                const SizedBox(height: 28),
                Text(
                  'Result',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.memory(
                    base64Decode(_resultImage!.split(',').last),
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  final LuxuryPalette palette;
  final String label;
  final String subtitle;
  final Uint8List? bytes;
  final VoidCallback onTap;

  const _ImageSlot({
    required this.palette,
    required this.label,
    required this.subtitle,
    required this.bytes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.accent.withValues(alpha: 0.4)),
          color: palette.accent.withValues(alpha: 0.04),
          image: bytes != null
              ? DecorationImage(image: MemoryImage(bytes!), fit: BoxFit.cover)
              : null,
        ),
        child: bytes == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, size: 32, color: palette.accent),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: palette.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 12, color: palette.textPrimary.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              )
            : Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Change', style: GoogleFonts.inter(color: Colors.white, fontSize: 11)),
                  ),
                ),
              ),
      ),
    );
  }
}
