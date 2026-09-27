import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/presentation/providers/spatial_audio_provider.dart';
import 'package:my_music/presentation/widgets/retro_icon.dart';
import 'package:my_music/presentation/widgets/retro_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RetroIcon loads dolby_atmos without error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RetroTheme.darkTheme(),
        home: const Scaffold(
          body: Center(
            child: RetroIcon('dolby_atmos', size: 24),
          ),
        ),
      ),
    );
    expect(find.byType(RetroIcon), findsOneWidget);
  });

  testWidgets('RetroBadge renders with dolby_atmos icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RetroTheme.darkTheme(),
        home: const Scaffold(
          body: Center(
            child: RetroBadge(
              text: 'DOLBY ATMOS',
              icon: RetroIcon('dolby_atmos', size: 12),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RetroBadge), findsOneWidget);
    expect(find.text('DOLBY ATMOS'), findsOneWidget);
  });

  testWidgets('RetroIcon loads all 4 unique spatial audio preset icons', (tester) async {
    const presetIcons = [
      'preset_cinema',
      'preset_studio',
      'preset_transaural',
      'preset_holographic',
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: RetroTheme.darkTheme(),
        home: Scaffold(
          body: Row(
            children: presetIcons.map((icon) => RetroIcon(icon, size: 20)).toList(),
          ),
        ),
      ),
    );

    expect(find.byType(RetroIcon), findsNWidgets(4));
  });

  test('SpatialAudioNotifier presets have unique dedicated icons', () {
    final icons = SpatialAudioNotifier.presets.map((p) => p.icon).toList();
    expect(icons, contains('preset_cinema'));
    expect(icons, contains('preset_studio'));
    expect(icons, contains('preset_transaural'));
    expect(icons, contains('preset_holographic'));
    // All presets must have unique distinct icons
    expect(icons.toSet().length, equals(4));
  });
}
