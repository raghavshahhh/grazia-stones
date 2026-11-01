import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' show openAppSettings;
import 'package:share_plus/share_plus.dart';
import 'package:grazia_stones/shared/widgets/luxury_toast.dart';

/// Text that goes with every shared AI Studio render. The link is the owner's public site.
const aiStudioShareCaption = 'Designed with Grazia Stones AI Studio\nhttps://waitlist.graziastones.com';

const _logoAsset = 'assets/brand/grazia-logo-white.png';
ui.Image? _logo;

/// Burns the Grazia mark into the bottom-right corner of [renderBytes] at the render's
/// full resolution and returns a PNG of the same size. Saved and shared renders use this,
/// so the mark travels with the file and not only with the in-app view.
Future<Uint8List> watermarkRender(Uint8List renderBytes) async {
  final render = await _decode(renderBytes);
  _logo ??= await _decode((await rootBundle.load(_logoAsset)).buffer.asUint8List());
  final logo = _logo!;

  final w = render.width.toDouble();
  final h = render.height.toDouble();
  final logoW = w * 0.14;
  final logoH = logoW * logo.height / logo.width;
  final inset = w * 0.035;
  final dst = Rect.fromLTWH(w - inset - logoW, h - inset - logoH, logoW, logoH);
  final src = Rect.fromLTWH(0, 0, logo.width.toDouble(), logo.height.toDouble());
  final blur = logoW * 0.025;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(render, Offset.zero, Paint());
  // A blurred dark copy under the white mark keeps it readable on light walls as well as dark rooms.
  canvas.drawImageRect(
    logo,
    src,
    dst.shift(Offset(0, blur * 0.6)),
    Paint()
      ..colorFilter = const ColorFilter.mode(Color(0x8C000000), BlendMode.srcIn)
      ..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
  );
  canvas.drawImageRect(
    logo,
    src,
    dst,
    Paint()
      ..filterQuality = FilterQuality.high
      ..colorFilter = const ColorFilter.mode(Color(0xD9FFFFFF), BlendMode.srcIn),
  );

  final out = await recorder.endRecording().toImage(render.width, render.height);
  final png = await out.toByteData(format: ui.ImageByteFormat.png);
  render.dispose();
  out.dispose();
  return png!.buffer.asUint8List();
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

String _fileName() => 'Grazia_Stones_AI_${DateTime.now().millisecondsSinceEpoch}';

/// Saves the watermarked render to Photos (iOS) or the Gallery (Android) and toasts the outcome.
Future<void> saveRenderToGallery(BuildContext context, Uint8List renderBytes) async {
  try {
    final bytes = await watermarkRender(renderBytes);
    final name = _fileName();
    if (kIsWeb) {
      await XFile.fromData(bytes, mimeType: 'image/png', name: '$name.png').saveTo('$name.png');
    } else {
      // iOS asks for add-only Photos access; Android 11+ needs no permission, 10 and older ask for storage.
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        if (!context.mounted) return;
        LuxuryToast.show(
          context,
          message: 'Allow photo access to save your render',
          isError: true,
          actionLabel: 'Settings',
          onAction: openAppSettings,
        );
        return;
      }
      await Gal.putImageBytes(bytes, name: name);
    }
    if (!context.mounted) return;
    LuxuryToast.show(
      context,
      message: kIsWeb ? 'Render downloaded' : (Platform.isIOS ? 'Saved to Photos' : 'Saved to Gallery'),
    );
  } on GalException catch (e) {
    debugPrint('[AIStudio] save to gallery failed: $e');
    if (!context.mounted) return;
    LuxuryToast.show(context, message: e.type.message, isError: true);
  } catch (e) {
    debugPrint('[AIStudio] save to gallery failed: $e');
    if (!context.mounted) return;
    LuxuryToast.show(context, message: 'Could not save the render. Please try again.', isError: true);
  }
}

/// Opens the system share sheet (WhatsApp, Instagram, Mail...) with the watermarked render as an
/// image file plus [aiStudioShareCaption].
Future<void> shareRender(BuildContext context, Uint8List renderBytes) async {
  // iPad shows the sheet as a popover and needs an anchor; bottom centre sits over the action buttons.
  final size = MediaQuery.sizeOf(context);
  final origin = Rect.fromCenter(center: Offset(size.width / 2, size.height - 80), width: 1, height: 1);
  try {
    final bytes = await watermarkRender(renderBytes);
    final name = '${_fileName()}.png';
    final XFile file;
    if (kIsWeb) {
      file = XFile.fromData(bytes, mimeType: 'image/png', name: name);
    } else {
      final tmp = File('${(await getTemporaryDirectory()).path}/$name');
      await tmp.writeAsBytes(bytes);
      file = XFile(tmp.path, mimeType: 'image/png');
    }
    await Share.shareXFiles([file], text: aiStudioShareCaption, sharePositionOrigin: origin);
  } catch (e) {
    debugPrint('[AIStudio] share failed: $e');
    if (!context.mounted) return;
    LuxuryToast.show(context, message: 'Could not share the render. Please try again.', isError: true);
  }
}
