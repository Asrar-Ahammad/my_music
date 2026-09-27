import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/data/repositories/settings_repository.dart';
import 'package:my_music/data/services/audio_player_handler.dart';
import 'package:my_music/data/services/storage_service.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/playlist.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/equalizer_provider.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/screens/playlists/playlist_detail_screen.dart';

class _MockSettingsRepo extends SettingsRepository {
  @override
  bool isDarkMode() => false;
}

class _MockPlaylistNotifier extends PlaylistNotifier {
  final Playlist playlist;
  _MockPlaylistNotifier(this.playlist);

  @override
  PlaylistState build() => PlaylistState(playlists: [playlist], isLoading: false);
}

class _MockLibraryNotifier extends LibraryNotifier {
  final List<Song> songs;
  _MockLibraryNotifier(this.songs);

  @override
  LibraryState build() => LibraryState(
        allSongs: songs,
        folders: {},
        isLoading: false,
      );
}

class _ScenarioTestingPlayerNotifier extends PlayerNotifier {
  @override
  PlayerStateModel build() => const PlayerStateModel();

  @override
  Future<void> playPlaylist({
    required String playlistId,
    required List<Song> songs,
    Song? initialSong,
    bool? forceShuffle,
  }) async {
    final storage = StorageService();
    final settings = storage.getPlaylistPlaybackSettings(playlistId);
    final savedShuffle = settings['isShuffle'] as bool? ?? false;
    final savedLoopStr = settings['loopMode'] as String? ?? 'off';
    final savedLoop = RetroLoopMode.values.firstWhere(
      (e) => e.name == savedLoopStr,
      orElse: () => RetroLoopMode.off,
    );

    final targetShuffle = forceShuffle ?? savedShuffle;
    final targetLoop = savedLoop;

    List<Song> playQueue;
    int targetIndex = 0;

    if (targetShuffle) {
      if (initialSong != null) {
        final otherSongs = List<Song>.from(songs)
          ..removeWhere((s) => s.id == initialSong.id)
          ..shuffle();
        playQueue = [initialSong, ...otherSongs];
        targetIndex = 0;
      } else {
        playQueue = List<Song>.from(songs)..shuffle();
        targetIndex = 0;
      }
    } else {
      playQueue = List<Song>.from(songs);
      if (initialSong != null) {
        final idx = playQueue.indexWhere((s) => s.id == initialSong.id);
        targetIndex = idx != -1 ? idx : 0;
      } else {
        targetIndex = 0;
      }
    }

    final startSong = playQueue[targetIndex];

    state = state.copyWith(
      currentSong: startSong,
      queue: playQueue,
      currentIndex: targetIndex,
      currentPlaylistId: playlistId,
      isShuffle: targetShuffle,
      loopMode: targetLoop,
    );
  }
}

void main() {
  final List<Song> testSongs = [
    const Song(
      id: 'song_1',
      title: 'Alpha Beat',
      artist: 'Retro Wave',
      album: 'Synth City',
      duration: Duration(seconds: 120),
      uri: 'assets/audio/1.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    ),
    const Song(
      id: 'song_2',
      title: 'Beta Groove',
      artist: 'Pixel Sound',
      album: '8Bit Dreams',
      duration: Duration(seconds: 140),
      uri: 'assets/audio/2.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    ),
    const Song(
      id: 'song_3',
      title: 'Gamma Pulse',
      artist: 'Chiptune Hero',
      album: 'Arcade Life',
      duration: Duration(seconds: 160),
      uri: 'assets/audio/3.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    ),
    const Song(
      id: 'song_4',
      title: 'Delta Melody',
      artist: 'Retro Wave',
      album: 'Synth City',
      duration: Duration(seconds: 180),
      uri: 'assets/audio/4.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    ),
  ];

  final Playlist testPlaylist = Playlist(
    id: 'scenario_playlist_1',
    name: 'Scenario Playlist',
    songIds: testSongs.map((s) => s.id).toList(),
    createdAt: DateTime.now(),
  );

  Widget createWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: RetroTheme.lightTheme(),
        home: PlaylistDetailScreen(
          playlist: testPlaylist,
          isFavorites: false,
        ),
      ),
    );
  }

  group('Playlist Search & Play Queue Scenarios', () {
    testWidgets('Scenario 1: Shuffle OFF -> Searching and playing a song queues all playlist songs in order', (tester) async {
      final storage = StorageService();
      await storage.savePlaylistPlaybackSettings(
        testPlaylist.id,
        isShuffle: false,
        loopMode: 'off',
      );

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(() => _MockLibraryNotifier(testSongs)),
          playlistProvider.overrideWith(() => _MockPlaylistNotifier(testPlaylist)),
          settingsRepositoryProvider.overrideWithValue(_MockSettingsRepo()),
          playerProvider.overrideWith(_ScenarioTestingPlayerNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createWidget(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEARCH TRACKS'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Gamma');
      await tester.pumpAndSettle();

      // Only 'Gamma Pulse' is displayed
      expect(find.text('Gamma Pulse'), findsOneWidget);
      expect(find.text('Alpha Beat'), findsNothing);
      expect(find.text('Beta Groove'), findsNothing);

      // Tap on 'Gamma Pulse'
      await tester.tap(find.text('Gamma Pulse'));
      await tester.pumpAndSettle();

      final playerState = container.read(playerProvider);

      // ALL 4 songs from the playlist are in the queue!
      expect(playerState.queue.length, 4);
      expect(playerState.queue.map((s) => s.title).toList(), [
        'Alpha Beat',
        'Beta Groove',
        'Gamma Pulse',
        'Delta Melody',
      ]);

      // Currently playing song is Gamma Pulse at index 2
      expect(playerState.currentSong?.title, 'Gamma Pulse');
      expect(playerState.currentIndex, 2);
      expect(playerState.isShuffle, isFalse);
      expect(playerState.loopMode, RetroLoopMode.off);
    });

    testWidgets('Scenario 2: Shuffle ON -> Searching and playing a song queues all playlist songs with searched song first', (tester) async {
      final storage = StorageService();
      await storage.savePlaylistPlaybackSettings(
        testPlaylist.id,
        isShuffle: true,
        loopMode: 'off',
      );

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(() => _MockLibraryNotifier(testSongs)),
          playlistProvider.overrideWith(() => _MockPlaylistNotifier(testPlaylist)),
          settingsRepositoryProvider.overrideWithValue(_MockSettingsRepo()),
          playerProvider.overrideWith(_ScenarioTestingPlayerNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createWidget(container));
      await tester.pumpAndSettle();

      // Open search and search for 'Beta'
      await tester.tap(find.text('SEARCH TRACKS'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Beta');
      await tester.pumpAndSettle();

      expect(find.text('Beta Groove'), findsOneWidget);

      // Tap on 'Beta Groove'
      await tester.tap(find.text('Beta Groove'));
      await tester.pumpAndSettle();

      final playerState = container.read(playerProvider);

      // ALL 4 songs from the playlist are in the queue
      expect(playerState.queue.length, 4);
      // Searched song is playing first at index 0
      expect(playerState.currentSong?.title, 'Beta Groove');
      expect(playerState.currentIndex, 0);
      expect(playerState.queue.first.title, 'Beta Groove');

      // The remaining 3 songs are all present in the queue
      final remainingTitles = playerState.queue.skip(1).map((s) => s.title).toSet();
      expect(remainingTitles, {'Alpha Beat', 'Gamma Pulse', 'Delta Melody'});

      expect(playerState.isShuffle, isTrue);
      expect(playerState.loopMode, RetroLoopMode.off);
    });

    testWidgets('Scenario 3: Loop ON (all) -> Searching and playing a song retains all songs and sets Loop Mode ALL', (tester) async {
      final storage = StorageService();
      await storage.savePlaylistPlaybackSettings(
        testPlaylist.id,
        isShuffle: false,
        loopMode: 'all',
      );

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(() => _MockLibraryNotifier(testSongs)),
          playlistProvider.overrideWith(() => _MockPlaylistNotifier(testPlaylist)),
          settingsRepositoryProvider.overrideWithValue(_MockSettingsRepo()),
          playerProvider.overrideWith(_ScenarioTestingPlayerNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createWidget(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEARCH TRACKS'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Delta');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delta Melody'));
      await tester.pumpAndSettle();

      final playerState = container.read(playerProvider);

      expect(playerState.queue.length, 4);
      expect(playerState.currentSong?.title, 'Delta Melody');
      expect(playerState.currentIndex, 3);
      expect(playerState.loopMode, RetroLoopMode.all);
      expect(playerState.isShuffle, isFalse);
    });

    testWidgets('Scenario 4: Loop Mode OFF -> Searching and playing a song retains all songs and Loop Mode is OFF', (tester) async {
      final storage = StorageService();
      await storage.savePlaylistPlaybackSettings(
        testPlaylist.id,
        isShuffle: false,
        loopMode: 'off',
      );

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(() => _MockLibraryNotifier(testSongs)),
          playlistProvider.overrideWith(() => _MockPlaylistNotifier(testPlaylist)),
          settingsRepositoryProvider.overrideWithValue(_MockSettingsRepo()),
          playerProvider.overrideWith(_ScenarioTestingPlayerNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createWidget(container));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SEARCH TRACKS'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Alpha Beat'));
      await tester.pumpAndSettle();

      final playerState = container.read(playerProvider);

      expect(playerState.queue.length, 4);
      expect(playerState.currentSong?.title, 'Alpha Beat');
      expect(playerState.currentIndex, 0);
      expect(playerState.loopMode, RetroLoopMode.off);
      expect(playerState.isShuffle, isFalse);
    });
  });
}
