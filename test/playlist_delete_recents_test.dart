import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/data/repositories/playlist_repository.dart';
import 'package:my_music/data/repositories/settings_repository.dart';
import 'package:my_music/data/services/storage_service.dart';
import 'package:my_music/domain/models/album.dart';
import 'package:my_music/domain/models/artist.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/playlist.dart';
import 'package:my_music/domain/models/recently_played_item.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/equalizer_provider.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/providers/recently_played_provider.dart';
import 'package:my_music/presentation/providers/theme_provider.dart';
import 'package:my_music/presentation/screens/library/library_screen.dart';
import 'package:my_music/presentation/screens/library/widgets/recently_played_grid.dart';

class TestSettingsRepository extends SettingsRepository {
  List<Map<String, dynamic>> _recents = [];

  @override
  List<Map<String, dynamic>> getRecentlyPlayed() => _recents;

  @override
  Future<void> saveRecentlyPlayed(List<Map<String, dynamic>> items) async {
    _recents = items;
  }
}

class TestPlaylistRepository extends PlaylistRepository {
  final List<Playlist> _repoPlaylists;
  TestPlaylistRepository(this._repoPlaylists) : super(storageService: StorageService());

  @override
  List<Playlist> get playlists => _repoPlaylists;

  @override
  Future<List<Playlist>> loadPlaylists() async => _repoPlaylists;

  @override
  Future<void> deletePlaylist(String playlistId) async {
    _repoPlaylists.removeWhere((p) => p.id == playlistId);
  }
}

class MockRecentlyPlayedNotifier extends RecentlyPlayedNotifier {
  final List<RecentlyPlayedItem> initialItems;
  MockRecentlyPlayedNotifier(this.initialItems);

  @override
  List<RecentlyPlayedItem> build() => initialItems;
}

class MockTestLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() {
    final song = Song(
      id: 's1',
      title: 'Chiptune',
      artist: 'Pixel Artist',
      album: 'Cyber Album',
      duration: const Duration(seconds: 30),
      uri: 'assets/audio/test.wav',
      quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
      isFavorite: false,
    );
    return LibraryState(
      allSongs: [song],
      albums: [Album(title: 'Cyber Album', artist: 'Pixel Artist', songs: [song])],
      artists: [Artist(name: 'Pixel Artist', songs: [song])],
      folders: {},
      isLoading: false,
    );
  }
}

class MockTestPlayerNotifier extends PlayerNotifier {
  @override
  PlayerStateModel build() => const PlayerStateModel();
}

class MockTestThemeNotifier extends ThemeNotifier {
  @override
  bool build() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Deleted Playlist in Recently Played Tests', () {
    test('RecentlyPlayedNotifier.removePlaylist removes playlist by id or name', () async {
      final settingsRepo = TestSettingsRepository();
      final container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(recentlyPlayedProvider.notifier);

      // Record an album and two playlists
      notifier.recordAlbum(title: 'Cyber Album', artist: 'Pixel Artist');
      notifier.recordPlaylist(id: 'pl_1', name: 'Synthwave Hits', songCount: 5);
      notifier.recordPlaylist(id: 'pl_2', name: 'Chiptunes 8-bit', songCount: 3);

      expect(container.read(recentlyPlayedProvider).length, 3);

      // Delete pl_1
      notifier.removePlaylist('pl_1', 'Synthwave Hits');

      final recentsAfter = container.read(recentlyPlayedProvider);
      expect(recentsAfter.length, 2);
      expect(recentsAfter.any((i) => i.id == 'pl_1'), isFalse);
      expect(recentsAfter.any((i) => i.title == 'Synthwave Hits'), isFalse);
      expect(recentsAfter.any((i) => i.id == 'pl_2'), isTrue);
      expect(recentsAfter.any((i) => i.title == 'Cyber Album'), isTrue);
    });

    test('PlaylistNotifier.deletePlaylist cleans up deleted playlist from recentlyPlayedProvider', () async {
      final settingsRepo = TestSettingsRepository();
      final testPlaylists = [
        Playlist(id: 'pl_delete', name: 'To Be Deleted', songIds: ['s1'], createdAt: DateTime.now()),
        Playlist(id: 'pl_keep', name: 'Keeper', songIds: ['s2'], createdAt: DateTime.now()),
      ];
      final playlistRepo = TestPlaylistRepository(testPlaylists);

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(MockTestLibraryNotifier.new),
          settingsRepositoryProvider.overrideWithValue(settingsRepo),
          playlistRepositoryProvider.overrideWithValue(playlistRepo),
        ],
      );
      addTearDown(container.dispose);

      final recentNotifier = container.read(recentlyPlayedProvider.notifier);
      recentNotifier.recordPlaylist(id: 'pl_delete', name: 'To Be Deleted', songCount: 1);
      recentNotifier.recordPlaylist(id: 'pl_keep', name: 'Keeper', songCount: 1);

      expect(container.read(recentlyPlayedProvider).length, 2);

      // Delete the playlist via PlaylistNotifier
      await container.read(playlistProvider.notifier).deletePlaylist('pl_delete');

      // Check playlistState
      expect(container.read(playlistProvider).playlists.any((p) => p.id == 'pl_delete'), isFalse);

      // Check recentlyPlayedProvider
      final recents = container.read(recentlyPlayedProvider);
      expect(recents.length, 1);
      expect(recents.first.id, 'pl_keep');
    });

    testWidgets('RecentlyPlayedGrid hides deleted playlist and renders SizedBox.shrink if all recents are deleted playlists', (tester) async {
      final playlistToKeep = Playlist(id: 'pl_live', name: 'Live Playlist', songIds: [], createdAt: DateTime.now());
      final recentItems = [
        RecentlyPlayedItem(
          id: 'pl_deleted_1',
          type: RecentItemType.playlist,
          title: 'Deleted Playlist',
          subtitle: 'PLAYLIST',
          playedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockTestLibraryNotifier.new),
            playlistRepositoryProvider.overrideWithValue(TestPlaylistRepository([playlistToKeep])),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: RecentlyPlayedGrid(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Since pl_deleted_1 does not exist in playlistProvider, it should be filtered out.
      // And because validRecentItems is empty, RecentlyPlayedGrid returns SizedBox.shrink().
      expect(find.text('RECENTLY PLAYED'), findsNothing);
      expect(find.text('Deleted Playlist'), findsNothing);
    });

    testWidgets('RecentlyPlayedGrid renders surviving items when a deleted playlist was in recents', (tester) async {
      final playlistToKeep = Playlist(id: 'pl_live', name: 'Live Playlist', songIds: [], createdAt: DateTime.now());
      final recentItems = [
        RecentlyPlayedItem(
          id: 'pl_deleted_1',
          type: RecentItemType.playlist,
          title: 'Deleted Playlist',
          subtitle: 'PLAYLIST',
          playedAt: DateTime.now(),
        ),
        RecentlyPlayedItem(
          id: 'album_retro',
          type: RecentItemType.album,
          title: 'Retro Galaxy',
          subtitle: 'Space Man',
          playedAt: DateTime.now(),
        ),
        RecentlyPlayedItem(
          id: 'pl_live',
          type: RecentItemType.playlist,
          title: 'Live Playlist',
          subtitle: 'PLAYLIST',
          playedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockTestLibraryNotifier.new),
            playlistRepositoryProvider.overrideWithValue(TestPlaylistRepository([playlistToKeep])),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: RecentlyPlayedGrid(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Header is shown
      expect(find.text('RECENTLY PLAYED'), findsOneWidget);
      // Deleted playlist is NOT shown
      expect(find.text('Deleted Playlist'), findsNothing);
      // Surviving items are shown
      expect(find.text('Retro Galaxy'), findsOneWidget);
      expect(find.text('Live Playlist'), findsOneWidget);
    });

    testWidgets('LibraryScreen does not render RecentlyPlayedGrid sliver when only deleted playlist was in recents', (tester) async {
      final recentItems = [
        RecentlyPlayedItem(
          id: 'pl_deleted_old',
          type: RecentItemType.playlist,
          title: 'Old Deleted Playlist',
          subtitle: 'PLAYLIST',
          playedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockTestLibraryNotifier.new),
            playlistRepositoryProvider.overrideWithValue(TestPlaylistRepository([])),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
            settingsRepositoryProvider.overrideWithValue(TestSettingsRepository()),
            playerProvider.overrideWith(MockTestPlayerNotifier.new),
            themeProvider.overrideWith(MockTestThemeNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const LibraryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // RecentlyPlayedGrid should NOT be present in the tree
      expect(find.byType(RecentlyPlayedGrid), findsNothing);
      expect(find.text('RECENTLY PLAYED'), findsNothing);
      expect(find.text('Old Deleted Playlist'), findsNothing);
    });
  });
}
