import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../providers/spatial_audio_provider.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_toast.dart';

class SpatialAudioScreen extends ConsumerWidget {
  const SpatialAudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spatialState = ref.watch(spatialAudioProvider);
    final spatialNotifier = ref.read(spatialAudioProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;
    final onPrimary = theme.colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const RetroIcon('arrow_left', size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SPATIAL AUDIO STUDIO',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'System Sound Settings',
            icon: const RetroIcon('sliders', size: 20),
            onPressed: () async {
              final ok = await spatialNotifier.openSystemSettings();
              if (!ok && context.mounted) {
                RetroToast.show(
                  context,
                  'SYSTEM AUDIO PANEL NOT FOUND',
                  icon: 'alert',
                  iconColor: retro.accentYellow,
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Master switch card
            RetroCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: spatialState.isEnabled
                          ? (retro.isDark
                              ? retro.cardColor
                              : theme.colorScheme.primary)
                          : retro.cardColor,
                      border: Border.all(
                        color: spatialState.isEnabled
                            ? retro.accentGreen
                            : retro.borderColor,
                        width: 2.0,
                      ),
                    ),
                    child: Center(
                      child: RetroIcon(
                        'dolby_atmos',
                        size: 24,
                        color: spatialState.isEnabled
                            ? (retro.isDark ? retro.accentGreen : onPrimary)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOLBY ATMOS & 3D SPATIAL',
                          style: RetroTypography.pixelBadge(
                            color: theme.colorScheme.onSurface,
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          spatialState.isEnabled
                              ? 'ACTIVE • ${(spatialState.strength / 10).round()}% STRENGTH'
                              : 'VIRTUALIZATION BYPASSED',
                          style: RetroTypography.retroMono(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: spatialState.isEnabled,
                    activeTrackColor: retro.accentGreen,
                    onChanged: (val) async {
                      await spatialNotifier.toggleEnabled(val);
                      if (context.mounted) {
                        RetroToast.show(
                          context,
                          val ? 'SPATIAL 3D ACTIVATED' : 'SPATIAL 3D DISABLED',
                          icon: val ? 'check' : 'close',
                          iconColor:
                              val ? retro.accentGreen : retro.accentYellow,
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Soundstage Visualizer Radar Card
            RetroCard(
              padding: const EdgeInsets.all(14),
              title: '3D SOUNDFIELD RADAR',
              titleTrailing: RetroBadge(
                text: spatialState.mode.toUpperCase(),
                backgroundColor: spatialState.isEnabled
                    ? retro.accentGreen
                    : retro.cardColor,
                textColor: spatialState.isEnabled ? Colors.black : Colors.white,
                fontSize: 8.5,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(220, 180),
                        painter: _SoundfieldRadarPainter(
                          width: spatialState.soundstageWidth,
                          depth: spatialState.soundstageDepth,
                          isEnabled: spatialState.isEnabled,
                          accentColor: theme.colorScheme.primary,
                          radarColor: retro.accentGreen,
                          gridColor: retro.borderColor.withValues(alpha: 0.35),
                          textColor: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildRadarSpecTag(
                        context,
                        'SPREAD',
                        '${(spatialState.soundstageWidth * 100).round()}%',
                      ),
                      _buildRadarSpecTag(
                        context,
                        'DEPTH',
                        '${(spatialState.soundstageDepth * 100).round()}%',
                      ),
                      _buildRadarSpecTag(
                        context,
                        'CHANNEL MATRIX',
                        spatialState.mode == 'binaural' ? '2.0 -> 7.1.4' : 'STEREO WIDE',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Presets selector
            Text(
              'IMMERSIVE PRESETS',
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),
            Column(
              children: SpatialAudioNotifier.presets.map((preset) {
                final isSelected =
                    spatialState.currentPreset.toUpperCase() ==
                        preset.title.toUpperCase();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: spatialState.isEnabled
                        ? () => spatialNotifier.applyPreset(preset)
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : retro.cardColor,
                        border: Border.all(
                          color: isSelected
                              ? (retro.isDark
                                  ? retro.accentGreen
                                  : theme.colorScheme.primary)
                              : retro.borderColor,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (retro.isDark
                                      ? retro.cardColor
                                      : theme.colorScheme.primary)
                                  : retro.cardColor,
                              border: Border.all(
                                color: isSelected
                                    ? (retro.isDark
                                        ? retro.accentGreen
                                        : theme.colorScheme.primary)
                                    : retro.borderColor,
                                width: isSelected ? 2.0 : 1.5,
                              ),
                            ),
                            child: Center(
                              child: RetroIcon(
                                preset.icon,
                                size: 18,
                                color: isSelected
                                    ? (retro.isDark
                                        ? retro.accentGreen
                                        : onPrimary)
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  preset.title,
                                  style: RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 9.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  preset.subtitle,
                                  style: RetroTypography.retroMono(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            RetroBadge(
                              text: 'ACTIVE',
                              backgroundColor: retro.accentGreen,
                              textColor: Colors.black,
                              fontSize: 7.5,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Virtualization strength slider card
            RetroCard(
              padding: const EdgeInsets.all(14),
              title: 'VIRTUALIZATION STRENGTH',
              titleTrailing: RetroBadge(
                text: '${(spatialState.strength / 10).round()}%',
                backgroundColor: theme.colorScheme.primary,
                textColor: onPrimary,
                fontSize: 8.5,
              ),
              child: Opacity(
                opacity: spatialState.isEnabled ? 1.0 : 0.45,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 6,
                        activeTrackColor: theme.colorScheme.primary,
                        inactiveTrackColor:
                            retro.borderColor.withValues(alpha: 0.4),
                        thumbColor: theme.colorScheme.primary,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7,
                          elevation: 0,
                          pressedElevation: 0,
                        ),
                      ),
                      child: Slider(
                        value: spatialState.strength.toDouble(),
                        min: 0,
                        max: 1000,
                        divisions: 20,
                        onChanged: spatialState.isEnabled
                            ? (val) => spatialNotifier.setStrength(val.round())
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'OUTPUT ACOUSTIC MODE',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 8.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: RetroButton(
                            isCompact: true,
                            label: 'BINAURAL (HEADPHONES)',
                            backgroundColor: spatialState.mode == 'binaural'
                                ? theme.colorScheme.primary
                                : retro.cardColor,
                            textColor: spatialState.mode == 'binaural'
                                ? onPrimary
                                : theme.colorScheme.onSurface,
                            onPressed: spatialState.isEnabled
                                ? () => spatialNotifier.setMode('binaural')
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: RetroButton(
                            isCompact: true,
                            label: 'TRANSAURAL (SPEAKERS)',
                            backgroundColor: spatialState.mode == 'transaural'
                                ? theme.colorScheme.primary
                                : retro.cardColor,
                            textColor: spatialState.mode == 'transaural'
                                ? onPrimary
                                : theme.colorScheme.onSurface,
                            onPressed: spatialState.isEnabled
                                ? () => spatialNotifier.setMode('transaural')
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Hardware & Codec Diagnostics Card
            RetroCard(
              padding: const EdgeInsets.all(14),
              title: 'HARDWARE & CODEC DIAGNOSTICS',
              titleTrailing: RetroBadge(
                text: 'DIAGNOSTIC',
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                fontSize: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDiagnosticRow(
                    context,
                    'DOLBY DIGITAL PLUS (E-AC-3)',
                    spatialState.capabilities.hasDolbyEac3Decoder
                        ? 'HARDWARE ACCELERATED'
                        : 'SOFTWARE EMULATED',
                    isOk: spatialState.capabilities.hasDolbyEac3Decoder,
                  ),
                  _buildDiagnosticRow(
                    context,
                    'DOLBY ATMOS (E-AC-3 JOC)',
                    spatialState.capabilities.hasDolbyEac3Decoder
                        ? 'NATIVE BITSTREAM READY'
                        : 'VIRTUALIZED 3D DSP',
                    isOk: true,
                  ),
                  _buildDiagnosticRow(
                    context,
                    'DOLBY AC-4 MULTI-STREAM',
                    spatialState.capabilities.hasDolbyAc4Decoder
                        ? 'DETECTED'
                        : 'UNSUPPORTED BY OEM SOC',
                    isOk: spatialState.capabilities.hasDolbyAc4Decoder,
                  ),
                  _buildDiagnosticRow(
                    context,
                    'ANDROID SPATIALIZER API',
                    spatialState.capabilities.isSpatializerAvailable
                        ? (spatialState.capabilities.isSpatializerEnabled
                            ? 'ENABLED (API 32+)'
                            : 'AVAILABLE (OFF)')
                        : 'NOT AVAILABLE (PRE-API 32)',
                    isOk: spatialState.capabilities.isSpatializerAvailable,
                  ),
                  _buildDiagnosticRow(
                    context,
                    'DEVICE HEAD TRACKING',
                    spatialState.capabilities.isHeadTrackerAvailable
                        ? 'SUPPORTED'
                        : 'NOT PRESENT',
                    isOk: spatialState.capabilities.isHeadTrackerAvailable,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: RetroButton(
                      isCompact: true,
                      label: 'LAUNCH SYSTEM DOLBY ATMOS DSP',
                      backgroundColor: retro.cardColor,
                      textColor: theme.colorScheme.primary,
                      onPressed: () async {
                        final ok = await spatialNotifier.openSystemSettings();
                        if (!ok && context.mounted) {
                          RetroToast.show(
                            context,
                            'SYSTEM AUDIO PANEL NOT FOUND',
                            icon: 'alert',
                            iconColor: retro.accentYellow,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRadarSpecTag(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RetroTypography.pixelBadge(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 7.5,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: RetroTypography.retroMono(
            color: theme.colorScheme.primary,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDiagnosticRow(
    BuildContext context,
    String label,
    String value, {
    required bool isOk,
  }) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: RetroTypography.retroMono(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          RetroBadge(
            text: value,
            backgroundColor: isOk
                ? retro.accentGreen.withValues(alpha: 0.2)
                : retro.borderColor.withValues(alpha: 0.2),
            textColor: isOk ? retro.accentGreen : theme.colorScheme.onSurface,
            fontSize: 7.5,
          ),
        ],
      ),
    );
  }
}

class _SoundfieldRadarPainter extends CustomPainter {
  final double width;
  final double depth;
  final bool isEnabled;
  final Color accentColor;
  final Color radarColor;
  final Color gridColor;
  final Color textColor;

  _SoundfieldRadarPainter({
    required this.width,
    required this.depth,
    required this.isEnabled,
    required this.accentColor,
    required this.radarColor,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.44;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Concentric radar rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), gridPaint);
    }

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - maxRadius, center.dy),
      Offset(center.dx + maxRadius, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - maxRadius),
      Offset(center.dx, center.dy + maxRadius),
      gridPaint,
    );

    // Diagonal lines
    final dOffset = maxRadius * 0.707;
    canvas.drawLine(
      Offset(center.dx - dOffset, center.dy - dOffset),
      Offset(center.dx + dOffset, center.dy + dOffset),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx - dOffset, center.dy + dOffset),
      Offset(center.dx + dOffset, center.dy - dOffset),
      gridPaint,
    );

    // Dynamic 3D Soundstage Ellipse
    final activeColor = isEnabled ? radarColor : gridColor;
    final stagePaint = Paint()
      ..color = activeColor.withValues(alpha: isEnabled ? 0.35 : 0.15)
      ..style = PaintingStyle.fill;

    final stageBorderPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rx = maxRadius * width.clamp(0.2, 1.0);
    final ry = maxRadius * depth.clamp(0.2, 1.0);
    final stageRect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);

    canvas.drawOval(stageRect, stagePaint);
    canvas.drawOval(stageRect, stageBorderPaint);

    // Listener center head
    final headPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 5, headPaint);

    // Surround Speaker Nodes (5.1 / 7.1.4 layout points)
    final speakerAngles = [
      -math.pi / 2, // Center (Front)
      -math.pi * 0.7, // Front Left
      -math.pi * 0.3, // Front Right
      -math.pi * 0.88, // Surround Left
      -math.pi * 0.12, // Surround Right
      math.pi * 0.75, // Rear Left
      math.pi * 0.25, // Rear Right
    ];

    final speakerPaint = Paint()
      ..color = isEnabled ? activeColor : gridColor
      ..style = PaintingStyle.fill;

    for (final angle in speakerAngles) {
      final sx = center.dx + (rx * 0.9) * math.cos(angle);
      final sy = center.dy + (ry * 0.9) * math.sin(angle);
      canvas.drawRect(Rect.fromCenter(center: Offset(sx, sy), width: 6, height: 6), speakerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundfieldRadarPainter oldDelegate) {
    return oldDelegate.width != width ||
        oldDelegate.depth != depth ||
        oldDelegate.isEnabled != isEnabled ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.radarColor != radarColor;
  }
}
