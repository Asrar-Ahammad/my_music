import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/screens/now_playing/queue_sheet.dart';
import 'package:my_music/presentation/screens/search/search_screen.dart';
import 'package:my_music/presentation/widgets/retro_icon.dart';
import 'package:my_music/presentation/widgets/retro_song_tile.dart';

const _testSong1 = Song(
  id: 'song_1',
  title: 'Cyberpunk Beat',
  artist: 'SynthWave',
  album: 'Neon 80s',
  duration: Duration(seconds: 180),
  uri: 'assets/audio/cyberpunk.wav',
  quality: AudioQuality(format: 'FLAC', bitDepth: 24, sampleRate: 96000),
);

const _testSong2 = Song(
  id: 'song_2',
  title: 'Pixel Fantasy',
  artist: 'Chiptune Hero',
  album: 'Retro Quest',
  duration: Duration(seconds: 150),
  uri: 'assets/audio/pixel.wav',
  quality: AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
);

class MockPlayingNotifier extends PlayerNotifier {
  @override
  PlayerStateModel build() {
    return const PlayerStateModel(
      currentSong: _testSong1,
      isPlaying: true,
      currentIndex: -1, // Intentionally -1 to test robust matching
      queue: [_testSong1, _testSong2],
    );
  }
}

class MockLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() {
    return const LibraryState(
      allSongs: [_testSong1, _testSong2],
      isLoading: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Song Card Playing Highlight Verification', () {
    testWidgets('RetroSongTile renders playing border and volume icon for active song', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayingNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: Scaffold(
              body: Column(
                children: const [
                  RetroSongTile(song: _testSong1, queue: [_testSong1, _testSong2]),
                  RetroSongTile(song: _testSong2, queue: [_testSong1, _testSong2]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the tiles
      final tiles = find.byType(RetroSongTile);
      expect(tiles, findsNWidgets(2));

      // The first tile is currently playing
      final firstTile = tester.widget<RetroSongTile>(tiles.first);
      expect(firstTile.song.id, equals(_testSong1.id));

      // Check volume icon is rendered for the playing song
      final volumeIcon = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'volume');
      expect(volumeIcon, findsOneWidget);

      // Verify the AnimatedContainer has the accent border for the playing tile
      final containers = find.descendant(of: tiles.first, matching: find.byType(AnimatedContainer));
      expect(containers, findsWidgets);

      bool foundBorder = false;
      for (final element in containers.evaluate()) {
        final widget = element.widget as AnimatedContainer;
        if (widget.decoration is BoxDecoration) {
          final box = widget.decoration as BoxDecoration;
          if (box.border != null) {
            foundBorder = true;
            break;
          }
        }
      }
      expect(foundBorder, isTrue);
    });

    testWidgets('QueueSheet song card highlights current playing song even when currentIndex is -1', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayingNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(
              body: QueueSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify play RetroIcon is shown inside the active song card in QueueSheet
      final playIcons = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'play');
      expect(playIcons, findsOneWidget);

      // Find the song cards in QueueSheet
      final item1Card = find.byKey(const ValueKey('song_1_0'));
      expect(item1Card, findsOneWidget);

      final containerWidget = tester.widget<Container>(item1Card);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.border, isNotNull);
      final border = decoration.border as Border;
      expect(border.top.width, equals(2.0));
    });

    testWidgets('SearchScreen renders song cards with RetroSongTile and active highlight', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayingNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const SearchScreen(isActive: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Search results now use RetroSongTile
      final tiles = find.byType(RetroSongTile);
      expect(tiles, findsNWidgets(2));

      // Active playing song has volume icon in search screen
      final volumeIcon = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'volume');
      expect(volumeIcon, findsOneWidget);
    });

    testWidgets('Song cards in RetroSongTile and QueueSheet display quality and bitrate badges', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayingNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: Scaffold(
              body: Column(
                children: const [
                  RetroSongTile(song: _testSong1, queue: [_testSong1, _testSong2]),
                  RetroSongTile(song: _testSong2, queue: [_testSong1, _testSong2]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check that RetroSongTile song cards show audio quality specs, not just extension
      expect(find.text('24-BIT 96kHz'), findsOneWidget);
      expect(find.text('LOSSLESS'), findsOneWidget);

      // Now verify QueueSheet song cards
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayingNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(
              body: QueueSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify quality badges do NOT appear in QueueSheet song cards
      expect(find.text('24-BIT 96kHz'), findsNothing);
      expect(find.text('LOSSLESS'), findsNothing);
    });
  });
}
