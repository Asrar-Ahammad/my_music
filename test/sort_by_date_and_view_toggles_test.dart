import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/playlist.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/screens/library/library_screen.dart';
import 'package:my_music/presentation/screens/playlists/playlists_screen.dart';
import 'package:my_music/presentation/screens/playlists/playlist_detail_screen.dart';
import 'package:my_music/presentation/widgets/retro_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final date1 = DateTime(2023, 1, 1);
  final date2 = DateTime(2023, 6, 1);
  final date3 = DateTime(2023, 12, 1);

  final testSongs = [
    Song(
      id: 'song_old',
      title: 'A Old Song',
      artist: 'Artist A',
      album: 'Album A',
      duration: const Duration(seconds: 100),
      uri: 'file:///old.mp3',
      quality: const AudioQuality(format: 'MP3'),
      dateAdded: date1,
    ),
    Song(
      id: 'song_mid',
      title: 'B Mid Song',
      artist: 'Artist B',
      album: 'Album B',
      duration: const Duration(seconds: 200),
      uri: 'file:///mid.mp3',
      quality: const AudioQuality(format: 'MP3'),
      dateAdded: date2,
    ),
    Song(
      id: 'song_new',
      title: 'C New Song',
      artist: 'Artist C',
      album: 'Album C',
      duration: const Duration(seconds: 300),
      uri: 'file:///new.mp3',
      quality: const AudioQuality(format: 'MP3'),
      dateAdded: date3,
    ),
  ];

  final testPlaylist = Playlist(
    id: 'p1',
    name: 'Date Test Playlist',
    songIds: ['song_old', 'song_mid', 'song_new'],
    createdAt: DateTime.now(),
  );

  group('Library sort by date', () {
    test('LibraryState sorts by date correctly', () {
      final stateAsc = LibraryState(
        allSongs: testSongs,
        sortMode: SongSortMode.date,
        sortAscending: true,
      );
      final sortedAsc = stateAsc.filteredSongs;
      expect(sortedAsc[0].id, 'song_old');
      expect(sortedAsc[1].id, 'song_mid');
      expect(sortedAsc[2].id, 'song_new');

      final stateDesc = LibraryState(
        allSongs: testSongs,
        sortMode: SongSortMode.date,
        sortAscending: false,
      );
      final sortedDesc = stateDesc.filteredSongs;
      expect(sortedDesc[0].id, 'song_new');
      expect(sortedDesc[1].id, 'song_mid');
      expect(sortedDesc[2].id, 'song_old');
    });
  });

  group('View toggles only have icons', () {
    testWidgets('PlaylistsScreen list and grid toggles do not have LIST or GRID text labels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistProvider.overrideWith(() => _MockPlaylistNotifier([testPlaylist])),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(body: PlaylistsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // None of the view toggle buttons should have label 'LIST' or 'GRID'
      expect(find.text('LIST'), findsNothing);
      expect(find.text('GRID'), findsNothing);

      // Verify list and grid RetroIcons are present
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'list'), findsWidgets);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'grid'), findsWidgets);
    });

    testWidgets('LibraryScreen view toggle does not have LIST or GRID text labels', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(
              () => _MockLibraryNotifier(LibraryState(allSongs: testSongs, isLoading: false)),
            ),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(body: LibraryScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to ALBUMS tab (index 1)
      await tester.tap(find.text('ALBUMS'));
      await tester.pumpAndSettle();

      // Ensure no 'LIST' or 'GRID' text buttons exist in the toolbar
      expect(find.text('LIST'), findsNothing);
      expect(find.text('GRID'), findsNothing);
    });
  });

  group('Playlist Detail and Add Songs Sheet sort by date', () {
    testWidgets('PlaylistDetailScreen shows SORT BY DATE in sort popup menu', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(
              () => _MockLibraryNotifier(LibraryState(allSongs: testSongs, isLoading: false)),
            ),
            playlistProvider.overrideWith(() => _MockPlaylistNotifier([testPlaylist])),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: Scaffold(
              body: PlaylistDetailScreen(playlist: testPlaylist),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open sort popup menu in playlist detail
      final sortButton = find.byTooltip('Sort playlist tracks');
      expect(sortButton, findsOneWidget);
      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      expect(find.text('SORT BY DATE'), findsOneWidget);
    });

    testWidgets('Add Songs Sheet shows SORT BY DATE in sort popup menu', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(
              () => _MockLibraryNotifier(LibraryState(allSongs: testSongs, isLoading: false)),
            ),
            playlistProvider.overrideWith(() => _MockPlaylistNotifier([testPlaylist])),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: Scaffold(
              body: PlaylistDetailScreen(playlist: testPlaylist),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap ADD MORE SONGS
      final addMoreBtn = find.text('ADD MORE SONGS');
      expect(addMoreBtn, findsOneWidget);
      await tester.tap(addMoreBtn);
      await tester.pumpAndSettle();

      // Open sort menu in Add Songs sheet
      final sortButton = find.byTooltip('Sort tracks');
      expect(sortButton, findsOneWidget);
      await tester.tap(sortButton);
      await tester.pumpAndSettle();

      expect(find.text('SORT BY DATE'), findsOneWidget);
    });
  });
}

class _MockLibraryNotifier extends LibraryNotifier {
  final LibraryState _customState;
  _MockLibraryNotifier(this._customState);

  @override
  LibraryState build() => _customState;
}

class _MockPlaylistNotifier extends PlaylistNotifier {
  final List<Playlist> _initialPlaylists;
  _MockPlaylistNotifier(this._initialPlaylists);

  @override
  PlaylistState build() {
    return PlaylistState(
      playlists: _initialPlaylists,
      isLoading: false,
    );
  }
}
