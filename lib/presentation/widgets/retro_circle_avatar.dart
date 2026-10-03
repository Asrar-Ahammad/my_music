import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import 'retro_icon.dart';

/// A custom retro circular avatar with an authentic arcade/radar retro circular border.
/// Features:
/// 1. Outer accent ring with subtle dual-track concentric border.
/// 2. Four cardinal retro pixel notch brackets (at 12, 3, 6, and 9 o'clock).
/// 3. Diagonal 8-bit corner pixel accents.
/// 4. An inner [ClipOval] using [Clip.antiAliasWithSaveLayer] to eliminate all square edges or corner artifacts.
class RetroCircleAvatar extends StatelessWidget {
  final String? artPath;
  final String? fallbackText;
  final double size;
  final Color? accentColor;
  final Color? borderColor;

  const RetroCircleAvatar({
    super.key,
    required this.artPath,
    this.fallbackText,
    required this.size,
    this.accentColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = theme.extension<RetroThemeTokens>();
    final effectiveAccent = accentColor ?? theme.colorScheme.primary;
    final effectiveBorderColor = borderColor ?? retro?.borderColor ?? effectiveAccent.withValues(alpha: 0.5);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Inner circular photo with anti-aliased save layer clipping
          Padding(
            padding: const EdgeInsets.all(4.5),
            child: ClipOval(
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: Container(
                color: theme.colorScheme.surface,
                width: size - 9,
                height: size - 9,
                child: _buildImageContent(context, effectiveAccent),
              ),
            ),
          ),

          // Custom retro arcade circle border
          Positioned.fill(
            child: CustomPaint(
              painter: _RetroCircleBorderPainter(
                accentColor: effectiveAccent,
                borderColor: effectiveBorderColor,
                strokeWidth: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context, Color effectiveAccent) {
    if (artPath != null && artPath!.trim().isNotEmpty) {
      final path = artPath!.trim();
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          width: size - 9,
          height: size - 9,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallback(effectiveAccent),
        );
      } else {
        return Image.file(
          File(path),
          width: size - 9,
          height: size - 9,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallback(effectiveAccent),
        );
      }
    }
    return _buildFallback(effectiveAccent);
  }

  Widget _buildFallback(Color effectiveAccent) {
    if (fallbackText != null && fallbackText!.trim().isNotEmpty) {
      final initial = fallbackText!.trim().substring(0, 1).toUpperCase();
      return Center(
        child: Text(
          initial,
          style: RetroTypography.pixelHeader(
            color: effectiveAccent,
            fontSize: size * 0.32,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return Center(
      child: RetroIcon(
        'user',
        size: size * 0.38,
        color: effectiveAccent,
      ),
    );
  }
}

class _RetroCircleBorderPainter extends CustomPainter {
  final Color accentColor;
  final Color borderColor;
  final double strokeWidth;

  const _RetroCircleBorderPainter({
    required this.accentColor,
    required this.borderColor,
    this.strokeWidth = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer main circle ring
    final outerRingPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, outerRingPaint);

    // 2. Inner concentric thin track ring
    final innerTrackPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 4.0, innerTrackPaint);

    // 3. Four cardinal retro pixel notches (at 12, 3, 6, and 9 o'clock)
    final notchPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final notchLength = (size.width * 0.055).clamp(4.0, 7.0);
    final notchThickness = (size.width * 0.025).clamp(2.0, 3.5);

    // Top notch (12 o'clock)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, strokeWidth / 2 + 1.0),
        width: notchThickness,
        height: notchLength,
      ),
      notchPaint,
    );

    // Bottom notch (6 o'clock)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(center.dx, size.height - strokeWidth / 2 - 1.0),
        width: notchThickness,
        height: notchLength,
      ),
      notchPaint,
    );

    // Left notch (9 o'clock)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(strokeWidth / 2 + 1.0, center.dy),
        width: notchLength,
        height: notchThickness,
      ),
      notchPaint,
    );

    // Right notch (3 o'clock)
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width - strokeWidth / 2 - 1.0, center.dy),
        width: notchLength,
        height: notchThickness,
      ),
      notchPaint,
    );

    // 4. Subtle 8-bit diagonal pixel dots at 45°, 135°, 225°, 315°
    final dotPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    final dotSize = (size.width * 0.022).clamp(2.0, 3.0);
    for (final deg in [45, 135, 225, 315]) {
      final rad = deg * pi / 180.0;
      final dx = center.dx + (radius - 2.0) * cos(rad);
      final dy = center.dy + (radius - 2.0) * sin(rad);
      canvas.drawRect(
        Rect.fromCenter(center: Offset(dx, dy), width: dotSize, height: dotSize),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RetroCircleBorderPainter oldDelegate) =>
      oldDelegate.accentColor != accentColor ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.strokeWidth != strokeWidth;
}
