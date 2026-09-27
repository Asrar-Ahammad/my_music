import 'package:flutter/material.dart';

/// Supported retro filters for playlist cover image editing.
enum RetroImageFilter {
  normal,
  gameBoy,
  pixelNoir,
  vintageCrt,
  synthwave,
  cassette,
  cyberpunk,
  pixelate,
}

/// Metadata and color matrix definition for retro filters.
class RetroFilterPreset {
  final RetroImageFilter filter;
  final String label;
  final String description;
  final List<double>? matrix;
  final bool hasPixelOverlay;

  const RetroFilterPreset({
    required this.filter,
    required this.label,
    required this.description,
    this.matrix,
    this.hasPixelOverlay = false,
  });

  /// All available retro filter presets.
  static const List<RetroFilterPreset> presets = [
    RetroFilterPreset(
      filter: RetroImageFilter.normal,
      label: 'NORMAL',
      description: 'Original colors',
      matrix: null,
    ),
    RetroFilterPreset(
      filter: RetroImageFilter.gameBoy,
      label: '8-BIT GB',
      description: 'Game Boy 4-color green matrix',
      matrix: [
        0.30, 0.40, 0.15, 0, 20,
        0.45, 0.60, 0.20, 0, 45,
        0.10, 0.25, 0.05, 0, 10,
        0, 0, 0, 1, 0,
      ],
    ),
    RetroFilterPreset(
      filter: RetroImageFilter.pixelNoir,
      label: 'PIXEL NOIR',
      description: 'High-contrast 1-bit monochrome',
      matrix: [
        0.70, 0.70, 0.70, 0, -50,
        0.70, 0.70, 0.70, 0, -50,
        0.70, 0.70, 0.70, 0, -50,
        0, 0, 0, 1, 0,
      ],
    ),
    RetroFilterPreset(
      filter: RetroImageFilter.vintageCrt,
      label: 'VINTAGE CRT',
      description: 'Warm nostalgic cathode-ray sepia',
      matrix: [
        0.393, 0.769, 0.189, 0, 10,
        0.349, 0.686, 0.168, 0, 5,
        0.272, 0.534, 0.131, 0, -10,
        0, 0, 0, 1, 0,
      ],
    ),
    RetroFilterPreset(
      filter: RetroImageFilter.synthwave,
      label: 'SYNTHWAVE',
      description: 'Neon magenta & electric cyan',
      matrix: [
        1.3, 0.0, 0.2, 0, 30,
        0.1, 0.8, 0.3, 0, -10,
        0.3, 0.2, 1.4, 0, 40,
        0, 0, 0, 1, 0,
      ],
    ),
    RetroFilterPreset(
      filter: RetroImageFilter.cassette,
      label: 'CASSETTE',
      description: 'Golden 80s analog tape warmth',
      matrix: [
        1.15, 0.10, 0.05, 0, 25,
        0.05, 1.05, 0.05, 0, 15,
        0.00, 0.05, 0.80, 0, -15,
        0, 0, 0, 1, 0,
      ],
    ),
    RetroFilterPreset(
      filter: RetroImageFilter.cyberpunk,
      label: 'CYBERPUNK',
      description: 'Deep violet shadows & vibrant yellow',
      matrix: [
        1.4, -0.1, -0.2, 0, 35,
        -0.2, 1.3, -0.1, 0, 20,
        0.4, -0.2, 1.5, 0, 50,
        0, 0, 0, 1, 0,
      ],
    ),
    RetroFilterPreset(
      filter: RetroImageFilter.pixelate,
      label: 'PIXELATE',
      description: 'Chunky 8-bit pixel matrix overlay',
      matrix: null,
      hasPixelOverlay: true,
    ),
  ];
}

/// CustomPainter that renders CRT cathode-ray tube horizontal scanlines.
class RetroScanlinesPainter extends CustomPainter {
  final double lineSpacing;
  final double opacity;

  const RetroScanlinesPainter({
    this.lineSpacing = 3.0,
    this.opacity = 0.22,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..strokeWidth = 1.0;

    for (double y = 0; y < size.height; y += lineSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant RetroScanlinesPainter oldDelegate) {
    return oldDelegate.lineSpacing != lineSpacing ||
        oldDelegate.opacity != opacity;
  }
}

/// CustomPainter that renders a fine retro pixel grid overlay.
class RetroPixelGridPainter extends CustomPainter {
  final double blockSize;
  final double opacity;

  const RetroPixelGridPainter({
    this.blockSize = 4.0,
    this.opacity = 0.18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: opacity)
      ..strokeWidth = 0.75;

    // Vertical pixel grid lines
    for (double x = 0; x < size.width; x += blockSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    // Horizontal pixel grid lines
    for (double y = 0; y < size.height; y += blockSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RetroPixelGridPainter oldDelegate) {
    return oldDelegate.blockSize != blockSize ||
        oldDelegate.opacity != opacity;
  }
}
