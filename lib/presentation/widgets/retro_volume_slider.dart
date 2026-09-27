import 'package:flutter/material.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import 'retro_icon.dart';

/// 8-bit retro volume slider with mute toggle button.
class RetroVolumeSlider extends StatefulWidget {
  final double volume; // 0.0 to 1.0
  final ValueChanged<double> onVolumeChanged;
  final Color? activeColor;
  final Color? inactiveColor;

  const RetroVolumeSlider({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
    this.activeColor,
    this.inactiveColor,
  });

  @override
  State<RetroVolumeSlider> createState() => _RetroVolumeSliderState();
}

class _RetroVolumeSliderState extends State<RetroVolumeSlider> {
  double _lastNonZeroVolume = 0.8;

  void _toggleMute() {
    if (widget.volume > 0.0) {
      _lastNonZeroVolume = widget.volume;
      widget.onVolumeChanged(0.0);
    } else {
      widget.onVolumeChanged(_lastNonZeroVolume > 0.05 ? _lastNonZeroVolume : 0.8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    final actColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactColor = widget.inactiveColor ?? retro.cardColor;
    final borderCol = retro.borderColor;
    final clampedVolume = widget.volume.clamp(0.0, 1.0);
    final isMuted = clampedVolume <= 0.001;

    return Row(
      children: [
        // Mute / Speaker Icon Button
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleMute,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isMuted
                  ? theme.colorScheme.error.withValues(alpha: 0.15)
                  : retro.cardColor,
              border: Border.all(
                color: isMuted ? theme.colorScheme.error : borderCol,
                width: 1.5,
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: RetroIcon(
              isMuted ? 'volume_mute' : 'volume',
              size: 16,
              color: isMuted ? theme.colorScheme.error : theme.colorScheme.onSurface,
            ),
          ),
        ),

        const SizedBox(width: 10),

        // Track with Thumb
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final barWidth = constraints.maxWidth;
              const barHeight = 12.0;
              const thumbWidth = 10.0;
              const thumbHeight = 18.0;

              void handleVolumeUpdate(double dx) {
                final clamped = dx.clamp(0.0, barWidth);
                final newVol = clamped / barWidth;
                widget.onVolumeChanged(newVol);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (details) =>
                    handleVolumeUpdate(details.localPosition.dx),
                onHorizontalDragUpdate: (details) =>
                    handleVolumeUpdate(details.localPosition.dx),
                onTapDown: (details) =>
                    handleVolumeUpdate(details.localPosition.dx),
                child: SizedBox(
                  height: thumbHeight,
                  width: barWidth,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Inactive + Active Track
                      Container(
                        height: barHeight,
                        width: barWidth,
                        decoration: BoxDecoration(
                          color: inactColor,
                          border: Border.all(
                            color: borderCol,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: (barWidth - 3.0) * clampedVolume,
                              decoration: BoxDecoration(
                                color: isMuted
                                    ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                                    : actColor,
                                borderRadius: BorderRadius.zero,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Thumb
                      Positioned(
                        left: (barWidth - thumbWidth) * clampedVolume,
                        child: Container(
                          width: thumbWidth,
                          height: thumbHeight,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            border: Border.all(
                              color: borderCol,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Center(
                            child: Container(
                              width: 2,
                              height: 8,
                              color: isMuted
                                  ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                  : actColor,
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
        ),

        const SizedBox(width: 10),

        // Volume Percentage Indicator
        SizedBox(
          width: 38,
          child: Text(
            '${(clampedVolume * 100).round()}%',
            textAlign: TextAlign.right,
            style: RetroTypography.pixelBadge(
              color: isMuted
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurface.withValues(alpha: 0.8),
              fontSize: 9,
            ),
          ),
        ),
      ],
    );
  }
}
