import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../providers/equalizer_provider.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../spatial_audio/spatial_audio_screen.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  static const List<String> bandLabels = [
    '60 Hz\n(SUB)',
    '230 Hz\n(BASS)',
    '910 Hz\n(MID)',
    '3.6 kHz\n(TREBLE)',
    '14 kHz\n(AIR)',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eqState = ref.watch(equalizerProvider);
    final eqNotifier = ref.read(equalizerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const RetroIcon('arrow_left', size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'EQUALIZER',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Master toggle card
            RetroCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: eqState.isEnabled ? theme.colorScheme.primary : retro.cardColor,
                      border: Border.all(color: retro.borderColor, width: 2.0),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Center(
                      child: RetroIcon(
                        'sliders',
                        size: 20,
                        color: eqState.isEnabled ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EQUALIZER DSP',
                          style: RetroTypography.pixelBadge(
                            color: theme.colorScheme.onSurface,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          eqState.isEnabled ? 'ACTIVE • 5 BANDS' : 'BYPASSED',
                          style: RetroTypography.retroMono(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RetroButton(
                    isCompact: true,
                    label: eqState.isEnabled ? 'ON' : 'OFF',
                    backgroundColor: eqState.isEnabled ? retro.accentGreen : retro.cardColor,
                    textColor: eqState.isEnabled ? Colors.black : theme.colorScheme.onSurface,
                    onPressed: () => eqNotifier.toggleEnabled(!eqState.isEnabled),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Presets selector
            Text(
              'PRESETS',
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EqualizerNotifier.presets.keys.map((preset) {
                final isSelected = eqState.currentPreset == preset;
                return RetroButton(
                  isCompact: true,
                  label: preset.toUpperCase(),
                  backgroundColor: isSelected ? theme.colorScheme.primary : retro.cardColor,
                  textColor: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  borderColor: isSelected ? retro.borderColor : retro.borderColor,
                  onPressed: () => eqNotifier.setPreset(preset),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // 5 Band Sliders Card
            RetroCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              title: '5-BAND FREQUENCY RESPONSE',
              titleTrailing: RetroBadge(
                text: '±10 dB',
                backgroundColor: retro.cardColor,
                fontSize: 8,
              ),
              child: Opacity(
                opacity: eqState.isEnabled ? 1.0 : 0.45,
                child: SizedBox(
                  height: 220,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(5, (bandIdx) {
                      final gain = eqState.bandGains[bandIdx];
                      final label = bandLabels[bandIdx];

                      return Expanded(
                        child: Column(
                          children: [
                            // Current dB readout
                            Text(
                              '${gain >= 0 ? '+' : ''}${gain.toStringAsFixed(1)}',
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.primary,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Vertical Slider
                            Expanded(
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 8,
                                    activeTrackColor: theme.colorScheme.primary,
                                    inactiveTrackColor: retro.cardColor,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 8,
                                      elevation: 0,
                                      pressedElevation: 0,
                                    ),
                                  ),
                                  child: Slider(
                                    value: gain,
                                    min: -10.0,
                                    max: 10.0,
                                    divisions: 20,
                                    onChanged: eqState.isEnabled
                                        ? (val) => eqNotifier.setBandGain(bandIdx, val)
                                        : null,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 6),

                            // Frequency label
                            Text(
                              label,
                              textAlign: TextAlign.center,
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface,
                                fontSize: 7.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Spatial Audio Studio link
            RetroCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: retro.cardColor,
                      border: Border.all(color: retro.borderColor, width: 1.5),
                    ),
                    child: Center(
                      child: RetroIcon(
                        'dolby_atmos',
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DOLBY ATMOS & SPATIAL AUDIO',
                          style: RetroTypography.pixelBadge(
                            color: theme.colorScheme.onSurface,
                            fontSize: 9.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Configure 3D soundfield & acoustic stage',
                          style: RetroTypography.retroMono(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RetroButton(
                    isCompact: true,
                    label: 'STUDIO',
                    backgroundColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SpatialAudioScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
