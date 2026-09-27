import 'package:flutter/material.dart';

/// Subtle CRT scanline effect painter for authentic retro CRT display cues.
class RetroScanlineOverlay extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final double opacity;

  const RetroScanlineOverlay({
    super.key,
    required this.child,
    this.enabled = true,
    this.opacity = 0.04,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                isComplex: true,
                willChange: false,
                painter: _ScanlinePainter(
                  opacity: opacity,
                  lineSpacing: 4.0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  final double opacity;
  final double lineSpacing;

  _ScanlinePainter({required this.opacity, required this.lineSpacing});

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
  bool shouldRepaint(covariant _ScanlinePainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.lineSpacing != lineSpacing;
}
