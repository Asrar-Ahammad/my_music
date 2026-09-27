import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/data/repositories/settings_repository.dart';
import 'package:my_music/data/services/storage_service.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/equalizer_provider.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/mini_player_settings_provider.dart';
import 'package:my_music/presentation/providers/now_playing_settings_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/screens/home_scaffold.dart';
import 'package:my_music/presentation/screens/now_playing/now_playing_screen.dart';
import 'package:my_music/presentation/widgets/mini_player.dart';
import 'package:my_music/presentation/widgets/morphing_album_art.dart';
import 'package:my_music/presentation/widgets/retro_album_art.dart';
import 'package:my_music/presentation/widgets/retro_cassette_art.dart';
import 'package:my_music/presentation/widgets/retro_now_playing_art.dart';

class MockSettingsRepository extends SettingsRepository {
  @override
  bool isOnboardingCompleted() => true;

  @override
  bool isDarkMode() => true;

  String _miniPlayerArtStyle = 'box';
  bool _miniPlayerVinylRotating = true;

  @override
  String getMiniPlayerArtStyle() => _miniPlayerArtStyle;

  @override
  Future<void> setMiniPlayerArtStyle(String style) async {
    _miniPlayerArtStyle = style;
  }

  @override
  bool isMiniPlayerVinylRotating() => _miniPlayerVinylRotating;

  @override
  Future<void> setMiniPlayerVinylRotating(bool rotating) async {
    _miniPlayerVinylRotating = rotating;
  }

  String _nowPlayingArtStyle = 'box';
  bool _nowPlayingVinylRotating = true;

  @override
  String getNowPlayingArtStyle() => _nowPlayingArtStyle;

  @override
  Future<void> setNowPlayingArtStyle(String style) async {
    _nowPlayingArtStyle = style;
  }

  @override
  bool isNowPlayingVinylRotating() => _nowPlayingVinylRotating;

  @override
  Future<void> setNowPlayingVinylRotating(bool rotating) async {
    _nowPlayingVinylRotating = rotating;
  }
}

class MockLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() => const LibraryState(
        allSongs: [],
        albums: [],
        artists: [],
        folders: {},
        isLoading: false,
      );
}

class MockPlaylistNotifier extends PlaylistNotifier {
  @override
  PlaylistState build() => const PlaylistState(playlists: []);
}

class MockPlayerNotifierPlaying extends PlayerNotifier {
  @override
  PlayerStateModel build() {
    return const PlayerStateModel(
      currentSong: Song(
        id: 'test-morph-song',
        title: 'Morphing Chiptune',
        artist: 'Retro Master',
        album: '8-Bit Dreams',
        duration: Duration(seconds: 180),
        uri: 'assets/audio/test.wav',
        quality: AudioQuality(
          format: 'MP3',
          sampleRate: 44100,
          bitDepth: 16,
        ),
      ),
      isPlaying: true,
      duration: Duration(seconds: 180),
      position: Duration(seconds: 45),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('morph_test_');
    final storage = StorageService();
    await storage.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    } catch (_) {}
  });

  const testSong = Song(
    id: 'test-morph-song',
    title: 'Morphing Chiptune',
    artist: 'Retro Master',
    album: '8-Bit Dreams',
    duration: Duration(seconds: 180),
    uri: 'assets/audio/test.wav',
    quality: AudioQuality(
      format: 'MP3',
      sampleRate: 44100,
      bitDepth: 16,
    ),
  );

  group('MorphingAlbumArt Widget Tests', () {
    testWidgets('Renders pure Box style correctly and scales with progress', (tester) async {
      final mockSettings = MockSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(
              body: Center(
                child: MorphingAlbumArt(
                  song: testSong,
                  progress: 0.5,
                  miniSize: 44.0,
                  fullSize: 300.0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // At progress 0.5, expected size is 44 + (300 - 44) * 0.5 = 172
      final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
      final rootBox = sizedBoxes.firstWhere((sb) => sb.width == 172.0 && sb.height == 172.0);
      expect(rootBox.width, equals(172.0));
      expect(rootBox.height, equals(172.0));
      expect(find.byType(RetroAlbumArt), findsOneWidget);
    });

    testWidgets('Renders pure Vinyl style with RotationTransition when both styles are vinyl', (tester) async {
      final mockSettings = MockSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettings),
          playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
        ],
      );
      container.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.vinyl);
      container.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.vinyl);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(
              body: Center(
                child: MorphingAlbumArt(
                  song: testSong,
                  progress: 0.0,
                  miniSize: 44.0,
                  fullSize: 300.0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // RotationTransition should be present for spinning vinyl inside MorphingAlbumArt
      expect(
        find.descendant(
          of: find.byType(MorphingAlbumArt),
          matching: find.byType(RotationTransition),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Smoothly cross-fades between Box and Vinyl styles when styles differ', (tester) async {
      final mockSettings = MockSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettings),
          playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
        ],
      );
      // Mini is box, full is vinyl
      container.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.box);
      container.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.vinyl);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(
              body: Center(
                child: MorphingAlbumArt(
                  song: testSong,
                  progress: 0.5,
                  miniSize: 44.0,
                  fullSize: 300.0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // In mixed mode at progress 0.5, both Box and Vinyl should be layered inside Opacity widgets
      final opacities = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(opacities.any((o) => (o.opacity - 0.5).abs() < 0.05), isTrue);
    });

    testWidgets('Renders pure Cassette style correctly with spool rotation and scales with progress', (tester) async {
      final mockSettings = MockSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettings),
          playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
        ],
      );
      container.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.cassette);
      container.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.cassette);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(
              body: Center(
                child: MorphingAlbumArt(
                  song: testSong,
                  progress: 1.0,
                  miniSize: 44.0,
                  fullSize: 300.0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RetroCassetteArt), findsOneWidget);
      expect(find.text('MORPHING CHIPTUNE'), findsOneWidget);
      expect(find.text('SIDE A'), findsOneWidget);
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('Smoothly cross-fades between Vinyl and Cassette styles', (tester) async {
      final mockSettings = MockSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettings),
          playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
        ],
      );
      container.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.vinyl);
      container.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.cassette);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: Center(
                child: MorphingAlbumArt(
                  song: testSong,
                  progress: 0.5,
                  miniSize: 44.0,
                  fullSize: 300.0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(RetroCassetteArt), findsOneWidget);
      final opacities = tester.widgetList<Opacity>(find.byType(Opacity));
      expect(opacities.length, greaterThanOrEqualTo(2));
    });

    testWidgets('Cassette adapts cleanly to all color themes and palettes', (tester) async {
      final palettes = ['pico8', 'gameboy', 'cyberpunk', 'amber', 'midnight'];
      for (final pid in palettes) {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: RetroTheme.darkTheme(paletteId: pid),
              home: const Scaffold(
                body: Center(
                  child: RetroCassetteArt(
                    song: testSong,
                    width: 300,
                    height: 300,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(RetroCassetteArt), findsOneWidget);
      }
    });
  });

  group('Expandable Sheet Gestures in HomeScaffold', () {
    testWidgets('Swiping up on MiniPlayer smoothly expands NowPlayingScreen and swipe down collapses', (tester) async {
      final mockSettings = MockSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
            playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Initially, NowPlayingScreen is unmounted (collapsed)
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Perform a fling up gesture on the MiniPlayer
      await tester.fling(find.byType(MiniPlayer), const Offset(0, -400), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // NowPlayingScreen is now fully expanded
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Perform a fling down gesture on the NowPlayingScreen
      await tester.fling(find.byType(RetroNowPlayingArt), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // NowPlayingScreen collapses back down to MiniPlayer
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('NowPlayer and MiniPlayer maintain 100% opacity without premature fading during drag', (tester) async {
      final mockSettings = MockSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
            playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // MiniPlayer is initially at 1.0 opacity
      final initialMiniOpacity = tester.widget<Opacity>(
        find.ancestor(of: find.byType(MiniPlayer), matching: find.byType(Opacity)).first,
      );
      expect(initialMiniOpacity.opacity, 1.0);

      // Drag up slightly on MiniPlayer so NowPlaying starts appearing
      final upGesture = await tester.startGesture(tester.getCenter(find.byType(MiniPlayer)));
      await upGesture.moveBy(const Offset(0, -25)); // break slop
      await tester.pump();
      await upGesture.moveBy(const Offset(0, -100));
      await tester.pump();

      // When NowPlaying is appearing, starting opacity must be high (>= 0.85), never low/dim
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      final appearingOpacity = tester.widget<Opacity>(
        find.ancestor(of: find.byType(NowPlayingScreen), matching: find.byType(Opacity)).first,
      );
      expect(appearingOpacity.opacity, greaterThanOrEqualTo(0.85));

      await upGesture.up();
      await tester.pumpAndSettle();

      // Expand fully to NowPlaying
      await tester.fling(find.byType(MiniPlayer), const Offset(0, -600), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      final nowPlayingOpacityWidget = tester.widget<Opacity>(
        find.ancestor(of: find.byType(NowPlayingScreen), matching: find.byType(Opacity)).first,
      );
      expect(nowPlayingOpacityWidget.opacity, 1.0);

      // Start dragging down by 150px (NowPlaying is still high on screen)
      final gesture = await tester.startGesture(tester.getCenter(find.byType(RetroNowPlayingArt)));
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();

      // At t > 0.38, NowPlayingScreen must remain at 1.0 opacity (not fading prematurely!)
      final draggingNowPlayingOpacity = tester.widget<Opacity>(
        find.ancestor(of: find.byType(NowPlayingScreen), matching: find.byType(Opacity)).first,
      );
      expect(draggingNowPlayingOpacity.opacity, 1.0);

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('Cover art morphing animation starts and ends with ease and transitions smoothly', (tester) async {
      final mockSettings = MockSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
            playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final homeState = tester.state<HomeScaffoldState>(find.byType(HomeScaffold));

      // 1. Initial collapsed state:
      expect(homeState.isNowPlayingExpanded, isFalse);
      expect(find.byType(MorphingAlbumArt), findsNothing);
      expect(find.byType(NowPlayingScreen), findsNothing);

      // MiniPlayer cover art should be visible
      final initialMiniPlayer = tester.widget<MiniPlayer>(find.byType(MiniPlayer));
      expect(initialMiniPlayer.hideCoverArt, isFalse);

      // 2. Trigger expansion:
      homeState.expandNowPlaying();
      await tester.pump(); // Start controller

      // Pump a small fraction of time (e.g. 30ms into ~420ms duration)
      await tester.pump(const Duration(milliseconds: 30));

      // Because Curves.easeInOutCubic starts with zero initial slope (ease-in),
      // progress at 30ms is gentle and non-zero (easing into motion without sudden jump)
      final earlyProgress = homeState.expansionProgress;
      expect(earlyProgress, greaterThan(0.001));
      expect(earlyProgress, lessThan(0.20)); // Gentle ease-in, NOT abruptly shooting up

      // MorphingAlbumArt is immediately active to carry the cover art smoothly
      expect(find.byType(MorphingAlbumArt), findsOneWidget);
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // MiniPlayer hides its cover art while morphing takes over
      final animatingMiniPlayer = tester.widget<MiniPlayer>(find.byType(MiniPlayer));
      expect(animatingMiniPlayer.hideCoverArt, isTrue);

      // NowPlayingScreen still hides its cover art while morphing is in flight
      final earlyNowPlaying = tester.widget<NowPlayingScreen>(find.byType(NowPlayingScreen));
      expect(earlyNowPlaying.hideCoverArt, isTrue);

      // 3. Pump halfway through (~210ms)
      await tester.pump(const Duration(milliseconds: 180));
      expect(homeState.expansionProgress, greaterThan(0.20));
      expect(homeState.expansionProgress, lessThan(0.90));
      expect(find.byType(MorphingAlbumArt), findsOneWidget);

      // 4. Pump to completion (ease-out gently into rest)
      await tester.pumpAndSettle();
      expect(homeState.isNowPlayingFullyExpanded, isTrue);

      // When fully expanded: MorphingAlbumArt unmounts, NowPlayingScreen cover art is visible
      expect(find.byType(MorphingAlbumArt), findsNothing);
      final fullNowPlaying = tester.widget<NowPlayingScreen>(find.byType(NowPlayingScreen));
      expect(fullNowPlaying.hideCoverArt, isFalse);

      // 5. Trigger collapse:
      homeState.collapseNowPlaying();
      await tester.pump(); // Start controller

      // Pump 30ms into collapse:
      await tester.pump(const Duration(milliseconds: 30));
      final earlyCollapseProgress = homeState.expansionProgress;
      // Gentle ease-in at collapse start
      expect(earlyCollapseProgress, lessThan(0.999));
      expect(earlyCollapseProgress, greaterThan(0.80)); // Has eased out from 1.0 gently
      expect(find.byType(MorphingAlbumArt), findsOneWidget);

      // 6. Complete collapse:
      await tester.pumpAndSettle();
      expect(homeState.isNowPlayingExpanded, isFalse);
      expect(find.byType(MorphingAlbumArt), findsNothing);
      expect(find.byType(NowPlayingScreen), findsNothing);
      final finalMiniPlayer = tester.widget<MiniPlayer>(find.byType(MiniPlayer));
      expect(finalMiniPlayer.hideCoverArt, isFalse);
    });

    testWidgets('Swiping gesture on cover art and mini player provides fluid eased transitions', (tester) async {
      final mockSettings = MockSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
            playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final homeState = tester.state<HomeScaffoldState>(find.byType(HomeScaffold));

      // 1. Swipe up on MiniPlayer with natural fling velocity (e.g. -600 px/s)
      await tester.fling(find.byType(MiniPlayer), const Offset(0, -200), 600);
      await tester.pump(); // Start controller
      await tester.pump(const Duration(milliseconds: 40));

      // Verifies fluid progression and active morphing cover art
      expect(homeState.expansionProgress, greaterThan(0.01));
      expect(find.byType(MorphingAlbumArt), findsOneWidget);

      await tester.pumpAndSettle();
      expect(homeState.isNowPlayingFullyExpanded, isTrue);
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // 2. Swipe down on the NowPlaying cover art directly
      final coverArtFinder = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(RetroAlbumArt),
      );
      expect(coverArtFinder, findsOneWidget);

      await tester.fling(coverArtFinder, const Offset(0, 200), 600);
      await tester.pump(); // Start controller
      await tester.pump(const Duration(milliseconds: 40));

      // Verifies fluid collapse and active morphing cover art
      expect(homeState.expansionProgress, lessThan(0.99));
      expect(find.byType(MorphingAlbumArt), findsOneWidget);

      await tester.pumpAndSettle();
      expect(homeState.isNowPlayingExpanded, isFalse);
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('Sub-pixel alignment between morph layer and target slot in portrait', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final mockSettings = MockSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
            playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final homeState = tester.state<HomeScaffoldState>(find.byType(HomeScaffold));

      // Right before hand-off threshold
      homeState.setExpansionProgress(0.998);
      await tester.pump();

      final morphArtRect = tester.getRect(find.byType(MorphingAlbumArt));

      // Fully expanded hand-off
      homeState.setExpansionProgress(1.0);
      await tester.pump();

      final nowArtRect = tester.getRect(find.byType(RetroNowPlayingArt));

      expect((morphArtRect.top - nowArtRect.top).abs(), lessThan(2.0));
      expect((morphArtRect.left - nowArtRect.left).abs(), lessThan(1.0));
      expect((morphArtRect.width - nowArtRect.width).abs(), lessThan(1.0));
      expect((morphArtRect.height - nowArtRect.height).abs(), lessThan(1.0));
    });

    testWidgets('Sub-pixel alignment between morph layer and target slot in landscape', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(left: 44, right: 34);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });
      final mockSettings = MockSettingsRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
            playerProvider.overrideWith(MockPlayerNotifierPlaying.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final homeState = tester.state<HomeScaffoldState>(find.byType(HomeScaffold));

      homeState.setExpansionProgress(0.998);
      await tester.pump();

      final morphArtRect = tester.getRect(find.byType(MorphingAlbumArt));

      homeState.setExpansionProgress(1.0);
      await tester.pump();

      final nowArtRect = tester.getRect(find.byType(RetroNowPlayingArt));

      expect((morphArtRect.top - nowArtRect.top).abs(), lessThan(1.5));
      expect((morphArtRect.left - nowArtRect.left).abs(), lessThan(1.0));
      expect((morphArtRect.width - nowArtRect.width).abs(), lessThan(1.0));
      expect((morphArtRect.height - nowArtRect.height).abs(), lessThan(1.0));
    });
  });
}


