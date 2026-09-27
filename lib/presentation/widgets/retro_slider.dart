import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../../core/utils/duration_formatter.dart';

/// Pixel-styled seek bar for 8-bit retro arcade.
class RetroSlider extends StatefulWidget {
  final Duration position;
  final Duration duration;
  final ValueChanged<Duration> onSeek;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showTimeLabels;

  const RetroSlider({
    super.key,
    required this.position,
    required this.duration,
    required this.onSeek,
    this.activeColor,
    this.inactiveColor,
    this.showTimeLabels = true,
  });

  @override
  State<RetroSlider> createState() => _RetroSliderState();
}

class _RetroSliderState extends State<RetroSlider> {
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    final actColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactColor = widget.inactiveColor ?? retro.cardColor;
    final borderCol = retro.borderColor;

    final totalMs =
        widget.duration.inMilliseconds > 0 ? widget.duration.inMilliseconds : 1;
    final curMs = widget.position.inMilliseconds.clamp(0, totalMs);
    final currentProgress = (curMs / totalMs).clamp(0.0, 1.0);
    final effectiveProgress = _isDragging ? _dragValue : currentProgress;
    final displayPosition = _isDragging
        ? Duration(milliseconds: (_dragValue * totalMs).round())
        : widget.position;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = constraints.maxWidth;
            const barHeight = 16.0;
            const thumbWidth = 14.0;
            const thumbHeight = 22.0;

            final maxFillWidth = (barWidth - 4.0).clamp(0.0, double.infinity);
            final maxThumbTravel =
                (barWidth - thumbWidth).clamp(0.0, double.infinity);

            void updateDrag(double dx) {
              final clamped = dx.clamp(0.0, barWidth);
              final pct =
                  barWidth > 0 ? (clamped / barWidth).clamp(0.0, 1.0) : 0.0;
              setState(() {
                _isDragging = true;
                _dragValue = pct;
              });
            }

            void commitSeek(double dx) {
              final clamped = dx.clamp(0.0, barWidth);
              final pct =
                  barWidth > 0 ? (clamped / barWidth).clamp(0.0, 1.0) : 0.0;
              final targetMs = (pct * totalMs).round();
              setState(() {
                _isDragging = false;
              });
              widget.onSeek(Duration(milliseconds: targetMs));
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (details) =>
                  updateDrag(details.localPosition.dx),
              onHorizontalDragUpdate: (details) =>
                  updateDrag(details.localPosition.dx),
              onHorizontalDragEnd: (details) {
                final targetMs = (_dragValue * totalMs).round();
                setState(() {
                  _isDragging = false;
                });
                widget.onSeek(Duration(milliseconds: targetMs));
              },
              onHorizontalDragCancel: () {
                setState(() {
                  _isDragging = false;
                });
              },
              onTapDown: (details) => commitSeek(details.localPosition.dx),
              child: SizedBox(
                height: thumbHeight,
                width: barWidth,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // Outer track
                    Container(
                      height: barHeight,
                      width: barWidth,
                      decoration: BoxDecoration(
                        color: inactColor,
                        border: Border.all(
                          color: borderCol,
                          width: 2.0,
                        ),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: (maxFillWidth * effectiveProgress)
                              .clamp(0.0, maxFillWidth),
                          height: double.infinity,
                          color: actColor,
                        ),
                      ),
                    ),

                    // Thumb
                    Positioned(
                      left: (maxThumbTravel * effectiveProgress)
                          .clamp(0.0, maxThumbTravel),
                      child: Container(
                        width: thumbWidth,
                        height: thumbHeight,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(
                            color: borderCol,
                            width: 2.5,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Center(
                          child: Container(
                            width: 4,
                            height: 10,
                            color: actColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (widget.showTimeLabels) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DurationFormatter.format(displayPosition),
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface,
                  fontSize: 10,
                ),
              ),
              Text(
                DurationFormatter.format(widget.duration),
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
