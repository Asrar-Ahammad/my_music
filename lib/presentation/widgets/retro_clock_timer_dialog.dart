import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../providers/player_provider.dart';
import 'retro_button.dart';
import 'retro_icon.dart';

/// A custom-designed retro 8-bit Hi-Fi clock timer dialog.
/// Features an interactive analog clock dial with retro ticks, cardinal labels,
/// sweeping pixel clock hand, digital LED/LCD readout, and quick preset steppers.
class RetroClockTimerDialog extends ConsumerStatefulWidget {
  final Duration? initialDuration;

  const RetroClockTimerDialog({
    super.key,
    this.initialDuration,
  });

  /// Shows the Retro Clock Timer dialog.
  static Future<void> show(
    BuildContext context, {
    Duration? initialDuration,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RetroClockTimerDialog(
        initialDuration: initialDuration,
      ),
    );
  }

  @override
  ConsumerState<RetroClockTimerDialog> createState() =>
      _RetroClockTimerDialogState();
}

class _RetroClockTimerDialogState extends ConsumerState<RetroClockTimerDialog>
    with SingleTickerProviderStateMixin {
  late int _minutes;
  late AnimationController _animController;
  late Animation<double> _handAnimation;
  double _animatedAngle = 0.0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    final initialMins = widget.initialDuration?.inMinutes ?? 30;
    _minutes = initialMins.clamp(1, 180);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    final targetAngle = (_minutes % 60) * (2 * math.pi / 60);
    _animatedAngle = targetAngle;
    _handAnimation = Tween<double>(begin: targetAngle, end: targetAngle)
        .animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _animateHandTo(int newMinutes) {
    final clamped = newMinutes.clamp(1, 180);
    final targetAngle = (clamped % 60) * (2 * math.pi / 60);

    _handAnimation = Tween<double>(
      begin: _animatedAngle,
      end: targetAngle,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ))..addListener(() {
        setState(() {
          _animatedAngle = _handAnimation.value;
        });
      });

    setState(() {
      _minutes = clamped;
    });

    _animController.forward(from: 0.0);
    HapticFeedback.selectionClick();
  }

  void _updateFromPan(Offset localPosition, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    // Angle clockwise starting from top (-pi/2)
    var angle = math.atan2(dy, dx) + (math.pi / 2);
    if (angle < 0) {
      angle += 2 * math.pi;
    }

    // Map angle (0 to 2*pi) to 0..60 minutes
    var minuteInHour = (angle / (2 * math.pi) * 60).round();
    if (minuteInHour <= 0) minuteInHour = 60;

    // Preserve hour tier if > 60
    final currentHourTier = (_minutes - 1) ~/ 60;
    var newMinutes = (currentHourTier * 60) + minuteInHour;
    if (newMinutes <= 0) newMinutes = 1;

    if (newMinutes != _minutes) {
      setState(() {
        _minutes = newMinutes.clamp(1, 180);
        _animatedAngle = angle;
      });
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final playerState = ref.watch(playerProvider);
    final activeTimer = playerState.sleepTimerRemaining;

    final hours = _minutes ~/ 60;
    final mins = _minutes % 60;
    final formattedTime = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:00'
        : '${mins.toString().padLeft(2, '0')}:00';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 350),
        decoration: BoxDecoration(
          color: retro.cardColor,
          border: Border.all(
            color: retro.borderColor,
            width: retro.borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: const Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                border: Border(
                  bottom: BorderSide(
                    color: retro.borderColor,
                    width: retro.borderWidth,
                  ),
                ),
              ),
              child: Row(
                children: [
                  RetroIcon(
                    'clock',
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CLOCK TIMER',
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: RetroIcon(
                      'close',
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Digital LED / LCD Readout
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: retro.isDark
                          ? const Color(0xFF0F140F)
                          : const Color(0xFFE8EEE5),
                      border: Border.all(
                        color: retro.borderColor,
                        width: retro.borderWidth,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SLEEP IN',
                              style: RetroTypography.pixelBadge(
                                color: retro.isDark
                                    ? retro.accentGreen.withValues(alpha: 0.7)
                                    : Colors.black54,
                                fontSize: 8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedTime,
                              style: RetroTypography.pixelHeader(
                                color: retro.isDark
                                    ? retro.accentGreen
                                    : theme.colorScheme.primary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: retro.accentYellow,
                            border: Border.all(
                              color: retro.borderColor,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$_minutes MIN',
                            style: RetroTypography.pixelBadge(
                              color: Colors.black,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Interactive Analog Retro Clock Face
                  Center(
                    child: SizedBox(
                      width: 180,
                      height: 180,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final size = Size(constraints.maxWidth, constraints.maxHeight);
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanStart: (details) {
                              _isDragging = true;
                              _updateFromPan(details.localPosition, size);
                            },
                            onPanUpdate: (details) {
                              _updateFromPan(details.localPosition, size);
                            },
                            onPanEnd: (_) {
                              _isDragging = false;
                            },
                            onTapDown: (details) {
                              _updateFromPan(details.localPosition, size);
                            },
                            child: CustomPaint(
                              size: size,
                              painter: _RetroClockPainter(
                                angle: _isDragging
                                    ? _animatedAngle
                                    : ((_minutes % 60) * (2 * math.pi / 60)),
                                minutes: _minutes,
                                retro: retro,
                                primaryColor: theme.colorScheme.primary,
                                accentColor: retro.accentYellow,
                                textColor: theme.colorScheme.onSurface,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Stepper row (-5, -1, +1, +5)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStepButton('-5M', () => _animateHandTo(_minutes - 5)),
                      const SizedBox(width: 6),
                      _buildStepButton('-1M', () => _animateHandTo(_minutes - 1)),
                      const SizedBox(width: 10),
                      _buildStepButton('+1M', () => _animateHandTo(_minutes + 1)),
                      const SizedBox(width: 6),
                      _buildStepButton('+5M', () => _animateHandTo(_minutes + 5)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Quick presets (15, 30, 45, 60, 90, 120)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [15, 30, 45, 60, 90, 120].map((preset) {
                      final isSelected = _minutes == preset;
                      return GestureDetector(
                        onTap: () => _animateHandTo(preset),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? retro.accentYellow
                                : retro.cardColor,
                            border: Border.all(
                              color: retro.borderColor,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '${preset}M',
                            style: RetroTypography.pixelBadge(
                              color: isSelected
                                  ? Colors.black
                                  : theme.colorScheme.onSurface,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 12),

                  // Action buttons
                  Row(
                    children: [
                      if (activeTimer != null) ...[
                        Expanded(
                          child: RetroButton(
                            isCompact: true,
                            height: 36,
                            backgroundColor: retro.cardColor,
                            textColor: theme.colorScheme.error,
                            borderColor: theme.colorScheme.error,
                            label: 'TURN OFF',
                            onPressed: () {
                              ref.read(playerProvider.notifier).setSleepTimer(null);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: RetroButton(
                          isCompact: true,
                          height: 36,
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          icon: RetroIcon(
                            'check',
                            size: 15,
                            color: theme.colorScheme.onPrimary,
                          ),
                          label: 'SET TIMER',
                          onPressed: () {
                            ref
                                .read(playerProvider.notifier)
                                .setSleepTimer(Duration(minutes: _minutes));
                            Navigator.of(context).pop();
                          },
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

  Widget _buildStepButton(String text, VoidCallback onPressed) {
    final retro = context.retro;
    final theme = Theme.of(context);
    return RetroButton(
      isCompact: true,
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      backgroundColor: retro.cardColor,
      textColor: theme.colorScheme.onSurface,
      label: text,
      onPressed: onPressed,
    );
  }
}

/// Custom painter for the retro 8-bit circular analog clock.
class _RetroClockPainter extends CustomPainter {
  final double angle; // in radians from top
  final int minutes;
  final RetroThemeTokens retro;
  final Color primaryColor;
  final Color accentColor;
  final Color textColor;

  _RetroClockPainter({
    required this.angle,
    required this.minutes,
    required this.retro,
    required this.primaryColor,
    required this.accentColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 4.0;

    // 1. Clock face background fill
    final bgPaint = Paint()
      ..color = retro.cardColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Outer retro border
    final borderPaint = Paint()
      ..color = retro.borderColor
      ..strokeWidth = retro.borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, borderPaint);

    // Inner decorative dashed/dotted ring
    final innerRingPaint = Paint()
      ..color = retro.borderColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 8.0, innerRingPaint);

    // 3. Active elapsed wedge/arc
    if (minutes > 0) {
      final sweepAngle = angle <= 0.05 ? 2 * math.pi : angle;
      final wedgePaint = Paint()
        ..color = accentColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill;

      final wedgePath = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius - 3.0),
          -math.pi / 2,
          sweepAngle,
          false,
        )
        ..close();
      canvas.drawPath(wedgePath, wedgePaint);
    }

    // 4. Tick marks (60 ticks: 12 major ticks at 5-min intervals, minor ticks in between)
    final majorTickPaint = Paint()
      ..color = retro.borderColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    final minorTickPaint = Paint()
      ..color = retro.borderColor.withValues(alpha: 0.4)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.square;

    for (var i = 0; i < 60; i++) {
      final tickAngle = i * (2 * math.pi / 60) - (math.pi / 2);
      final isMajor = i % 5 == 0;
      final tickLength = isMajor ? 8.0 : 4.0;

      final startR = radius - 2.0;
      final endR = startR - tickLength;

      final p1 = Offset(
        center.dx + startR * math.cos(tickAngle),
        center.dy + startR * math.sin(tickAngle),
      );
      final p2 = Offset(
        center.dx + endR * math.cos(tickAngle),
        center.dy + endR * math.sin(tickAngle),
      );

      canvas.drawLine(p1, p2, isMajor ? majorTickPaint : minorTickPaint);
    }

    // 5. Cardinal numbers: 0, 15, 30, 45
    _drawCardinalText(canvas, center, '0', 0, radius - 18);
    _drawCardinalText(canvas, center, '15', 15, radius - 18);
    _drawCardinalText(canvas, center, '30', 30, radius - 18);
    _drawCardinalText(canvas, center, '45', 45, radius - 18);

    // 6. Clock Hand
    final handAngle = angle - (math.pi / 2);
    final handLength = radius - 22.0;

    final handTip = Offset(
      center.dx + handLength * math.cos(handAngle),
      center.dy + handLength * math.sin(handAngle),
    );

    // Hand shaft
    final handShaftPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(center, handTip, handShaftPaint);

    // Hand pointer head (retro triangle/diamond)
    final arrowBaseR = handLength - 10.0;
    final perpAngle = handAngle + math.pi / 2;
    const arrowHalfWidth = 5.0;

    final baseLeft = Offset(
      center.dx +
          arrowBaseR * math.cos(handAngle) +
          arrowHalfWidth * math.cos(perpAngle),
      center.dy +
          arrowBaseR * math.sin(handAngle) +
          arrowHalfWidth * math.sin(perpAngle),
    );
    final baseRight = Offset(
      center.dx +
          arrowBaseR * math.cos(handAngle) -
          arrowHalfWidth * math.cos(perpAngle),
      center.dy +
          arrowBaseR * math.sin(handAngle) -
          arrowHalfWidth * math.sin(perpAngle),
    );

    final arrowPath = Path()
      ..moveTo(handTip.dx, handTip.dy)
      ..lineTo(baseLeft.dx, baseLeft.dy)
      ..lineTo(baseRight.dx, baseRight.dy)
      ..close();

    final arrowPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(arrowPath, arrowPaint);

    final arrowBorderPaint = Paint()
      ..color = retro.borderColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(arrowPath, arrowBorderPaint);

    // 7. Center cap / rivet
    final centerOuterPaint = Paint()
      ..color = retro.borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 6.0, centerOuterPaint);

    final centerInnerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3.5, centerInnerPaint);
  }

  void _drawCardinalText(
    Canvas canvas,
    Offset center,
    String text,
    int minute,
    double r,
  ) {
    final cardinalAngle = minute * (2 * math.pi / 60) - (math.pi / 2);
    final pos = Offset(
      center.dx + r * math.cos(cardinalAngle),
      center.dy + r * math.sin(cardinalAngle),
    );

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: RetroTypography.currentFontFamily,
        fontSize: 8.0,
        fontWeight: FontWeight.bold,
        color: textColor.withValues(alpha: 0.8),
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final textOffset = Offset(
      pos.dx - textPainter.width / 2,
      pos.dy - textPainter.height / 2,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _RetroClockPainter oldDelegate) {
    return oldDelegate.angle != angle ||
        oldDelegate.minutes != minutes ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.textColor != textColor;
  }
}
