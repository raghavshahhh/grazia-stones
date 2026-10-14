import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A wall made of individual tiles: every tile shows the stone photo at the tile's own size, with its own crop, mirror
/// and shade, a bevelled edge and a recessed grout line. Replaces "one photo stretched over the whole wall", which
/// looked flat because there was no per-tile texture or real scale.
class TileTextureWall extends StatefulWidget {
  final String? imageUrl;
  final int columns;
  final int rows;

  /// 'brick' (running bond), 'stacked' or 'vertical'.
  final String pattern;

  /// Real tile width / height, so tiles keep their true shape instead of filling the grid cell.
  final double tileAspect;
  final Color groutColor;
  final Color fallbackColor;

  const TileTextureWall({
    super.key,
    required this.imageUrl,
    required this.columns,
    required this.rows,
    required this.pattern,
    required this.tileAspect,
    required this.groutColor,
    this.fallbackColor = const Color(0xFFC4B5A5),
  });

  @override
  State<TileTextureWall> createState() => _TileTextureWallState();
}

class _TileTextureWallState extends State<TileTextureWall> {
  ui.Image? _image;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    (info, _) {
      if (mounted) setState(() => _image = info.image);
    },
    onError: (_, _) {},
  );

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant TileTextureWall old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) _resolve();
  }

  void _resolve() {
    _stream?.removeListener(_listener);
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      _image = null;
      return;
    }
    final provider = url.startsWith('http')
        ? ResizeImage(CachedNetworkImageProvider(url), width: 1024, allowUpscaling: false)
        : ResizeImage(AssetImage(url), width: 1024, allowUpscaling: false) as ImageProvider;
    _stream = provider.resolve(const ImageConfiguration())..addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _TileWallPainter(
          image: _image,
          columns: widget.columns,
          rows: widget.rows,
          pattern: widget.pattern,
          tileAspect: widget.tileAspect,
          groutColor: widget.groutColor,
          fallbackColor: widget.fallbackColor,
        ),
      ),
    );
  }
}

class _TileWallPainter extends CustomPainter {
  final ui.Image? image;
  final int columns;
  final int rows;
  final String pattern;
  final double tileAspect;
  final Color groutColor;
  final Color fallbackColor;

  _TileWallPainter({
    required this.image,
    required this.columns,
    required this.rows,
    required this.pattern,
    required this.tileAspect,
    required this.groutColor,
    required this.fallbackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (columns <= 0 || rows <= 0) return;
    final wall = Offset.zero & size;
    canvas.clipRect(wall);
    // The wall behind the tiles is the grout
    canvas.drawRect(wall, Paint()..color = groutColor);

    final cellW = size.width / columns;
    final cellH = size.height / rows;
    // Real tile shape inside the cell grid; the remainder of the cell becomes the grout line
    final gap = (math.min(cellW, cellH) * 0.045).clamp(1.2, 3.2);
    final stagger = pattern == 'brick';

    for (var r = 0; r < rows; r++) {
      final shift = stagger && r.isOdd ? cellW * 0.5 : 0.0;
      for (var c = stagger && r.isOdd ? -1 : 0; c <= columns; c++) {
        final left = c * cellW + shift;
        if (left >= size.width) break;
        final cell = Rect.fromLTWH(left, r * cellH, cellW, cellH);
        final tile = cell.deflate(gap / 2);
        final visible = tile.intersect(wall);
        if (visible.isEmpty) continue;
        _paintTile(canvas, tile, r, c);
      }
    }
  }

  void _paintTile(Canvas canvas, Rect tile, int r, int c) {
    final rnd = math.Random((r * 73856093) ^ (c * 19349663) ^ 0x5bd1e995);
    final rrect = RRect.fromRectAndRadius(tile, const Radius.circular(1.4));

    canvas.save();
    canvas.clipRRect(rrect);

    final img = image;
    if (img == null) {
      canvas.drawRect(tile, Paint()..color = fallbackColor);
    } else {
      // Crop with the tile's own shape from a random spot of the photo, so no two neighbours look identical
      final iw = img.width.toDouble();
      final ih = img.height.toDouble();
      final dstAspect = tile.width / tile.height;
      var cw = iw * (0.55 + 0.4 * rnd.nextDouble());
      var ch = cw / dstAspect;
      if (ch > ih) {
        ch = ih * (0.55 + 0.4 * rnd.nextDouble());
        cw = ch * dstAspect;
      }
      cw = math.min(cw, iw);
      final src = Rect.fromLTWH(
        (iw - cw) * rnd.nextDouble(),
        (ih - ch) * rnd.nextDouble(),
        cw,
        math.min(ch, ih),
      );
      final shade = 0.9 + 0.16 * rnd.nextDouble(); // natural batch variation
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = ColorFilter.matrix(<double>[
          shade, 0, 0, 0, 0, //
          0, shade, 0, 0, 0, //
          0, 0, shade, 0, 0, //
          0, 0, 0, 1, 0,
        ]);
      if (rnd.nextBool()) {
        // Mirror half of the tiles
        canvas.translate(tile.center.dx, 0);
        canvas.scale(-1, 1);
        canvas.translate(-tile.center.dx, 0);
      }
      canvas.drawImageRect(img, src, tile, paint);
    }

    // Light falls from the top-left: lit face fading to shade, so each tile reads as a raised block
    canvas.drawRect(
      tile,
      Paint()
        ..shader = ui.Gradient.linear(
          tile.topLeft,
          tile.bottomRight,
          [Colors.white.withValues(alpha: 0.10), Colors.transparent, Colors.black.withValues(alpha: 0.16)],
          const [0.0, 0.5, 1.0],
        ),
    );
    canvas.restore();

    // Bevel: bright top/left edge, dark bottom/right edge, soft shadow into the grout
    final edge = Paint()..strokeWidth = 1.0;
    canvas.drawLine(tile.topLeft, tile.topRight, edge..color = Colors.white.withValues(alpha: 0.30));
    canvas.drawLine(tile.topLeft, tile.bottomLeft, edge..color = Colors.white.withValues(alpha: 0.20));
    canvas.drawLine(tile.bottomLeft, tile.bottomRight, edge..color = Colors.black.withValues(alpha: 0.45));
    canvas.drawLine(tile.topRight, tile.bottomRight, edge..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawRRect(
      rrect.inflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.black.withValues(alpha: 0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  @override
  bool shouldRepaint(covariant _TileWallPainter old) =>
      old.image != image ||
      old.columns != columns ||
      old.rows != rows ||
      old.pattern != pattern ||
      old.tileAspect != tileAspect ||
      old.groutColor != groutColor;
}
