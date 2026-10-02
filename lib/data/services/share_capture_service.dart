import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Aspect ratio options for share card images.
enum ShareAspectRatio {
  story(9, 16, 'Story (9:16)', 450, 800),
  square(1, 1, 'Square (1:1)', 580, 580),
  wide(19, 10, 'Wide (1.9:1)', 760, 400);

  const ShareAspectRatio(
    this.widthRatio,
    this.heightRatio,
    this.label,
    this.canonicalWidth,
    this.canonicalHeight,
  );
  final int widthRatio;
  final int heightRatio;
  final String label;
  final double canonicalWidth;
  final double canonicalHeight;

  double get aspectValue => widthRatio / heightRatio;
}

/// Available share card background gradient presets.
enum ShareCardTheme {
  dark('Dark', [Color(0xFF0A0A0F), Color(0xFF1A1A2E)]),
  neon('Neon', [Color(0xFF0D0D1A), Color(0xFF1B003A)]),
  retro('Retro', [Color(0xFF1A0A00), Color(0xFF2D1200)]),
  midnight('Midnight', [Color(0xFF000814), Color(0xFF001D3D)]),
  aurora('Aurora', [Color(0xFF030D0A), Color(0xFF004030)]);

  const ShareCardTheme(this.label, this.colors);
  final String label;
  final List<Color> colors;
}

/// Service that captures a widget subtree as a high-resolution PNG
/// and either shares it via the system sheet or saves it to the gallery.
class ShareCaptureService {
  /// Renders the widget identified by [repaintKey] at [pixelRatio]× density
  /// and returns raw PNG bytes.
  static Future<Uint8List> captureWidget({
    required GlobalKey repaintKey,
    double pixelRatio = 3.0,
  }) async {
    final context = repaintKey.currentContext;
    if (context == null) throw StateError('RepaintBoundary key has no context');
    final boundary =
        context.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw StateError('No RenderRepaintBoundary found for key');
    }
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode image as PNG');
    return byteData.buffer.asUint8List();
  }

  /// Saves [bytes] to a uniquely-named temp file and returns its path.
  static Future<String> saveTempImage(
      Uint8List bytes, String cardName) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/sound_capsule_${cardName}_$ts.png');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Full capture → temp-file → system share sheet pipeline.
  static Future<void> shareCard({
    required GlobalKey repaintKey,
    required String cardName,
    String shareText =
        '🎧 Check out my Sound Capsule — my listening stats this month!',
    double pixelRatio = 3.0,
  }) async {
    final bytes =
        await captureWidget(repaintKey: repaintKey, pixelRatio: pixelRatio);
    final path = await saveTempImage(bytes, cardName);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        text: shareText,
      ),
    );
  }

  /// Capture → save directly to device gallery (no share sheet).
  static Future<void> saveToGallery({
    required GlobalKey repaintKey,
    required String cardName,
    double pixelRatio = 3.0,
  }) async {
    final bytes =
        await captureWidget(repaintKey: repaintKey, pixelRatio: pixelRatio);
    final path = await saveTempImage(bytes, cardName);
    await Gal.putImage(path);
    // Temp file is left in place; OS will clean it up when space is needed.
  }

  /// Checks whether gallery write permission is granted.
  static Future<bool> hasGalleryAccess() => Gal.hasAccess();

  /// Requests gallery write permission.
  static Future<bool> requestGalleryAccess() => Gal.requestAccess();
}
