import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/widgets/retro_song_tile.dart';

void main() {
  const testSong = Song(
    id: 'test-song-jet-black',
    title: 'Neon Shadows',
    artist: 'Cyber Runner',
    album: 'Pitch Black',
    duration: Duration(seconds: 210),
    uri: 'assets/audio/test.mp3',
    quality: AudioQuality(format: 'FLAC', sampleRate: 48000, bitDepth: 24),
  );

  testWidgets('RetroSongTile checkbox has high contrast in Jet Black theme when selected', (tester) async {
    final jetBlackTheme = RetroTheme.darkTheme(paletteId: 'jet_black');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: jetBlackTheme,
          home: const Scaffold(
            body: RetroSongTile(
              song: testSong,
              queue: [testSong],
              selectionMode: true,
              isSelected: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Check icon should be present
    final checkIconFinder = find.byIcon(Icons.check);
    expect(checkIconFinder, findsOneWidget);

    final checkIcon = tester.widget<Icon>(checkIconFinder);
    // In Jet Black, primary is white (0xFFFFFFFF). The check icon color MUST be onPrimary (0xFF0F0E0E dark ink), NOT Colors.white!
    expect(checkIcon.color, equals(jetBlackTheme.colorScheme.onPrimary));
    expect(checkIcon.color, isNot(equals(Colors.white)));
    expect(checkIcon.color, equals(const Color(0xFF0F0E0E)));
  });

  testWidgets('RetroSongTile checkbox has visible retro border and card background when unselected', (tester) async {
    final jetBlackTheme = RetroTheme.darkTheme(paletteId: 'jet_black');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: jetBlackTheme,
          home: const Scaffold(
            body: RetroSongTile(
              song: testSong,
              queue: [testSong],
              selectionMode: true,
              isSelected: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In unselected mode, check icon should NOT be present
    expect(find.byIcon(Icons.check), findsNothing);

    // The animated container box should have retro.cardColor and retro.borderColor
    final containerFinder = find.byType(AnimatedContainer);
    expect(containerFinder, findsWidgets);

    final animatedContainer = tester.widget<AnimatedContainer>(containerFinder.last);
    final decoration = animatedContainer.decoration as BoxDecoration;
    expect(decoration.color, equals(const Color(0xFF181818))); // retro.cardColor in Jet Black
    expect(decoration.border, isNotNull);
  });
}
