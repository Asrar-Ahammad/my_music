import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_colors.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/core/theme/retro_typography.dart';
import 'package:my_music/domain/models/album.dart';
import 'package:my_music/domain/models/artist.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/playlist.dart';
import 'package:my_music/domain/models/recently_played_item.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/recently_played_provider.dart';
import 'package:my_music/presentation/screens/library/widgets/recently_played_grid.dart';
import 'package:my_music/data/repositories/settings_repository.dart';
import 'package:my_music/data/services/audio_player_handler.dart';
import 'package:my_music/data/services/storage_service.dart';
import 'package:my_music/core/utils/lrc_parser.dart';
import 'package:my_music/presentation/providers/equalizer_provider.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/lyrics_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/providers/navigation_provider.dart';
import 'package:my_music/presentation/providers/theme_provider.dart';
import 'package:my_music/presentation/screens/home_scaffold.dart';
import 'package:my_music/presentation/screens/library/library_screen.dart';
import 'package:my_music/presentation/screens/library/album_detail_screen.dart';
import 'package:my_music/presentation/screens/library/artist_detail_screen.dart';
import 'package:my_music/presentation/screens/library/folder_detail_screen.dart';
import 'package:my_music/presentation/screens/library/tabs/all_songs_tab.dart';
import 'package:my_music/presentation/screens/library/tabs/albums_tab.dart';
import 'package:my_music/presentation/screens/library/tabs/artists_tab.dart';
import 'package:my_music/presentation/screens/library/tabs/folders_tab.dart';
import 'package:my_music/presentation/screens/equalizer/equalizer_screen.dart';
import 'package:my_music/presentation/screens/now_playing/now_playing_screen.dart';
import 'package:my_music/presentation/screens/now_playing/queue_sheet.dart';
import 'package:my_music/presentation/screens/playlists/playlist_detail_screen.dart';
import 'package:my_music/presentation/screens/playlists/playlists_screen.dart';
import 'package:my_music/presentation/screens/search/search_screen.dart';
import 'package:my_music/presentation/screens/settings/settings_screen.dart';
import 'package:my_music/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:my_music/presentation/providers/mini_player_settings_provider.dart';
import 'package:my_music/presentation/providers/now_playing_settings_provider.dart';
import 'package:my_music/presentation/widgets/create_playlist_modal.dart';
import 'package:my_music/presentation/widgets/mini_player.dart';
import 'package:my_music/presentation/widgets/retro_album_art.dart';
import 'package:my_music/presentation/widgets/retro_marquee_text.dart';
import 'package:my_music/presentation/widgets/retro_mini_player_art.dart';
import 'package:my_music/presentation/widgets/retro_now_playing_art.dart';
import 'package:my_music/presentation/widgets/retro_badge.dart';
import 'package:my_music/presentation/widgets/retro_button.dart';
import 'package:my_music/presentation/widgets/retro_song_tile.dart';
import 'package:my_music/presentation/widgets/retro_card.dart';
import 'package:my_music/presentation/widgets/retro_icon.dart';
import 'package:my_music/presentation/widgets/retro_loading_state.dart';
import 'package:my_music/presentation/widgets/retro_scroll_thumb.dart';
import 'package:my_music/presentation/widgets/retro_volume_slider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_music/presentation/widgets/retro_refresh_indicator.dart';
import 'package:my_music/presentation/widgets/retro_slider.dart';
import 'package:my_music/presentation/widgets/shuffle_options_sheet.dart';
import 'package:my_music/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  group('Retro Widgets UI Verification', () {
    testWidgets('RetroButton renders label and responds to taps', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: Scaffold(
            body: RetroButton(
              label: 'PRESS START',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('PRESS START'), findsOneWidget);
      await tester.tap(find.text('PRESS START'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('RetroBadge renders text with solid border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: RetroBadge(text: '24-BIT FLAC'),
          ),
        ),
      );

      expect(find.text('24-BIT FLAC'), findsOneWidget);
    });

    testWidgets('RetroCard renders child and title header', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: RetroCard(
              title: 'AUDIO SPECS',
              child: Text('Content inside card'),
            ),
          ),
        ),
      );

      expect(find.text('AUDIO SPECS'), findsOneWidget);
      expect(find.text('Content inside card'), findsOneWidget);
    });

    testWidgets('RetroSlider renders timestamps and reacts to seek', (tester) async {
      Duration? seekTarget;

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: Scaffold(
            body: RetroSlider(
              position: const Duration(seconds: 30),
              duration: const Duration(seconds: 120),
              onSeek: (pos) => seekTarget = pos,
            ),
          ),
        ),
      );

      expect(find.text('00:30'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);

      await tester.tap(find.byType(RetroSlider));
      await tester.pump();
      expect(seekTarget, isNotNull);
    });


    testWidgets('CreatePlaylistModal renders suggestions and updates text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => const CreatePlaylistModal(
                      isInitialEmptyPrompt: true,
                    ),
                  );
                },
                child: const Text('OPEN MODAL'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN MODAL'));
      await tester.pumpAndSettle();

      expect(find.text('CREATE FIRST PLAYLIST'), findsOneWidget);
      expect(find.text('CHIPTUNES'), findsOneWidget);
      expect(find.text('8-BIT HITS'), findsOneWidget);

      // Tap on suggestion 'CHIPTUNES'
      await tester.tap(find.text('CHIPTUNES'));
      await tester.pumpAndSettle();

      // Check text field has 'CHIPTUNES'
      expect(find.text('CHIPTUNES'), findsWidgets);
    });

    testWidgets('RetroAlbumArt renders placeholder when artPath is null and handles borders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: RetroAlbumArt(
              artPath: null,
              width: 100,
              height: 100,
              borderWidth: 2.0,
            ),
          ),
        ),
      );

      expect(find.byType(RetroAlbumArt), findsOneWidget);
    });

    testWidgets('RetroAlbumArt handles double.infinity width/height with SVG and assets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: SizedBox(
              width: 120,
              height: 120,
              child: RetroAlbumArt(
                artPath: 'assets/album_art/retro_quest.svg',
                width: double.infinity,
                height: double.infinity,
                borderWidth: 2.0,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(RetroAlbumArt), findsOneWidget);
    });

    testWidgets('RetroAlbumArt renders procedural retro vinyl placeholder when artPath is null with title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: RetroAlbumArt(
              artPath: null,
              title: 'Neon Odyssey',
              artist: 'Chiptune Samurai',
              width: 140,
              height: 140,
              borderWidth: 2.0,
            ),
          ),
        ),
      );

      expect(find.byType(RetroAlbumArt), findsOneWidget);
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('AlbumsTab renders album cards with cover art and track info', (tester) async {
      const song1 = Song(
        id: 's1',
        title: 'Chiptune Quest',
        artist: 'Pixel Hero',
        album: 'Overworld Odyssey',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/chiptune_quest.wav',
        artPath: 'assets/album_art/retro_quest.svg',
        quality: AudioQuality(format: 'WAV'),
      );
      const song2 = Song(
        id: 's2',
        title: 'Arcade Rush',
        artist: 'Synth Samurai',
        album: 'Neon Stage',
        duration: Duration(seconds: 140),
        uri: 'assets/audio/arcade_rush.wav',
        artPath: null,
        quality: AudioQuality(format: 'WAV'),
      );

      final album1 = Album(
        title: 'Overworld Odyssey',
        artist: 'Pixel Hero',
        songs: const [song1],
        artPath: 'assets/album_art/retro_quest.svg',
      );
      final album2 = Album(
        title: 'Neon Stage',
        artist: 'Synth Samurai',
        songs: const [song2],
        artPath: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
                  LibraryState(
                    allSongs: [song1, song2],
                    albums: [album1, album2],
                    isLoading: false,
                  ),
                )),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: AlbumsTab(),
            ),
          ),
        ),
      );

      expect(find.text('Overworld Odyssey'), findsOneWidget);
      expect(find.text('Neon Stage'), findsOneWidget);
      expect(find.text('1 TRACKS'), findsNWidgets(2));
      expect(find.byType(RetroAlbumArt), findsNWidgets(2));
      // Second album has no artPath so it renders procedural vinyl with initial 'N'
      expect(find.text('N'), findsOneWidget);
    });

    testWidgets('ArtistDetailScreen renders PLAY ALL and SHUFFLE PLAY buttons and displays songs', (tester) async {
      const song1 = Song(
        id: 's1',
        title: 'Chiptune Quest',
        artist: 'Pixel Hero',
        album: 'Overworld Odyssey',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/chiptune_quest.wav',
        artPath: 'assets/album_art/retro_quest.svg',
        quality: AudioQuality(format: 'WAV'),
      );
      const song2 = Song(
        id: 's2',
        title: 'Castle Battle',
        artist: 'Pixel Hero',
        album: 'Overworld Odyssey',
        duration: Duration(seconds: 150),
        uri: 'assets/audio/arcade_rush.wav',
        quality: AudioQuality(format: 'WAV'),
      );

      const artist = Artist(
        name: 'Pixel Hero',
        songs: [song1, song2],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
                  const LibraryState(
                    allSongs: [song1, song2],
                    artists: [artist],
                    isLoading: false,
                  ),
                )),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const ArtistDetailScreen(artist: artist),
          ),
        ),
      );

      expect(find.text('PIXEL HERO'), findsOneWidget);
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);
      expect(find.text('Chiptune Quest'), findsOneWidget);
      expect(find.text('Castle Battle'), findsOneWidget);
    });

    testWidgets('ArtistsTab tapping on artist card navigates to ArtistDetailScreen', (tester) async {
      const song1 = Song(
        id: 's1',
        title: 'Chiptune Quest',
        artist: 'Pixel Hero',
        album: 'Overworld Odyssey',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/chiptune_quest.wav',
        artPath: 'assets/album_art/retro_quest.svg',
        quality: AudioQuality(format: 'WAV'),
      );

      const artist = Artist(
        name: 'Pixel Hero',
        songs: [song1],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
                  const LibraryState(
                    allSongs: [song1],
                    artists: [artist],
                    isLoading: false,
                  ),
                )),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: ArtistsTab(),
            ),
          ),
        ),
      );

      expect(find.text('Pixel Hero'), findsOneWidget);
      await tester.tap(find.text('Pixel Hero'));
      await tester.pumpAndSettle();

      // Should now be on ArtistDetailScreen
      expect(find.byType(ArtistDetailScreen), findsOneWidget);
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);
    });

    testWidgets('FolderDetailScreen renders PLAY ALL and SHUFFLE PLAY buttons and displays songs', (tester) async {
      const song1 = Song(
        id: 's1',
        title: 'Chiptune Quest',
        artist: 'Pixel Hero',
        album: 'Overworld Odyssey',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/chiptune_quest.wav',
        artPath: 'assets/album_art/retro_quest.svg',
        folderPath: 'assets/audio',
        quality: AudioQuality(format: 'WAV'),
      );
      const song2 = Song(
        id: 's2',
        title: 'Arcade Rush',
        artist: 'Synth Samurai',
        album: 'Neon Stage',
        duration: Duration(seconds: 140),
        uri: 'assets/audio/arcade_rush.wav',
        folderPath: 'assets/audio',
        quality: AudioQuality(format: 'WAV'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
                  const LibraryState(
                    allSongs: [song1, song2],
                    folders: {'assets/audio': [song1, song2]},
                    isLoading: false,
                  ),
                )),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const FolderDetailScreen(folderPath: 'assets/audio'),
          ),
        ),
      );

      expect(find.text('AUDIO'), findsOneWidget);
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);
      expect(find.text('Chiptune Quest'), findsOneWidget);
      expect(find.text('Arcade Rush'), findsOneWidget);
    });

    testWidgets('FoldersTab tapping on folder card navigates to FolderDetailScreen', (tester) async {
      const song1 = Song(
        id: 's1',
        title: 'Chiptune Quest',
        artist: 'Pixel Hero',
        album: 'Overworld Odyssey',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/chiptune_quest.wav',
        folderPath: 'assets/audio',
        quality: AudioQuality(format: 'WAV'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
                  const LibraryState(
                    allSongs: [song1],
                    folders: {'assets/audio': [song1]},
                    isLoading: false,
                  ),
                )),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: FoldersTab(),
            ),
          ),
        ),
      );

      expect(find.text('audio'), findsOneWidget);
      await tester.tap(find.text('audio'));
      await tester.pumpAndSettle();

      // Should now be on FolderDetailScreen
      expect(find.byType(FolderDetailScreen), findsOneWidget);
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);
    });

    testWidgets('PlaylistDetailScreen renders PLAY ALL and SHUFFLE PLAY buttons when tracks exist', (tester) async {
      final samplePlaylist = Playlist(
        id: 'favorites_system',
        name: 'Favorites',
        songIds: ['s1'],
        createdAt: DateTime.now(),
        isSystem: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: samplePlaylist,
              isFavorites: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);
      // Verify both album cover and track number 01 are rendered using RetroSongTile template
      expect(find.byType(RetroAlbumArt), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
    });

    testWidgets('PlaylistDetailScreen shows dropdown menu with Edit and Delete options', (tester) async {
      final userPlaylist = Playlist(
        id: 'p1',
        name: 'Retro Hits',
        songIds: ['s1'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: userPlaylist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify tracks count and created date are displayed next to each other
      expect(find.text('1 Tracks'), findsOneWidget);
      expect(
        find.text('Created ${userPlaylist.createdAt.month}/${userPlaylist.createdAt.day}/${userPlaylist.createdAt.year}'),
        findsOneWidget,
      );

      // Verify dropdown icon exists
      final popupFinder = find.byTooltip('Playlist Options');
      expect(popupFinder, findsOneWidget);

      // Open popup menu
      await tester.tap(popupFinder);
      await tester.pumpAndSettle();

      // Verify options
      expect(find.text('EDIT PLAYLIST'), findsOneWidget);
      expect(find.text('DELETE PLAYLIST'), findsOneWidget);
    });

    testWidgets('Tapping DELETE PLAYLIST opens confirmation dialog', (tester) async {
      final userPlaylist = Playlist(
        id: 'p1',
        name: 'Retro Hits',
        songIds: ['s1'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: userPlaylist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byTooltip('Playlist Options'));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text('DELETE PLAYLIST'));
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.text('DELETE PLAYLIST?'), findsOneWidget);
      expect(find.text('Are you sure you want to delete "Retro Hits"?'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('DELETE'), findsOneWidget);
    });

    testWidgets('Tapping EDIT PLAYLIST opens edit dialog with pre-filled name', (tester) async {
      final userPlaylist = Playlist(
        id: 'p1',
        name: 'Retro Hits',
        songIds: ['s1'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: userPlaylist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open popup menu
      await tester.tap(find.byTooltip('Playlist Options'));
      await tester.pumpAndSettle();

      // Tap Edit
      await tester.tap(find.text('EDIT PLAYLIST'));
      await tester.pumpAndSettle();

      // Edit dialog should be displayed
      expect(find.text('PLAYLIST NAME'), findsOneWidget);
      expect(find.text('SAVE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('Retro Hits'), findsWidgets);
    });

    testWidgets('PlaylistDetailScreen song three-dot menu shows options and handles actions', (tester) async {
      final userPlaylist = Playlist(
        id: 'p1',
        name: 'Retro Hits',
        songIds: ['s1'],
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(MockLibraryNotifier.new),
          playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: userPlaylist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Close icon must NOT exist
      expect(find.byIcon(Icons.close), findsNothing);
      expect(
        find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'close'),
        findsNothing,
      );

      // Song three-dot options menu must exist
      final songMenuFinder = find.byTooltip('Song Options');
      expect(songMenuFinder, findsOneWidget);

      // Verify PopupMenuButton uses theme retro.cardColor in Light Mode instead of hardcoded dark
      final songPopup = tester.widget<PopupMenuButton<String>>(
        find.descendant(of: find.byType(RetroSongTile), matching: find.byType(PopupMenuButton<String>)),
      );
      expect(songPopup.color, equals(RetroColors.lightCard));

      // Tap the three-dot menu
      await tester.tap(songMenuFinder);
      await tester.pumpAndSettle();

      // Verify all requested options and icons are present
      expect(find.text('PLAY NEXT'), findsOneWidget);
      expect(find.text('ADD TO QUEUE'), findsOneWidget);
      expect(find.text('GO TO ALBUM'), findsOneWidget);
      expect(find.text('GO TO ARTIST'), findsOneWidget);
      expect(find.text('REMOVE FROM PLAYLIST'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RetroIcon && (w.iconName == 'disc' || w.iconName == 'vinyl')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'user'),
        findsOneWidget,
      );

      // Tap GO TO ARTIST to verify navigation (navigates without creating a separate screen)
      await tester.tap(find.text('GO TO ARTIST'));
      await tester.pumpAndSettle();
      expect(container.read(homeTabProvider), equals(0));
      expect(find.byType(ArtistDetailScreen), findsNothing);

      // Tap the three-dot menu again
      await tester.tap(songMenuFinder);
      await tester.pumpAndSettle();

      // Tap GO TO ALBUM to verify navigation (navigates without creating a separate screen)
      await tester.tap(find.text('GO TO ALBUM'));
      await tester.pumpAndSettle();
      expect(container.read(homeTabProvider), equals(0));
      expect(find.byType(AlbumDetailScreen), findsNothing);
    });

    testWidgets('HomeScaffold preserves BottomNavigationBar and MiniPlayer inside playlist screen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // BottomNavigationBar and MiniPlayer are visible on home screen
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Tap the PLAYLISTS tab (second tab)
      await tester.tap(find.text('PLAYLISTS'));
      await tester.pumpAndSettle();

      // We should see user playlist "Retro Hits"
      expect(find.text('Retro Hits'), findsOneWidget);

      // Tap "Retro Hits" card to open playlist screen
      await tester.tap(find.text('Retro Hits'));
      await tester.pumpAndSettle();

      // Playlist songs screen is active: tracks and banner are shown
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);

      // CRITICAL ASSERTION: BottomNavigationBar and MiniPlayer MUST STILL BE VISIBLE!
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Verify bottom nav labels remain interactive
      expect(find.text('LIBRARY'), findsOneWidget);
      expect(find.text('PLAYLISTS'), findsOneWidget);
      expect(find.text('SEARCH'), findsOneWidget);
      expect(find.text('AI'), findsNothing);

      // Tap back button in playlist screen
      final backButtonFinder = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.icon is RetroIcon && (widget.icon as RetroIcon).iconName == 'arrow_left',
      );
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();

      // Returned to playlists list
      expect(find.text('MY PLAYLISTS (1)'), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('Tapping MiniPlayer opens full screen player drawer with collapse button and swipe down', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the MiniPlayer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();

      // Full screen music player drawer is now displayed
      expect(find.byType(NowPlayingScreen), findsOneWidget);
      expect(find.text('NOW PLAYING'), findsNothing);
      expect(find.text('Chiptune'), findsWidgets);

      // Verify top bar NOW PLAYING and down arrow / collapse button are removed
      expect(find.byKey(const ValueKey('now_playing_collapse_button')), findsNothing);
      final topArrowDown = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.icon is RetroIcon && (widget.icon as RetroIcon).iconName == 'arrow_down',
        ),
      );
      expect(topArrowDown, findsNothing);

      // Test swipe down to collapse from the album art
      await tester.fling(find.byType(RetroNowPlayingArt), const Offset(0, 500), 1000);
      await tester.pumpAndSettle();

      // NowPlayingScreen drawer should be collapsed/dismissed
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Tap MiniPlayer again to re-open drawer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Test swipe down on the Album Art in NowPlayingScreen to collapse
      final nowPlayingAlbumArt = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(RetroAlbumArt),
      );
      await tester.fling(nowPlayingAlbumArt, const Offset(0, 300), 800);
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Re-open drawer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Test swipe down on the scrollable body to collapse
      await tester.fling(
        find.byKey(const ValueKey('now_playing_body_scroll')),
        const Offset(0, 300),
        800,
      );
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Re-open drawer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Verify Volume Slider exists below music controls
      expect(find.byType(RetroVolumeSlider), findsOneWidget);

      // Verify Lyrics Ticker has fixed height of 52.0px so height does not jump between 1 and 2 lines
      expect(tester.getSize(find.byKey(const ValueKey('now_playing_lyrics_ticker'))).height, equals(52.0));

      // Verify Sleep Timer, EQ, and Queue utility buttons exist below music controls
      expect(find.text('TIMER'), findsOneWidget);
      expect(find.text('EQ'), findsOneWidget);
      expect(find.text('QUEUE'), findsOneWidget);

      // Scroll until EQ button is visible and tap it
      await tester.ensureVisible(find.text('EQ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('EQ'));
      await tester.pumpAndSettle();
      expect(find.byType(EqualizerScreen), findsOneWidget);

      // Pop back from EqualizerScreen
      await tester.tap(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'arrow_left'));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Tap QUEUE to verify opening QueueSheet
      await tester.ensureVisible(find.text('QUEUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('QUEUE'));
      await tester.pumpAndSettle();
      expect(find.byType(QueueSheet), findsOneWidget);
      expect(find.text('QUEUE IS EMPTY'), findsOneWidget);

      // Dismiss QueueSheet
      await tester.drag(find.text('PLAYBACK QUEUE'), const Offset(0, 300));
      await tester.pumpAndSettle();

      // Tap TIMER to verify opening Sleep Timer dialog
      await tester.ensureVisible(find.text('TIMER'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TIMER'));
      await tester.pumpAndSettle();
      expect(find.text('SLEEP TIMER'), findsOneWidget);

      // Close Sleep Timer dialog
      await tester.tap(find.text('CLOSE'));
      await tester.pumpAndSettle();

      // Swipe down on album art to collapse
      await tester.fling(find.byType(RetroNowPlayingArt), const Offset(0, 500), 1000);
      await tester.pumpAndSettle();

      // NowPlayingScreen drawer is collapsed again
      expect(find.byType(NowPlayingScreen), findsNothing);
    });

    testWidgets('NowPlayingScreen has no border on screen modal sheet and top header bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => NowPlayingScreen.showBottomSheet(context),
                    child: const Text('OPEN'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Verify the ModalBottomSheet Material does not have a border
      final sheetMaterial = tester.widget<Material>(
        find.ancestor(
          of: find.byType(NowPlayingScreen),
          matching: find.byType(Material),
        ).first,
      );
      if (sheetMaterial.shape is RoundedRectangleBorder) {
        final shape = sheetMaterial.shape as RoundedRectangleBorder;
        expect(shape.side.style, equals(BorderStyle.none));
      }

      // Verify collapse button is removed
      expect(find.byKey(const ValueKey('now_playing_collapse_button')), findsNothing);
    });

    testWidgets('RetroButton applies depression on press down and resets on release', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: Scaffold(
            body: Center(
              child: RetroButton(
                label: 'PRESS',
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      final gesture = await tester.startGesture(tester.getCenter(find.text('PRESS')));
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.byType(AnimatedContainer), findsOneWidget);
      AnimatedContainer container = tester.widget(find.byType(AnimatedContainer));
      expect(container.transform, isNotNull);

      await gesture.up();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      container = tester.widget(find.byType(AnimatedContainer));
      expect(container.transform, equals(Matrix4.identity()));
    });

    testWidgets('NowPlayingScreen uses RetroButton for music controls and favorite', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: NowPlayingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Controls row: shuffle, prev, play/pause, next, repeat, plus favorite and bottom buttons
      expect(find.byType(RetroButton), findsWidgets);
      expect(find.byType(RetroButton).evaluate().length, greaterThanOrEqualTo(6));

      // Favorite button starts filled because isFavorite is true in mock
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart_filled'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart'), findsNothing);

      // Tap favorite button to unfavorite
      final favButton = find.ancestor(
        of: find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart_filled'),
        matching: find.byType(RetroButton),
      );
      await tester.tap(favButton);
      await tester.pumpAndSettle();

      // Icon should have toggled to heart
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart_filled'), findsNothing);

      // Tap favorite button again to re-favorite
      final favButton2 = find.ancestor(
        of: find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart'),
        matching: find.byType(RetroButton),
      );
      await tester.tap(favButton2);
      await tester.pumpAndSettle();

      // Icon should have toggled back to heart_filled
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart_filled'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'heart'), findsNothing);
    });

    testWidgets('NowPlayingScreen displays UNSYNCED in lyrics ticker when lyrics are unsynced', (tester) async {
      final doc = LrcParser.parse('''[ti:Zulfe]
[ar:Saahel, Trosk]
Hm-mm, hm-mm
''');

      final mockLyricsState = LyricsState(
        lyrics: doc,
        activeLineIndex: -1,
        sourceName: 'LOCAL FILE',
        songId: 's1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
            lyricsProvider.overrideWith(() => MockCustomLyricsForWidgetTest(mockLyricsState)),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: NowPlayingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('now_playing_lyrics_ticker')), findsOneWidget);
      expect(find.text('UNSYNCED'), findsOneWidget);
    });

    testWidgets('NowPlayingScreen buttons maintain high color contrast in Jet Black theme', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(paletteId: 'jet_black'),
            home: const Scaffold(
              body: NowPlayingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Skip previous & skip next icons must have high contrast (white on dark card)
      final prevIcon = tester.widget<RetroIcon>(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'skip_prev'));
      expect(prevIcon.color, equals(const Color(0xFFFFFFFF)));

      final nextIcon = tester.widget<RetroIcon>(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'skip_next'));
      expect(nextIcon.color, equals(const Color(0xFFFFFFFF)));

      // Play/pause icon must be onPrimary (black on white button in Jet Black)
      final playPauseIcon = tester.widget<RetroIcon>(find.byWidgetPredicate((w) => w is RetroIcon && (w.iconName == 'play' || w.iconName == 'pause')));
      expect(playPauseIcon.color, equals(const Color(0xFF0F0E0E)));
    });

    testWidgets('NowPlayingScreen repeat button shows repeat_dot for repeat all and repeat_one for repeat one', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final mockPlayer = MockPlayerNotifierWithCustomSong();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(() => mockPlayer),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: NowPlayingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Finder findButtonIcon(String name) => find.descendant(
            of: find.byType(RetroButton),
            matching: find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == name),
          );

      // Initially loop mode is off -> repeat icon
      expect(findButtonIcon('repeat'), findsOneWidget);

      // Tap repeat button -> toggles to loop all -> repeat_dot icon
      final repeatButton = find.ancestor(
        of: findButtonIcon('repeat'),
        matching: find.byType(RetroButton),
      );
      await tester.tap(repeatButton);
      await tester.pumpAndSettle();

      expect(findButtonIcon('repeat_dot'), findsOneWidget);

      // Tap repeat button again -> toggles to loop one -> repeat_one icon
      final repeatDotButton = find.ancestor(
        of: findButtonIcon('repeat_dot'),
        matching: find.byType(RetroButton),
      );
      await tester.tap(repeatDotButton);
      await tester.pumpAndSettle();

      expect(findButtonIcon('repeat_one'), findsOneWidget);

      // Tap repeat button again -> toggles back to off -> repeat icon
      final repeatOneButton = find.ancestor(
        of: findButtonIcon('repeat_one'),
        matching: find.byType(RetroButton),
      );
      await tester.tap(repeatOneButton);
      await tester.pumpAndSettle();

      expect(findButtonIcon('repeat'), findsOneWidget);
    });

    testWidgets('NowPlayingScreen favorite button is fixed to the right end regardless of song title length', (tester) async {
      final mockPlayer = MockPlayerNotifierWithCustomSong();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(() => mockPlayer),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: NowPlayingScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final favFinder = find.ancestor(
        of: find.byWidgetPredicate((w) => w is RetroIcon && (w.iconName == 'heart' || w.iconName == 'heart_filled')),
        matching: find.byType(RetroButton),
      );
      expect(favFinder, findsOneWidget);
      final initialRight = tester.getRect(favFinder).right;
      final initialFavRect = tester.getRect(favFinder);

      // Verify container has minHeight 48 and favorite button is fully within bounds
      final stackFinder = find.ancestor(of: favFinder, matching: find.byType(Stack)).first;
      final stackRect = tester.getRect(stackFinder);
      expect(stackRect.height, greaterThanOrEqualTo(44.0));
      expect(initialFavRect.top, greaterThanOrEqualTo(stackRect.top));
      expect(initialFavRect.bottom, lessThanOrEqualTo(stackRect.bottom));

      // Update to very long song title
      mockPlayer.updateSong(const Song(
        id: 's2',
        title: 'Extremely Long Song Title That Extends Very Far Across The Screen',
        artist: 'Very Long Artist Name Here',
        album: 'Very Long Album Title Here',
        duration: Duration(seconds: 300),
        uri: 'test.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      ));
      await tester.pumpAndSettle();

      final updatedRight = tester.getRect(favFinder).right;

      // The right edge of the favorite button must remain fixed at the right end of the screen
      expect(updatedRight, equals(initialRight));
    });

    testWidgets('MiniPlayer has shuffle button that opens ShuffleOptionsSheet with shuffle play options', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: Column(
                children: [
                  Spacer(),
                  MiniPlayer(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MiniPlayer is displayed
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Shuffle icon button should exist inside MiniPlayer
      final shuffleBtn = find.descendant(
        of: find.byType(MiniPlayer),
        matching: find.byWidgetPredicate(
          (w) => w is RetroIcon && w.iconName == 'shuffle',
        ),
      );
      expect(shuffleBtn, findsOneWidget);

      // Tap the shuffle button toggles shuffle
      await tester.tap(shuffleBtn);
      await tester.pump();
      expect(find.text('SHUFFLE: ON'), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(MiniPlayer))).clearSnackBars();
      await tester.pumpAndSettle();

      // Long press the shuffle button opens ShuffleOptionsSheet
      await tester.longPress(shuffleBtn);
      await tester.pumpAndSettle();

      // ShuffleOptionsSheet should be opened
      expect(find.byType(ShuffleOptionsSheet), findsOneWidget);
      expect(find.text('SHUFFLE PLAY OPTIONS'), findsOneWidget);
      expect(find.text('SHUFFLE PLAYBACK MODE'), findsOneWidget);
      expect(find.text('QUICK SHUFFLE ACTIONS'), findsOneWidget);
      expect(find.text('SHUFFLE ALL SONGS (1)'), findsOneWidget);

      // Close the sheet
      await tester.tap(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'close'));
      await tester.pumpAndSettle();
      expect(find.byType(ShuffleOptionsSheet), findsNothing);
    });

    testWidgets('PlaylistsScreen switches between List and Grid views and persists preference', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: PlaylistsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial state is List view
      final listIconFinder = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'list');
      final gridIconFinder = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'grid');
      expect(listIconFinder, findsOneWidget);
      expect(gridIconFinder, findsOneWidget);
      expect(find.byType(SliverGrid), findsNothing);

      // Tap GRID button icon
      await tester.tap(gridIconFinder);
      await tester.pumpAndSettle();

      // Should now render SliverGrid
      expect(find.byType(SliverGrid), findsOneWidget);
      // Verify setting was saved to repository
      expect(mockSettings.isPlaylistGridView(), isTrue);

      // Tap LIST button icon
      await tester.tap(listIconFinder);
      await tester.pumpAndSettle();

      // Should switch back to list view
      expect(find.byType(SliverGrid), findsNothing);
      expect(mockSettings.isPlaylistGridView(), isFalse);
    });

    testWidgets('PlaylistsScreen renders FAB on bottom right to create new playlist and does not render top action button', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: PlaylistsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top action button 'NEW' is gone
      expect(find.widgetWithText(AppBar, 'NEW'), findsNothing);

      // FAB is present with icon and no text
      expect(find.text('NEW PLAYLIST'), findsNothing);
      final fabFinder = find.byKey(const ValueKey('playlists_new_playlist_fab'));
      expect(fabFinder, findsOneWidget);

      // Tap FAB to verify create modal opens
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Create playlist dialog appears
      expect(find.text('+ CREATE'), findsOneWidget);
      expect(find.text('QUICK SUGGESTIONS'), findsOneWidget);
    });

    testWidgets('FoldersTab and AllSongsTab support drag down to rescan', (tester) async {
      final mockLib = MockLibraryNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => mockLib),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: FoldersTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetroRefreshIndicator), findsOneWidget);

      // Trigger refresh on RetroRefreshIndicator
      await tester.state<RetroRefreshIndicatorState>(find.byType(RetroRefreshIndicator)).show();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(mockLib.loadLibraryCallCount, equals(1));
      expect(find.textContaining('LIBRARY UP TO DATE'), findsOneWidget);
    });

    testWidgets('repeat, repeat_dot, repeat_one, refresh, history, and clock RetroIcons render cleanly with 8-bit graphics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                RetroIcon('repeat', size: 24),
                RetroIcon('repeat_dot', size: 24),
                RetroIcon('repeat_one', size: 24),
                RetroIcon('refresh', size: 24),
                RetroIcon('history', size: 24),
                RetroIcon('clock', size: 24),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetroIcon), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets('music, folder, playlist, and settings RetroIcons render cleanly with 8-bit graphics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                RetroIcon('music', size: 24),
                RetroIcon('folder', size: 24),
                RetroIcon('playlist', size: 24),
                RetroIcon('settings', size: 24),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetroIcon), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('skip_next and skip_prev RetroIcons render properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                RetroIcon('skip_prev', size: 24),
                RetroIcon('skip_next', size: 24),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RetroIcon), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('SearchScreen automatically focuses on input field when active', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const SearchScreen(isActive: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final TextField textField = tester.widget(textFieldFinder);
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('RetroRefreshIndicator shows arcade card and RESCANNING... on show()', (tester) async {
      final completer = Completer<void>();
      final key = GlobalKey<RetroRefreshIndicatorState>();

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: Scaffold(
            body: RetroRefreshIndicator(
              key: key,
              onRefresh: () => completer.future,
              child: ListView(
                children: const [Text('Item 1'), Text('Item 2')],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger refresh
      key.currentState!.show();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('RESCANNING...'), findsOneWidget);

      completer.complete();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('RESCANNING...'), findsNothing);
    });

    testWidgets('SettingsScreen allows selecting MiniPlayer cover art style (BOX vs VINYL) and conditional rotation', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to ensure MINIPLAYER COVER ART card is visible
      await tester.scrollUntilVisible(find.text('MINIPLAYER COVER ART'), 200);

      // Verify card header exists
      expect(find.text('MINIPLAYER COVER ART'), findsOneWidget);
      expect(find.text('BOX'), findsWidgets);
      expect(find.text('VINYL'), findsWidgets);

      // By default (box mode), rotation option is hidden
      expect(find.text('ROTATE VINYL ON PLAYBACK'), findsNothing);

      // Tap VINYL to switch style
      await tester.ensureVisible(find.text('VINYL').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('VINYL').first);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // Now rotation option must be visible
      expect(find.text('ROTATE VINYL ON PLAYBACK'), findsOneWidget);
      final enabledFinder = find.descendant(
        of: find.widgetWithText(RetroCard, 'MINIPLAYER COVER ART'),
        matching: find.text('ENABLED'),
      );
      expect(enabledFinder, findsOneWidget);

      // Tap ENABLED to toggle to DISABLED
      await tester.ensureVisible(enabledFinder);
      await tester.pumpAndSettle();
      await tester.tap(enabledFinder);
      await tester.pumpAndSettle();
      expect(find.text('DISABLED'), findsOneWidget);

      // Tap BOX to switch back
      final boxFinder = find.descendant(
        of: find.widgetWithText(RetroCard, 'MINIPLAYER COVER ART'),
        matching: find.text('BOX'),
      );
      await tester.ensureVisible(boxFinder);
      await tester.pumpAndSettle();
      await tester.tap(boxFinder);
      await tester.pumpAndSettle();

      // Rotation option should be hidden again
      expect(find.text('ROTATE VINYL ON PLAYBACK'), findsNothing);
    });

    testWidgets('MiniPlayer switches between box and vinyl cover art and handles rotation', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: MiniPlayer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default (BOX), RetroMiniPlayerArt renders standard RetroAlbumArt
      expect(find.byType(RetroMiniPlayerArt), findsOneWidget);
      expect(
        find.descendant(of: find.byType(RetroMiniPlayerArt), matching: find.byType(RetroAlbumArt)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(RetroMiniPlayerArt), matching: find.byType(RotationTransition)),
        findsNothing,
      );

      // Switch to VINYL style with rotation enabled
      final element = tester.element(find.byType(MiniPlayer));
      final container = ProviderScope.containerOf(element);
      container.read(miniPlayerArtSettingsProvider.notifier).setStyle(MiniPlayerArtStyle.vinyl);
      container.read(miniPlayerArtSettingsProvider.notifier).setRotating(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now RotationTransition should be present inside RetroMiniPlayerArt around the vinyl disc
      expect(
        find.descendant(of: find.byType(RetroMiniPlayerArt), matching: find.byType(RotationTransition)),
        findsOneWidget,
      );

      // Verify that 8-bit pixel clipping is used instead of a smooth/clear circle ClipOval
      expect(
        find.descendant(of: find.byType(RetroMiniPlayerArt), matching: find.byType(ClipOval)),
        findsNothing,
      );
      final clipPaths = find.descendant(
        of: find.byType(RetroMiniPlayerArt),
        matching: find.byType(ClipPath),
      );
      expect(clipPaths, findsAtLeastNWidgets(2)); // Outer disc body + inner cover art label

      // Disable rotation
      container.read(miniPlayerArtSettingsProvider.notifier).setRotating(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // RotationTransition should no longer be present inside RetroMiniPlayerArt
      expect(
        find.descendant(of: find.byType(RetroMiniPlayerArt), matching: find.byType(RotationTransition)),
        findsNothing,
      );
    });

    testWidgets('NowPlayingScreen switches between box and vinyl cover art and handles rotation', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: NowPlayingScreen(isDrawer: false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // By default (BOX), RetroNowPlayingArt renders standard RetroAlbumArt
      expect(find.byType(RetroNowPlayingArt), findsOneWidget);
      expect(
        find.descendant(of: find.byType(RetroNowPlayingArt), matching: find.byType(RetroAlbumArt)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(RetroNowPlayingArt), matching: find.byType(RotationTransition)),
        findsNothing,
      );

      // Switch to VINYL style with rotation enabled
      final element = tester.element(find.byType(NowPlayingScreen));
      final container = ProviderScope.containerOf(element);
      container.read(nowPlayingArtSettingsProvider.notifier).setStyle(NowPlayingArtStyle.vinyl);
      container.read(nowPlayingArtSettingsProvider.notifier).setRotating(true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now RotationTransition should be present inside RetroNowPlayingArt around the vinyl disc
      expect(
        find.descendant(of: find.byType(RetroNowPlayingArt), matching: find.byType(RotationTransition)),
        findsOneWidget,
      );

      // Verify that 8-bit pixel clipping is used instead of a smooth/clear circle ClipOval
      expect(
        find.descendant(of: find.byType(RetroNowPlayingArt), matching: find.byType(ClipOval)),
        findsNothing,
      );
      final clipPaths = find.descendant(
        of: find.byType(RetroNowPlayingArt),
        matching: find.byType(ClipPath),
      );
      expect(clipPaths, findsAtLeastNWidgets(2)); // Outer disc body + inner cover art label

      // Disable rotation
      container.read(nowPlayingArtSettingsProvider.notifier).setRotating(false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // RotationTransition should no longer be present inside RetroNowPlayingArt
      expect(
        find.descendant(of: find.byType(RetroNowPlayingArt), matching: find.byType(RotationTransition)),
        findsNothing,
      );
    });

    testWidgets('RetroMarqueeText keeps short text static and scrolls long text horizontally', (tester) async {
      // 1. Short text in wide container -> stays static
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: SizedBox(
              width: 300,
              child: RetroMarqueeText(
                text: 'Short Title',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Short Title'), findsOneWidget);
      final staticTransform = tester.widget<Transform>(
        find.descendant(of: find.byType(RetroMarqueeText), matching: find.byType(Transform)),
      );
      expect(staticTransform.transform.getTranslation().x, equals(0.0));

      // 2. Long text in narrow container -> triggers horizontal sliding animation
      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: const Scaffold(
            body: SizedBox(
              width: 60,
              child: RetroMarqueeText(
                text: 'Extremely Long Song Title That Overflows Bound',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // After initial hold (1800ms) and partway into scroll animation
      await tester.pump(const Duration(milliseconds: 2000));
      await tester.pump(const Duration(milliseconds: 500));

      final animatedTransform = tester.widget<Transform>(
        find.descendant(of: find.byType(RetroMarqueeText), matching: find.byType(Transform)),
      );
      // Translation offset must have moved to the left (< 0.0)
      expect(animatedTransform.transform.getTranslation().x, lessThan(0.0));
    });

    testWidgets('MiniPlayer uses RetroMarqueeText for song title', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: MiniPlayer(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(RetroMarqueeText), findsOneWidget);
      expect(find.text('Chiptune'), findsOneWidget);
    });

    testWidgets('QueueSheet displays drag_handle and trash icons for queue tracks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayerNotifierWithQueue.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: QueueSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(QueueSheet), findsOneWidget);
      expect(find.text('2 TRACKS'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'drag_handle'),
        findsNWidgets(2),
      );
      expect(
        find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'trash'),
        findsNWidgets(2),
      );
    });

    testWidgets('Tapping CLEAR in QueueSheet keeps current playing song and does not stop player', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            playerProvider.overrideWith(MockPlayerNotifierWithQueue.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => QueueSheet.showAsDrawer(context),
                    child: const Text('OPEN QUEUE'),
                  ),
                ),
              ),
              bottomNavigationBar: const MiniPlayer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // MiniPlayer is initially present
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.text('Chiptune 1'), findsOneWidget);

      // Open QueueSheet
      await tester.tap(find.text('OPEN QUEUE'));
      await tester.pumpAndSettle();
      expect(find.byType(QueueSheet), findsOneWidget);

      // Tap CLEAR
      expect(find.text('CLEAR'), findsOneWidget);
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();

      // Confirmation dialog should be displayed
      expect(find.text('CLEAR QUEUE?'), findsOneWidget);
      expect(find.text('Are you sure you want to clear all tracks from the queue?'), findsOneWidget);

      // First test CANCEL:
      expect(find.text('CANCEL'), findsOneWidget);
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      // Dialog dismissed, QueueSheet still open
      expect(find.text('CLEAR QUEUE?'), findsNothing);
      expect(find.byType(QueueSheet), findsOneWidget);

      // Tap CLEAR again and confirm
      await tester.tap(find.text('CLEAR'));
      await tester.pumpAndSettle();
      expect(find.text('CLEAR QUEUE?'), findsOneWidget);

      // Tap the confirm CLEAR button in the dialog
      final confirmClear = find.widgetWithText(RetroButton, 'CLEAR');
      await tester.tap(confirmClear.last);
      await tester.pumpAndSettle();

      // QueueSheet dismissed, MiniPlayer is still visible and song remains active
      expect(find.byType(QueueSheet), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);
      expect(find.text('Chiptune 1'), findsOneWidget);
    });

    testWidgets('volume RetroIcon renders and RetroSongTile displays it vertically centered when playing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: Scaffold(
              body: Column(
                children: [
                  const RetroIcon('volume', size: 16),
                  RetroSongTile(
                    song: const Song(
                      id: 's1',
                      title: 'Faded',
                      artist: 'Alan Walker',
                      album: 'Faded',
                      duration: Duration(seconds: 212),
                      uri: 'faded.mp3',
                      quality: AudioQuality(format: 'FLAC', bitDepth: 16, sampleRate: 44100),
                    ),
                    queue: const [
                      Song(
                        id: 's1',
                        title: 'Faded',
                        artist: 'Alan Walker',
                        album: 'Faded',
                        duration: Duration(seconds: 212),
                        uri: 'faded.mp3',
                        quality: AudioQuality(format: 'FLAC', bitDepth: 16, sampleRate: 44100),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final volumeIcons = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'volume');
      expect(volumeIcons, findsNWidgets(2));

      // Verify the volume icon inside RetroSongTile is centered vertically relative to the tile
      final tileFinder = find.byType(RetroSongTile);
      final tileRect = tester.getRect(tileFinder);
      final tileVolumeFinder = find.descendant(of: tileFinder, matching: find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'volume'));
      final volumeRect = tester.getRect(tileVolumeFinder);

      // Center Y of tile vs center Y of volume icon should be aligned within 2px
      expect((tileRect.center.dy - volumeRect.center.dy).abs(), lessThanOrEqualTo(2.0));
    });

    testWidgets('RetroSongTile displays small heart icon next to song title when favorite', (tester) async {
      const favSong = Song(
        id: 'fav_1',
        title: 'Starboy',
        artist: 'The Weeknd',
        album: 'Starboy',
        duration: Duration(seconds: 230),
        uri: 'starboy.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
        isFavorite: true,
      );
      const nonFavSong = Song(
        id: 'non_fav_2',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        album: 'After Hours',
        duration: Duration(seconds: 200),
        uri: 'blinding.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
        isFavorite: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(
              () => MockLibraryWithCustomState(
                const LibraryState(
                  allSongs: [favSong, nonFavSong],
                  isLoading: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: Column(
                children: [
                  RetroSongTile(song: favSong, queue: [favSong, nonFavSong]),
                  RetroSongTile(song: nonFavSong, queue: [favSong, nonFavSong]),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly one filled heart icon of size 11 rendered for the favorited song
      final heartIcons = find.byWidgetPredicate(
        (w) => w is RetroIcon && w.iconName == 'heart_filled' && w.size == 11 && w.color == RetroColors.picoRed,
      );
      expect(heartIcons, findsOneWidget);

      // Verify the heart icon is a sibling to the song title
      expect(
        find.descendant(
          of: find.ancestor(of: find.text('Starboy'), matching: find.byType(Row)),
          matching: heartIcons,
        ),
        findsOneWidget,
      );
    });

    testWidgets('SettingsScreen uses identical 8-bit RetroIcon(vinyl, size: 18) for both mini player and now playing switches', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final vinylIcons = find.byWidgetPredicate(
        (w) => w is RetroIcon && w.iconName == 'vinyl' && w.size == 18,
      );
      // Both Mini Player and Now Playing cover art cards use RetroIcon('vinyl', size: 18)
      expect(vinylIcons, findsNWidgets(2));
    });

    testWidgets('SettingsScreen App Font card expands, lists fonts, and selects font', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('APPEARANCE & THEME'), findsOneWidget);
      expect(find.text('APP FONT'), findsOneWidget);
      expect(find.text('TYPOGRAPHY STYLE'), findsOneWidget);

      final expandBtn = find.text('SELECT APP FONT (3 AVAILABLE)');
      expect(expandBtn, findsOneWidget);

      await tester.tap(expandBtn);
      await tester.pumpAndSettle();

      expect(find.text('COLLAPSE FONT LIST'), findsOneWidget);
      expect(find.text('Press Start 2P'), findsWidgets);
      expect(find.text('Satoshi'), findsWidgets);
      expect(find.text('Gotham'), findsWidgets);

      await tester.tap(find.text('Gotham').first);
      await tester.pumpAndSettle();

      expect(RetroTypography.currentFontFamily, equals('Gotham'));
      expect(mockSettings.getAppFont(), equals('Gotham'));

      // Reset
      RetroTypography.setFontFamily('PressStart2P');
    });


    testWidgets('RetroVolumeSlider renders speaker icon, percentage, and reacts to taps/drags', (tester) async {
      double currentVolume = 0.75;

      await tester.pumpWidget(
        MaterialApp(
          theme: RetroTheme.lightTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return RetroVolumeSlider(
                  volume: currentVolume,
                  onVolumeChanged: (newVol) {
                    setState(() {
                      currentVolume = newVol;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      // Initial state: 75% and speaker volume icon
      expect(find.text('75%'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'volume'), findsOneWidget);

      // Tap speaker button to mute
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(currentVolume, 0.0);
      expect(find.text('0%'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'volume_mute'), findsOneWidget);

      // Tap speaker button again to unmute / restore previous volume
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(currentVolume, 0.75);
      expect(find.text('75%'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'volume'), findsOneWidget);
    });

    testWidgets('PlaylistDetailScreen supports searching and sorting tracks inside playlist', (tester) async {
      final songA = Song(
        id: 's_zelda',
        title: 'Zelda Lullaby',
        artist: 'Koji Kondo',
        album: 'Nintendo Classics',
        duration: const Duration(seconds: 120),
        uri: 'assets/audio/zelda.wav',
        quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
      );
      final songB = Song(
        id: 's_arcade',
        title: 'Arcade Adventure',
        artist: 'Pixel Beat',
        album: 'Retro Gems',
        duration: const Duration(seconds: 200),
        uri: 'assets/audio/arcade.wav',
        quality: const AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      final songC = Song(
        id: 's_mega',
        title: 'Mega Drive Blast',
        artist: 'Yuzo Koshiro',
        album: 'Sega Hits',
        duration: const Duration(seconds: 90),
        uri: 'assets/audio/mega.wav',
        quality: const AudioQuality(format: 'FLAC', bitDepth: 24, sampleRate: 96000),
      );

      final multiSongPlaylist = Playlist(
        id: 'multi_test_playlist',
        name: 'Game Soundtracks',
        songIds: ['s_zelda', 's_arcade', 's_mega'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
              LibraryState(
                allSongs: [songA, songB, songC],
                folders: {'/Games': [songA, songB, songC]},
                isLoading: false,
              ),
            )),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: multiSongPlaylist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initial State: 3 tracks rendered in default order
      expect(find.text('3 TRACKS'), findsOneWidget);
      expect(find.text('SEARCH TRACKS'), findsOneWidget);
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('Zelda Lullaby'), findsOneWidget);
      expect(find.text('Arcade Adventure'), findsOneWidget);
      expect(find.text('Mega Drive Blast'), findsOneWidget);

      // 2. Search functionality: Tap SEARCH TRACKS to reveal inline input
      await tester.tap(find.text('SEARCH TRACKS'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'arcade');
      await tester.pumpAndSettle();

      // Only Arcade Adventure should be visible
      expect(find.text('Arcade Adventure'), findsOneWidget);
      expect(find.text('Zelda Lullaby'), findsNothing);
      expect(find.text('Mega Drive Blast'), findsNothing);
      expect(find.text('1/3 TRACKS'), findsOneWidget);

      // Search with non-matching query
      await tester.enterText(find.byType(TextField), 'synthwave');
      await tester.pumpAndSettle();

      expect(find.text('NO TRACKS MATCHING "SYNTHWAVE"'), findsOneWidget);
      expect(find.text('CLEAR SEARCH'), findsOneWidget);

      // Tap CLEAR SEARCH
      await tester.tap(find.text('CLEAR SEARCH'));
      await tester.pumpAndSettle();

      expect(find.text('Zelda Lullaby'), findsOneWidget);
      expect(find.text('Arcade Adventure'), findsOneWidget);
      expect(find.text('Mega Drive Blast'), findsOneWidget);

      // 3. Sort functionality: Open sort dropdown
      await tester.tap(find.text('DEFAULT'));
      await tester.pumpAndSettle();

      expect(find.text('SORT BY TITLE'), findsOneWidget);
      expect(find.text('SORT BY ARTIST'), findsOneWidget);
      expect(find.text('SORT BY DURATION'), findsOneWidget);

      // Select SORT BY TITLE (A -> Z)
      await tester.tap(find.text('SORT BY TITLE'));
      await tester.pumpAndSettle();

      expect(find.text('TITLE'), findsOneWidget);
      expect(find.text('▲'), findsWidgets);
      expect(find.text('▼'), findsWidgets);

      // Verify tiles are rendered in alphabetical order: Arcade Adventure (index 0), Mega Drive Blast (index 1), Zelda Lullaby (index 2)
      final tiles = tester.widgetList<RetroSongTile>(find.byType(RetroSongTile)).toList();
      expect(tiles.length, 3);
      expect(tiles[0].song.title, 'Arcade Adventure');
      expect(tiles[1].song.title, 'Mega Drive Blast');
      expect(tiles[2].song.title, 'Zelda Lullaby');

      // Tap down arrow ▼ to toggle descending (Z -> A)
      await tester.tap(find.text('▼').first);
      await tester.pumpAndSettle();

      final descTiles = tester.widgetList<RetroSongTile>(find.byType(RetroSongTile)).toList();
      expect(descTiles[0].song.title, 'Zelda Lullaby');
      expect(descTiles[1].song.title, 'Mega Drive Blast');
      expect(descTiles[2].song.title, 'Arcade Adventure');

      // Tap up arrow ▲ to toggle ascending back (A -> Z)
      await tester.tap(find.text('▲').first);
      await tester.pumpAndSettle();

      final ascTiles = tester.widgetList<RetroSongTile>(find.byType(RetroSongTile)).toList();
      expect(ascTiles[0].song.title, 'Arcade Adventure');
      expect(ascTiles[1].song.title, 'Mega Drive Blast');
      expect(ascTiles[2].song.title, 'Zelda Lullaby');
    });

    testWidgets('PlaylistDetailScreen search text is vertically centered and unfocuses on tap outside', (tester) async {
      final samplePlaylist = Playlist(
        id: 'search_focus_test',
        name: 'Focus Test',
        songIds: ['s1'],
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: samplePlaylist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open search input
      await tester.tap(find.text('SEARCH TRACKS'));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.textAlignVertical, equals(TextAlignVertical.center));
      expect(textField.decoration?.isDense, isTrue);

      // Verify search field is focused
      expect(textField.focusNode?.hasFocus, isTrue);

      // Tap outside (on playlist name or banner)
      await tester.tap(find.text('Focus Test'));
      await tester.pumpAndSettle();

      // Focus is dismissed
      expect(textField.focusNode?.hasFocus, isFalse);
    });

    testWidgets('PlaylistDetailScreen dynamically hides and shows details banner on scroll', (tester) async {
      final List<Song> songs = List.generate(
        25,
        (i) => Song(
          id: 'song_$i',
          title: 'Track #$i',
          artist: 'Artist #$i',
          album: 'Album #$i',
          duration: const Duration(seconds: 180),
          uri: 'assets/audio/song_$i.mp3',
          quality: const AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
        ),
      );

      final longPlaylist = Playlist(
        id: 'long_playlist',
        name: 'Mega Mix',
        songIds: songs.map((s) => s.id).toList(),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
              LibraryState(
                allSongs: songs,
                folders: {'/Music': songs},
                isLoading: false,
              ),
            )),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: longPlaylist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially, details banner is visible with PLAY ALL button
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('Mega Mix'), findsOneWidget);

      // Scroll down (drag up on CustomScrollView)
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Details banner has scrolled out of view to give more room for tracks
      expect(find.text('PLAY ALL'), findsNothing);

      // Scroll back up (drag down on CustomScrollView)
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.pumpAndSettle();

      // Details banner is back in view
      expect(find.text('PLAY ALL'), findsOneWidget);

      // Tapping title in AppBar also toggles visibility manually
      await tester.tap(find.text('MEGA MIX'));
      await tester.pumpAndSettle();

      // Now hidden again
      expect(find.text('PLAY ALL'), findsNothing);
    });

    testWidgets('SettingsScreen renders COLOR PALETTE card and allows selecting Dark and Light palettes', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository(isDarkMode: true)),
            themeProvider.overrideWith(() => MockThemeNotifier(initialDark: true)),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );

      // Scroll down to COLOR PALETTE card and ensure dropdown is fully visible
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('palette_dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('DARK PALETTES'), findsOneWidget);
      expect(find.byKey(const ValueKey('palette_dropdown')), findsOneWidget);

      // Tap on palette dropdown to open options
      await tester.tap(find.byKey(const ValueKey('palette_dropdown')));
      await tester.pumpAndSettle();

      // Verify Dark palettes are listed in dropdown
      expect(find.text('WARM ESPRESSO'), findsWidgets);
      expect(find.text('CYBER SLATE'), findsWidgets);
      expect(find.text('OBSIDIAN OLIVE'), findsWidgets);
      expect(find.text('JET BLACK'), findsWidgets);
      // Verify light palettes are not shown in dark mode
      expect(find.text('PASTEL LAVENDER'), findsNothing);

      // Tap on JET BLACK option
      await tester.tap(find.text('JET BLACK').last);
      await tester.pumpAndSettle();

      // Scroll up to VISUAL THEME card and switch to LIGHT mode
      await tester.drag(find.byType(ListView).first, const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LIGHT RETRO'));
      await tester.pumpAndSettle();

      // Scroll back down to COLOR PALETTE dropdown
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('palette_dropdown')));
      await tester.pumpAndSettle();
      expect(find.text('LIGHT PALETTES'), findsOneWidget);

      // Tap on palette dropdown to open light options
      await tester.tap(find.byKey(const ValueKey('palette_dropdown')));
      await tester.pumpAndSettle();

      // Verify Light palettes are listed
      expect(find.text('VINTAGE HANDHELD'), findsWidgets);
      expect(find.text('DESERT SAGE'), findsWidgets);
      expect(find.text('OLIVE GROVE'), findsWidgets);
      expect(find.text('PASTEL LAVENDER'), findsWidgets);
      // Verify dark palettes are not in light dropdown
      expect(find.text('JET BLACK'), findsNothing);

      // Tap on PASTEL LAVENDER
      await tester.tap(find.text('PASTEL LAVENDER').last);
      await tester.pumpAndSettle();
    });

    testWidgets('SettingsScreen renders "Made with [heart] by Asrar" footer at the bottom', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to the bottom to reveal the footer
      await tester.scrollUntilVisible(find.text('Made with '), 300);
      expect(find.text('Made with '), findsOneWidget);
      expect(find.text(' by Asrar'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is RetroIcon && w.iconName == 'heart_filled' && w.color == const Color(0xFFE53935),
        ),
        findsOneWidget,
      );
    });

    testWidgets('RetroSongTile ADD TO PLAYLIST dialog displays playlist cover for existing playlists', (tester) async {
      final song = Song(
        id: 's1',
        title: 'Chiptune',
        artist: 'Retro',
        album: 'Album',
        duration: const Duration(seconds: 30),
        uri: 'assets/audio/chiptune_quest.wav',
        quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: Scaffold(
              body: RetroSongTile(
                song: song,
                queue: [song],
                index: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the three-dot popup menu
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      // Tap ADD TO PLAYLIST
      await tester.tap(find.text('ADD TO PLAYLIST'));
      await tester.pumpAndSettle();

      // Verify ADD TO PLAYLIST dialog is visible
      expect(find.text('ADD TO PLAYLIST'), findsWidgets);
      expect(find.text('Retro Hits'), findsOneWidget);

      // Verify playlist cover art is rendered in the dialog
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Retro Hits'),
          matching: find.byType(Container),
        ),
        findsWidgets,
      );
    });

    testWidgets('PlaylistDetailScreen renders fixed-length RetroScrollThumb and floating TOP button on scroll', (tester) async {
      final List<Song> songs = List.generate(
        30,
        (i) => Song(
          id: 's_$i',
          title: 'Track #$i',
          artist: 'Artist #$i',
          album: 'Album #$i',
          duration: const Duration(seconds: 200),
          uri: 'assets/audio/s_$i.mp3',
          quality: const AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
        ),
      );

      final playlist = Playlist(
        id: 'test_scroll_pl',
        name: 'Scroll Party',
        songIds: songs.map((s) => s.id).toList(),
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryWithCustomState(
              LibraryState(
                allSongs: songs,
                folders: {'/Music': songs},
                isLoading: false,
              ),
            )),
            playlistProvider.overrideWith(MockPlaylistNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: playlist,
              isFavorites: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify RetroScrollThumb is present with fixed height (44.0), thickness (4.0), and starts at first song
      final thumbFinder = find.byType(RetroScrollThumb);
      expect(thumbFinder, findsOneWidget);
      final thumb = tester.widget<RetroScrollThumb>(thumbFinder);
      expect(thumb.thumbHeight, 44.0);
      expect(thumb.thickness, 4.0);
      expect(thumb.initialTop, isNotNull);
      expect(thumb.initialTop!, greaterThan(200.0));

      // Initially, TOP button is not visible
      expect(find.text('TOP'), findsNothing);

      // Scroll down
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // TOP button is now visible
      expect(find.text('TOP'), findsOneWidget);

      // Tap TOP button
      await tester.tap(find.text('TOP'));
      await tester.pumpAndSettle();

      // Scrolled back to top
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('TOP'), findsNothing);
    });

    testWidgets('PlaylistsScreen collapses FAB to icon on scroll and expands on scroll up', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithManyPlaylists.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: PlaylistsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FAB has only icon and no text
      expect(find.text('NEW PLAYLIST'), findsNothing);
      final fabButtonFinder = find.byKey(const ValueKey('playlists_new_playlist_fab'));
      expect(fabButtonFinder, findsOneWidget);

      // Tapping FAB opens create modal
      await tester.tap(fabButtonFinder);
      await tester.pumpAndSettle();
      expect(find.text('CANCEL'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
    });

    testWidgets('Playlist playback settings: SHUFFLE PLAY activates shuffle and saves preference, PLAY ALL restores previous settings', (tester) async {
      final List<Song> songs = List.generate(
        5,
        (i) => Song(
          id: 'track_$i',
          title: 'Song #$i',
          artist: 'Artist #$i',
          album: 'Album #$i',
          duration: const Duration(seconds: 180),
          uri: 'assets/audio/track_$i.mp3',
          quality: const AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
        ),
      );

      final playlist = Playlist(
        id: 'pref_test_playlist',
        name: 'Preferences Playlist',
        songIds: songs.map((s) => s.id).toList(),
        createdAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(() => MockLibraryWithCustomState(
            LibraryState(
              allSongs: songs,
              folders: {'/Music': songs},
              isLoading: false,
            ),
          )),
          playlistProvider.overrideWith(MockPlaylistNotifier.new),
          settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          playerProvider.overrideWith(MockPlayerNotifierForPreferences.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: playlist,
              isFavorites: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify SHUFFLE PLAY button exists
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);

      // Tap SHUFFLE PLAY
      await tester.tap(find.text('SHUFFLE PLAY'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify player state has isShuffle = true and currentPlaylistId set
      final playerState = container.read(playerProvider);
      expect(playerState.isShuffle, isTrue);
      expect(playerState.currentPlaylistId, 'pref_test_playlist');

      // Verify StorageService saved isShuffle = true for this playlist
      final storage = StorageService();
      final savedSettings = storage.getPlaylistPlaybackSettings('pref_test_playlist');
      expect(savedSettings['isShuffle'], isTrue);

      // Now toggle shuffle OFF in playerNotifier (e.g. user toggled in Now Playing)
      await container.read(playerProvider.notifier).toggleShuffle();
      expect(container.read(playerProvider).isShuffle, isFalse);
      expect(storage.getPlaylistPlaybackSettings('pref_test_playlist')['isShuffle'], isFalse);

      // Now tap PLAY ALL to verify previous settings (isShuffle: false) are restored
      await tester.tap(find.text('PLAY ALL'));
      await tester.pump(const Duration(milliseconds: 100));

      final updatedState = container.read(playerProvider);
      expect(updatedState.isShuffle, isFalse);
      expect(updatedState.currentPlaylistId, 'pref_test_playlist');
    });

    testWidgets('PlaylistDetailScreen does not display edit icon in playlist cover or next to name', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: PlaylistDetailScreen(
              playlist: Playlist(
                id: 'playlist_clean_header',
                name: 'Clean Playlist',
                songIds: ['s1'],
                createdAt: DateTime.now(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Playlist name is displayed
      expect(find.text('Clean Playlist'), findsOneWidget);

      // Verify no RetroIcon('edit') is in the header cover or next to playlist name
      final editIcons = find.byWidgetPredicate(
        (w) => w is RetroIcon && w.iconName == 'edit',
      );
      // The only edit option is in the 3-dot popup menu when opened, not inline in header
      expect(editIcons, findsNothing);
    });

    testWidgets('NowPlayingScreen has collapse chevron button that dismisses the drawer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Swipe up on MiniPlayer opens NowPlayingScreen drawer
      await tester.fling(find.byType(MiniPlayer), const Offset(0, -300), 1000);
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Verify chevron_down collapse button is removed from drawer header
      final chevronDown = find.byWidgetPredicate(
        (w) => w is RetroIcon && w.iconName == 'chevron_down',
      );
      expect(chevronDown, findsNothing);

      // Swipe down on album art to collapse the drawer
      await tester.fling(find.byType(RetroNowPlayingArt), const Offset(0, 500), 1000);
      await tester.pumpAndSettle();

      // Drawer is collapsed
      expect(find.byType(NowPlayingScreen), findsNothing);
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('Swiping up in NowPlayingScreen opens QueueSheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open NowPlayingScreen drawer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Open queue via the QUEUE utility button
      final queueBtn = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.widgetWithText(RetroButton, 'QUEUE'),
      );
      await tester.tap(queueBtn);
      await tester.pumpAndSettle();

      // Verify QueueSheet is open
      expect(find.byType(QueueSheet), findsOneWidget);

      // Dismiss QueueSheet
      await tester.drag(find.text('PLAYBACK QUEUE'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(find.byType(QueueSheet), findsNothing);
      expect(find.byType(NowPlayingScreen), findsOneWidget);
    });

    testWidgets('Swiping down to collapse and cancelling back up does NOT open QueueSheet', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open NowPlayingScreen drawer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();
      expect(find.byType(NowPlayingScreen), findsOneWidget);

      // Start swiping down on NowPlayingScreen and cancel back up
      final nowPlayingAlbumArt = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.byType(RetroAlbumArt),
      );
      final center = tester.getCenter(nowPlayingAlbumArt);

      final gesture = await tester.startGesture(center);
      // Drag down by 80px to start collapse
      await gesture.moveBy(const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 30));

      // Cancel back by swiping up past the origin
      await gesture.moveBy(const Offset(0, -120));
      await tester.pump(const Duration(milliseconds: 30));
      await gesture.up();
      await tester.pumpAndSettle();

      // Verify QueueSheet did NOT open
      expect(find.byType(QueueSheet), findsNothing);
      expect(find.byType(NowPlayingScreen), findsOneWidget);
    });

    testWidgets('QueueSheet collapses on swipe down', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open NowPlayingScreen drawer
      await tester.tap(find.byType(MiniPlayer));
      await tester.pumpAndSettle();

      // Open queue via the QUEUE utility button
      final queueBtn = find.descendant(
        of: find.byType(NowPlayingScreen),
        matching: find.widgetWithText(RetroButton, 'QUEUE'),
      );
      await tester.tap(queueBtn);
      await tester.pumpAndSettle();

      expect(find.byType(QueueSheet), findsOneWidget);
      expect(find.text('PLAYBACK QUEUE'), findsOneWidget);

      // Swipe down on the QueueSheet header to collapse
      await tester.fling(find.text('PLAYBACK QUEUE'), const Offset(0, 300), 800);
      await tester.pumpAndSettle();

      // Verify QueueSheet is dismissed
      expect(find.byType(QueueSheet), findsNothing);
      expect(find.byType(NowPlayingScreen), findsOneWidget);
    });

    testWidgets('Reordering songs downward in QueueSheet does not dismiss the drawer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayerNotifierWithQueue.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: QueueSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(QueueSheet), findsOneWidget);
      expect(find.text('2 TRACKS'), findsOneWidget);

      // Locate first song drag handle and drag it downward
      final firstDragHandle = find.byType(ReorderableDragStartListener).first;
      await tester.drag(firstDragHandle, const Offset(0, 120));
      await tester.pumpAndSettle();

      // Verify QueueSheet is still open and was not dismissed
      expect(find.byType(QueueSheet), findsOneWidget);
      expect(find.text('PLAYBACK QUEUE'), findsOneWidget);
    });

    testWidgets('Tapping SEARCH in bottom navbar focuses the input field when in SearchScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap SEARCH tab in BottomNavigationBar
      await tester.tap(find.text('SEARCH'));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      final TextField textField = tester.widget(textFieldFinder);
      expect(textField.focusNode?.hasFocus, isTrue);

      // Unfocus the text field
      textField.focusNode?.unfocus();
      await tester.pumpAndSettle();
      expect(textField.focusNode?.hasFocus, isFalse);

      // Tap SEARCH tab again in bottom navbar
      await tester.tap(find.text('SEARCH'));
      await tester.pumpAndSettle();

      // Verify text field has regained focus
      expect(textField.focusNode?.hasFocus, isTrue);

      // Tap SEARCH tab when already in focus to verify it cycles focus and forces keyboard show
      await tester.tap(find.text('SEARCH'));
      await tester.pumpAndSettle();
      expect(textField.focusNode?.hasFocus, isTrue);
    });

    testWidgets('HomeScaffold preserves BottomNavigationBar and MiniPlayer when opening album, artist, and folder from LibraryScreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // BottomNavigationBar and MiniPlayer are visible on root library
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // --- 1. Test Album Navigation ---
      await tester.tap(find.text('ALBUMS'));
      await tester.pumpAndSettle();
      expect(find.text('Album'), findsOneWidget);

      // Tap the album card
      await tester.tap(find.byType(RetroCard).first);
      await tester.pumpAndSettle();

      // AlbumDetailScreen is active
      expect(find.byType(AlbumDetailScreen), findsOneWidget);
      // CRITICAL ASSERTION: BottomNavigationBar and MiniPlayer MUST STILL BE VISIBLE!
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Tap back button to return to albums list
      final backButtonFinder = find.byWidgetPredicate(
        (w) => w is IconButton && w.icon is RetroIcon && (w.icon as RetroIcon).iconName == 'arrow_left',
      );
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumDetailScreen), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // --- 2. Test Artist Navigation ---
      await tester.tap(find.text('ARTISTS'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(ArtistsTab), matching: find.text('Retro')), findsOneWidget);

      // Tap the artist card
      await tester.tap(find.descendant(of: find.byType(ArtistsTab), matching: find.byType(RetroCard)).first);
      await tester.pumpAndSettle();

      // ArtistDetailScreen is active
      expect(find.byType(ArtistDetailScreen), findsOneWidget);
      // CRITICAL ASSERTION: BottomNavigationBar and MiniPlayer MUST STILL BE VISIBLE!
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Tap back button
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();
      expect(find.byType(ArtistDetailScreen), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // --- 3. Test Folder Navigation ---
      await tester.tap(find.text('FOLDERS'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(FoldersTab), matching: find.text('Retro')), findsOneWidget);

      // Tap the folder card
      await tester.tap(find.descendant(of: find.byType(FoldersTab), matching: find.byType(RetroCard)).first);
      await tester.pumpAndSettle();

      // FolderDetailScreen is active
      expect(find.byType(FolderDetailScreen), findsOneWidget);
      // CRITICAL ASSERTION: BottomNavigationBar and MiniPlayer MUST STILL BE VISIBLE!
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Tap LIBRARY on bottom navbar to pop to root
      await tester.tap(find.text('LIBRARY'));
      await tester.pumpAndSettle();
      expect(find.byType(FolderDetailScreen), findsNothing);
      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(MiniPlayer), findsOneWidget);
    });

    testWidgets('AlbumsTab switches between Grid and List views and persists preference', (tester) async {
      final mockSettings = MockSettingsRepository();
      mockSettings.setAlbumGridView(true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            settingsRepositoryProvider.overrideWithValue(mockSettings),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(body: AlbumsTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial view mode is GridView
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);

      final listIconFinder = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'list');
      final gridIconFinder = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'grid');

      // Tap LIST button
      await tester.tap(listIconFinder);
      await tester.pumpAndSettle();

      // View mode switched to ListView and persisted to repository
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(mockSettings.isAlbumGridView(), isFalse);

      // Tap GRID button
      await tester.tap(gridIconFinder);
      await tester.pumpAndSettle();

      // View mode switched back to GridView
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(mockSettings.isAlbumGridView(), isTrue);
    });

    testWidgets('ArtistsTab switches between List and Grid views and persists preference', (tester) async {
      final mockSettings = MockSettingsRepository();
      mockSettings.setArtistGridView(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            settingsRepositoryProvider.overrideWithValue(mockSettings),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(body: ArtistsTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initial view mode is ListView
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);

      final listIconFinder = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'list');
      final gridIconFinder = find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'grid');

      // Tap GRID button
      await tester.tap(gridIconFinder);
      await tester.pumpAndSettle();

      // View mode switched to GridView and persisted to repository
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
      expect(mockSettings.isArtistGridView(), isTrue);

      // Tap LIST button
      await tester.tap(listIconFinder);
      await tester.pumpAndSettle();

      // View mode switched back to ListView
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(GridView), findsNothing);
      expect(mockSettings.isArtistGridView(), isFalse);
    });

    testWidgets('Library tab section screens support search and sort functionality', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(body: AllSongsTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AllSongsTab search button
      expect(find.text('SEARCH TRACKS'), findsOneWidget);
      await tester.tap(find.text('SEARCH TRACKS'));
      await tester.pumpAndSettle();

      // Search input is open
      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'NonExistent');
      await tester.pumpAndSettle();

      // Empty search state
      expect(find.text('NO MATCHING TRACKS FOUND'), findsOneWidget);
      expect(find.text('CLEAR SEARCH'), findsOneWidget);

      // Tap CLEAR SEARCH
      await tester.tap(find.text('CLEAR SEARCH'));
      await tester.pumpAndSettle();

      // Track restored
      expect(find.text('Chiptune'), findsOneWidget);
    });

    testWidgets('RecentlyPlayedGrid renders 2-column quick navigation tiles and navigates on tap', (tester) async {
      final recentItems = [
        RecentlyPlayedItem(
          id: 'album_Album',
          type: RecentItemType.album,
          title: 'Album',
          subtitle: 'Retro',
          playedAt: DateTime.now(),
        ),
        RecentlyPlayedItem(
          id: 'artist_Retro',
          type: RecentItemType.artist,
          title: 'Retro',
          subtitle: 'Artist',
          playedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
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

      // Header is visible (badge removed) and renders history RetroIcon
      expect(find.text('RECENTLY PLAYED'), findsOneWidget);
      expect(find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'history'), findsOneWidget);
      expect(find.text('2 RECENTS'), findsNothing);

      // Both items are displayed in the 2-column layout
      expect(find.text('Album'), findsOneWidget);
      expect(find.text('Retro'), findsWidgets);

      // Tap album tile navigates to AlbumDetailScreen
      await tester.tap(find.text('Album'));
      await tester.pumpAndSettle();
      expect(find.byType(AlbumDetailScreen), findsOneWidget);
    });

    testWidgets('Library tab toolbars fit without overflow even on narrow screen widths', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(body: AllSongsTab()),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('1 TRACKS'), findsOneWidget);
      expect(find.text('IMPORT'), findsOneWidget);
    });

    testWidgets('LibraryScreen scrolls recents up, sticks TabBar to top, and shows scroll to top button', (tester) async {
      final recentItems = [
        RecentlyPlayedItem(
          id: 'album_Album',
          type: RecentItemType.album,
          title: 'Album',
          subtitle: 'Retro',
          playedAt: DateTime.now(),
        ),
      ];

      final manySongs = List.generate(
        30,
        (i) => Song(
          id: 'song_$i',
          title: 'Track $i',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
          uri: 'assets/audio/test.mp3',
          quality: const AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryNotifierWithSongs(manySongs)),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const LibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, RecentlyPlayedGrid is visible
      expect(find.byType(RecentlyPlayedGrid), findsOneWidget);
      expect(find.text('RECENTLY PLAYED'), findsOneWidget);
      expect(find.text('SONGS'), findsOneWidget);

      // Scroll to top button is initially NOT visible
      expect(find.text('TOP'), findsNothing);

      // Scroll down the songs list
      await tester.drag(find.text('Track 0'), const Offset(0, -400));
      await tester.pumpAndSettle();

      // TabBar is still visible (pinned to top)
      expect(find.text('SONGS'), findsOneWidget);
      expect(find.text('ALBUMS'), findsOneWidget);

      // Search & filters toolbar is ALSO pinned and visible with TabBar when scrolled!
      expect(find.text('SEARCH TRACKS'), findsOneWidget);
      expect(find.text('30 TRACKS'), findsOneWidget);

      // The TOP button is now visible and aligned to bottom-right (does not block center song titles)
      expect(find.text('TOP'), findsOneWidget);
      final topButton = find.ancestor(of: find.text('TOP'), matching: find.byType(RetroButton));
      final topButtonCenter = tester.getCenter(topButton);
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(topButtonCenter.dx, greaterThan(screenWidth / 2));

      // Tap TOP button
      await tester.tap(find.text('TOP'));
      await tester.pumpAndSettle();

      // Recents grid and Track 0 are visible again at the top
      expect(find.text('RECENTLY PLAYED'), findsOneWidget);
      expect(find.text('Track 0'), findsOneWidget);
      expect(find.text('TOP'), findsNothing);
    });

    testWidgets('LibraryScreen sticky search and filter toolbar sticks with tab navigation when scrolled across tabs', (tester) async {
      final manySongs = List.generate(
        25,
        (i) => Song(
          id: 'song_$i',
          title: 'Track $i',
          artist: 'Artist',
          album: 'Album',
          duration: const Duration(minutes: 3),
          uri: 'assets/audio/test.mp3',
          quality: const AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
        ),
      );
      final recentItems = [
        RecentlyPlayedItem(
          id: 'album_Album',
          type: RecentItemType.album,
          title: 'Album',
          subtitle: 'Retro',
          playedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => MockLibraryNotifierWithSongs(manySongs)),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const LibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down
      await tester.drag(find.text('Track 0'), const Offset(0, -400));
      await tester.pumpAndSettle();

      // In SONGS tab, pinned toolbar shows SONGS tools
      expect(find.text('SEARCH TRACKS'), findsOneWidget);

      // Switch to ALBUMS tab while scrolled
      await tester.tap(find.text('ALBUMS'));
      await tester.pumpAndSettle();

      // TabBar is pinned and ALBUMS toolbar is pinned
      expect(find.text('ALBUMS'), findsOneWidget);
      expect(find.text('SEARCH ALBUMS'), findsOneWidget);

      // Switch to ARTISTS tab while scrolled
      await tester.tap(find.text('ARTISTS'));
      await tester.pumpAndSettle();

      // ARTISTS toolbar is pinned
      expect(find.text('SEARCH ARTISTS'), findsOneWidget);

      // Switch to FOLDERS tab while scrolled
      await tester.tap(find.text('FOLDERS'));
      await tester.pumpAndSettle();

      // FOLDERS toolbar is pinned
      expect(find.text('SEARCH FOLDERS'), findsOneWidget);
    });

    testWidgets('Opening playlist from recents renders exactly one MiniPlayer', (tester) async {
      final playlist = Playlist(
        id: 'p_breeze',
        name: 'Breeze',
        songIds: ['s1'],
        createdAt: DateTime.now(),
      );
      final recentItems = [
        RecentlyPlayedItem(
          id: 'playlist_p_breeze',
          type: RecentItemType.playlist,
          title: 'Breeze',
          subtitle: 'Playlist',
          playedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(() => MockPlaylistNotifierWithCustomPlaylists([playlist])),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Recent playlist tile is rendered in Library screen
      expect(find.text('Breeze'), findsOneWidget);

      // Verify we start on LIBRARY tab (index 0)
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, equals(0));

      // Tap the recent playlist tile
      await tester.tap(find.text('Breeze'));
      await tester.pumpAndSettle();

      // Navigation switched to PLAYLISTS tab (index 1) and opened playlist
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, equals(1));
      expect(find.byType(PlaylistDetailScreen), findsOneWidget);
      expect(find.text('PLAY ALL'), findsOneWidget);

      // CRITICAL ASSERTION: There MUST be EXACTLY ONE MiniPlayer, NEVER duplicates!
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Tapping back button on playlist screen returns to playlists list view
      final backButton = find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.icon is RetroIcon && (widget.icon as RetroIcon).iconName == 'arrow_left',
      );
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Now at Playlists screen root, still on PLAYLISTS tab (index 1)
      expect(find.text('MY PLAYLISTS (1)'), findsOneWidget);
      expect(tester.widget<BottomNavigationBar>(find.byType(BottomNavigationBar)).currentIndex, equals(1));
    });

    testWidgets('Playlist in recents without custom photo uses song cover art as photo', (tester) async {
      const songWithArt = Song(
        id: 's_art_1',
        title: 'Song With Art',
        artist: 'Artist',
        album: 'Album',
        duration: Duration(seconds: 180),
        uri: 'song.mp3',
        artPath: 'assets/images/retro_cover.png',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      final playlist = Playlist(
        id: 'p_art',
        name: 'Art Playlist',
        songIds: ['s_art_1'],
        createdAt: DateTime.now(),
      );
      final recentItems = [
        RecentlyPlayedItem(
          id: 'p_art',
          type: RecentItemType.playlist,
          title: 'Art Playlist',
          subtitle: 'Playlist',
          artUri: null, // No custom photo
          playedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(
              () => MockLibraryWithCustomState(
                const LibraryState(
                  allSongs: [songWithArt],
                  isLoading: false,
                ),
              ),
            ),
            playlistProvider.overrideWith(() => MockPlaylistNotifierWithCustomPlaylists([playlist])),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier(recentItems)),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
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

      // Find RetroAlbumArt for the playlist tile
      final albumArtFinder = find.byWidgetPredicate(
        (w) => w is RetroAlbumArt && w.artPath == 'assets/images/retro_cover.png',
      );
      expect(albumArtFinder, findsOneWidget);
    });

    testWidgets('Back press in search, playlist or settings navigates back to library and exits directly without toast', (tester) async {
      final List<MethodCall> methodCalls = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          methodCalls.add(call);
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.retro.mymusic/app_control'),
        (call) async {
          methodCalls.add(call);
          return true;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('com.retro.mymusic/app_control'),
          null,
        );
      });

      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(MockLibraryNotifier.new),
          playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
          playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
          themeProvider.overrideWith(MockThemeNotifier.new),
          settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to SEARCH tab (index 2)
      await tester.tap(find.text('SEARCH'));
      await tester.pumpAndSettle();
      expect(container.read(homeTabProvider), equals(2));

      // Navigate to PLAYLISTS tab (index 1)
      await tester.tap(find.text('PLAYLISTS'));
      await tester.pumpAndSettle();
      expect(container.read(homeTabProvider), equals(1));

      // First back press pops back to Search (index 2)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(container.read(homeTabProvider), equals(2));

      // Second back press from Search pops back to Library (index 0)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(container.read(homeTabProvider), equals(0));

      // Third back press on Library root exits the app directly without any toast
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // RetroToast is NOT displayed
      expect(find.text('PRESS BACK AGAIN TO EXIT'), findsNothing);

      // App exit triggered
      expect(
        methodCalls.any((c) => c.method == 'exitToHome' || c.method == 'SystemNavigator.pop'),
        isTrue,
      );
    });

    testWidgets('Back press inside detail screen pops detail and does NOT trigger exit toast', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const HomeScaffold(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Navigate to ALBUMS tab and open album
      await tester.tap(find.text('ALBUMS'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(RetroCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(AlbumDetailScreen), findsOneWidget);

      // System back press
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // AlbumDetailScreen is dismissed, returning to albums tab
      expect(find.byType(AlbumDetailScreen), findsNothing);

      // Exit toast MUST NOT be shown
      expect(find.text('PRESS BACK AGAIN TO EXIT'), findsNothing);
    });

    testWidgets('NowPlayingScreen renders three-dot dropdown menu with required options and handles navigation', (tester) async {
      final container = ProviderContainer(
        overrides: [
          libraryProvider.overrideWith(MockLibraryNotifier.new),
          playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
          playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
          themeProvider.overrideWith(MockThemeNotifier.new),
          equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: NowPlayingScreen(isDrawer: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Three-dot menu button is present in NowPlayingScreen
      final moreBtn = find.byKey(const ValueKey('now_playing_more_menu'));
      expect(moreBtn, findsOneWidget);

      // Open the dropdown menu
      await tester.tap(moreBtn);
      await tester.pumpAndSettle();

      // All 4 required options are rendered
      expect(find.text('ADD TO QUEUE'), findsOneWidget);
      expect(find.text('ADD TO PLAYLIST'), findsOneWidget);
      expect(find.text('GO TO ALBUM'), findsOneWidget);
      expect(find.text('GO TO ARTIST'), findsOneWidget);

      // Tap GO TO ALBUM and verify it navigates without creating a separate full screen
      await tester.tap(find.text('GO TO ALBUM'));
      await tester.pumpAndSettle();
      expect(container.read(homeTabProvider), equals(0));
      expect(find.byType(AlbumDetailScreen), findsNothing);
    });

    testWidgets('PlaylistsScreen updates track count on playlist card when song is removed from local storage', (tester) async {
      final mockSettings = MockSettingsRepository();
      const song1 = Song(
        id: 's1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 120),
        uri: '/path/1',
        quality: AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 150),
        uri: '/path/2',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      final playlistWithTwoSongs = Playlist(
        id: 'pl_custom',
        name: 'My Playlist',
        songIds: ['s1', 's2'],
        createdAt: DateTime.now(),
      );

      final libraryNotifier = MockLibraryNotifierWithSongs([song1, song2]);
      final playlistNotifier = MockPlaylistNotifierWithCustomPlaylists([playlistWithTwoSongs]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(() => libraryNotifier),
            playlistProvider.overrideWith(() => playlistNotifier),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
            themeProvider.overrideWith(MockThemeNotifier.new),
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            equalizerProvider.overrideWith(MockEqualizerNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: PlaylistsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially both songs exist in storage, so playlist card badge says '2 SONGS'
      expect(find.text('2 SONGS'), findsOneWidget);
      expect(find.text('1 SONGS'), findsNothing);

      // Now simulate removing song2 from local storage
      libraryNotifier.setSongs([song1]);
      await tester.pumpAndSettle();

      // Playlist card badge count must immediately update to '1 SONGS'
      expect(find.text('1 SONGS'), findsOneWidget);
      expect(find.text('2 SONGS'), findsNothing);
    });

    testWidgets('QueueSheet displays SHUFFLE toggle button and toggles shuffle mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(MockPlayerNotifierWithQueue.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const Scaffold(
              body: QueueSheet(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SHUFFLE button is rendered in the header
      expect(find.text('SHUFFLE'), findsOneWidget);

          // Tap SHUFFLE button
      await tester.tap(find.text('SHUFFLE'));
      await tester.pumpAndSettle();

      // Label switches to SHUFFLE ON
      expect(find.text('SHUFFLE ON'), findsOneWidget);
    });

    testWidgets('OnboardingScreen renders 6 stages, navigates forward/backward, and finishes with PRESS START', (tester) async {
      final mockSettings = MockSettingsRepository(onboardingCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Stage 1
      expect(find.text('8-BIT RETRO AUDIO'), findsOneWidget);
      expect(find.text('STAGE 1/6'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('SKIP'), findsOneWidget);

      // Tap NEXT to go to Stage 2
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Stage 2
      expect(find.text('DEEP LOCAL SCANNING'), findsOneWidget);
      expect(find.text('STAGE 2/6'), findsOneWidget);
      expect(find.text('PREV'), findsOneWidget);

      // Tap PREV to return to Stage 1
      await tester.tap(find.text('PREV'));
      await tester.pumpAndSettle();
      expect(find.text('8-BIT RETRO AUDIO'), findsOneWidget);

      // Advance through to Stage 3
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('VINYL & SYNCED LYRICS'), findsOneWidget);
      expect(find.text('STAGE 3/6'), findsOneWidget);

      // Advance through to Stage 4
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('SMART QUEUE & THEMES'), findsOneWidget);
      expect(find.text('STAGE 4/6'), findsOneWidget);

      // Advance to Stage 5: Audio Source Setup
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('SELECT MUSIC SOURCE'), findsOneWidget);
      expect(find.text('STAGE 5/6'), findsOneWidget);
      expect(find.text('FETCH ALL AUDIO & MUSIC'), findsOneWidget);
      expect(find.text('SELECT SPECIFIC FOLDER'), findsOneWidget);

      // Advance to Stage 6: Lyrics Setup
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      expect(find.text('SELECT LYRICS FOLDER'), findsOneWidget);
      expect(find.text('STAGE 6/6'), findsOneWidget);
      expect(find.text('PRESS START'), findsOneWidget);

      // Pressing start completes onboarding
      await tester.tap(find.text('PRESS START'));
      await tester.pumpAndSettle();
      expect(mockSettings.isOnboardingCompleted(), isTrue);
    });

    testWidgets('OnboardingScreen Stage 5: toggling Fetch All Audio shows confirmation box and handles cancel/confirm', (tester) async {
      final mockSettings = MockSettingsRepository(onboardingCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Stage 5
      for (int i = 0; i < 4; i++) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }
      expect(find.text('SELECT MUSIC SOURCE'), findsOneWidget);
      expect(find.text('STAGE 5/6'), findsOneWidget);

      // Find switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      // Tap switch to turn ON -> Confirmation dialog should appear
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(find.text('CONFIRM FULL SCAN'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('YES, FETCH ALL'), findsOneWidget);

      // Tap CANCEL -> Dialog closes and fetch all stays false
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM FULL SCAN'), findsNothing);
      expect(mockSettings.isFetchAllAudio(), isFalse);

      // Tap switch again to turn ON -> Confirmation dialog
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM FULL SCAN'), findsOneWidget);

      // Tap YES, FETCH ALL -> Confirms and enables
      await tester.tap(find.text('YES, FETCH ALL'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM FULL SCAN'), findsNothing);
      expect(mockSettings.isFetchAllAudio(), isTrue);
    });

    testWidgets('OnboardingScreen SKIP immediately completes onboarding', (tester) async {
      final mockSettings = MockSettingsRepository(onboardingCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(mockSettings.isOnboardingCompleted(), isFalse);
      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();
      expect(mockSettings.isOnboardingCompleted(), isTrue);
    });

    testWidgets('OnboardingScreen Stage 6: displays lyrics setup with CHOOSE LRC FOLDER and default indicator', (tester) async {
      final mockSettings = MockSettingsRepository(onboardingCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigate to Stage 6
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
      }

      expect(find.text('SELECT LYRICS FOLDER'), findsOneWidget);
      expect(find.text('STAGE 6/6'), findsOneWidget);
      expect(find.text('CHOOSE LRC FOLDER'), findsOneWidget);
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('PRESS START'), findsOneWidget);
    });

    testWidgets('SettingsScreen renders Fetch All Audio toggle and confirmation dialog', (tester) async {
      final mockSettings = MockSettingsRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleLabel = find.text('FETCH ALL AUDIO & MUSIC');
      await tester.scrollUntilVisible(toggleLabel, 300);
      expect(toggleLabel, findsOneWidget);

      // Find Switch
      final switchFinder = find.descendant(
        of: find.ancestor(of: toggleLabel, matching: find.byType(Container)).first,
        matching: find.byType(Switch),
      );
      expect(switchFinder, findsOneWidget);
      await tester.ensureVisible(switchFinder);
      await tester.pumpAndSettle();

      // Tap switch -> confirmation dialog appears
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM FULL SCAN'), findsOneWidget);

      // Cancel
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM FULL SCAN'), findsNothing);
      expect(mockSettings.isFetchAllAudio(), isFalse);

      // Tap switch again and confirm
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('YES, FETCH ALL'));
      await tester.pumpAndSettle();
      expect(find.text('CONFIRM FULL SCAN'), findsNothing);
      expect(mockSettings.isFetchAllAudio(), isTrue);
    });

    testWidgets('SettingsScreen renders VIEW FEATURE TOUR button and navigates to onboarding tour', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to About section
      final tourFinder = find.text('VIEW FEATURE TOUR');
      await tester.scrollUntilVisible(tourFinder, 300);
      expect(tourFinder, findsOneWidget);
      await tester.ensureVisible(tourFinder);
      await tester.pumpAndSettle();

      await tester.tap(tourFinder);
      await tester.pumpAndSettle();

      // Onboarding screen is opened
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text('STAGE 1/6'), findsOneWidget);
    });

    testWidgets('RetroMusicApp displays OnboardingScreen on first launch and HomeScaffold after completion', (tester) async {
      final mockSettings = MockSettingsRepository(onboardingCompleted: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsRepositoryProvider.overrideWithValue(mockSettings),
            themeProvider.overrideWith(MockThemeNotifier.new),
            libraryProvider.overrideWith(MockLibraryNotifier.new),
            playlistProvider.overrideWith(MockPlaylistNotifierWithData.new),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
          ],
          child: const RetroMusicApp(),
        ),
      );
      await tester.pumpAndSettle();

      // First launch shows OnboardingScreen, not HomeScaffold
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(HomeScaffold), findsNothing);

      // Complete onboarding via SKIP
      await tester.tap(find.text('SKIP'));
      await tester.pumpAndSettle();

      // Now HomeScaffold is displayed
      expect(find.byType(HomeScaffold), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(mockSettings.isOnboardingCompleted(), isTrue);
    });

    testWidgets('LibraryScreen displays retro loading state when fetching songs from storage', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            libraryProvider.overrideWith(MockLibraryNotifierLoading.new),
            settingsRepositoryProvider.overrideWithValue(MockSettingsRepository()),
            themeProvider.overrideWith(MockThemeNotifier.new),
            recentlyPlayedProvider.overrideWith(() => MockRecentlyPlayedNotifier([])),
            playerProvider.overrideWith(MockPlayerNotifierWithSong.new),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const LibraryScreen(),
          ),
        ),
      );
      await tester.pump();

      // Verify retro loading state is displayed with scanning text
      expect(find.byType(RetroLoadingState), findsOneWidget);
      expect(find.text('FETCHING FROM STORAGE...'), findsOneWidget);
      expect(find.text('SCANNING AUDIO FILES & EXTRACTING METADATA'), findsOneWidget);
      expect(find.text('LOADING LIBRARY'), findsOneWidget);
    });
  });
}

class MockLibraryNotifierLoading extends LibraryNotifier {
  @override
  LibraryState build() {
    return const LibraryState(
      allSongs: [],
      albums: [],
      artists: [],
      folders: {},
      isLoading: true,
    );
  }
}

class MockLibraryNotifier extends LibraryNotifier {
  int autoScanCallCount = 0;
  int loadLibraryCallCount = 0;

  @override
  LibraryState build() {
    final song = Song(
      id: 's1',
      title: 'Chiptune',
      artist: 'Retro',
      album: 'Album',
      duration: const Duration(seconds: 30),
      uri: 'assets/audio/chiptune_quest.wav',
      quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
      isFavorite: true,
    );
    final album = Album(
      title: 'Album',
      artist: 'Retro',
      songs: [song],
    );
    final artist = Artist(
      name: 'Retro',
      songs: [song],
    );
    return LibraryState(
      allSongs: [song],
      albums: [album],
      artists: [artist],
      folders: {
        '/Music/Retro': [song],
      },
      isLoading: false,
    );
  }

  @override
  Future<void> loadLibrary() async {
    loadLibraryCallCount++;
  }

  @override
  Future<int> rescanSelectedFolders() async {
    loadLibraryCallCount++;
    return state.allSongs.length;
  }

  @override
  Future<({int totalCount, int newCount})> rescanLibrary() async {
    loadLibraryCallCount++;
    return (totalCount: state.allSongs.length, newCount: 0);
  }

  @override
  Future<int> autoScanDevice() async {
    autoScanCallCount++;
    return state.allSongs.length;
  }

  @override
  Future<void> toggleFavorite(String songId) async {
    final updatedSongs = state.allSongs.map((s) {
      if (s.id == songId) {
        return s.copyWith(isFavorite: !s.isFavorite);
      }
      return s;
    }).toList();
    state = state.copyWith(allSongs: updatedSongs);
  }
}

class MockPlaylistNotifier extends PlaylistNotifier {
  @override
  PlaylistState build() {
    return const PlaylistState(isLoading: false);
  }
}

class MockLibraryNotifierWithSongs extends LibraryNotifier {
  final List<Song> customSongs;

  MockLibraryNotifierWithSongs(this.customSongs);

  @override
  LibraryState build() {
    return LibraryState(
      allSongs: customSongs,
      albums: [],
      artists: [],
      folders: {},
      isLoading: false,
    );
  }

  @override
  Future<void> loadLibrary() async {}

  void setSongs(List<Song> songs) {
    state = state.copyWith(allSongs: songs);
  }
}

class MockPlaylistNotifierWithData extends PlaylistNotifier {
  @override
  PlaylistState build() {
    return PlaylistState(
      playlists: [
        Playlist(
          id: 'p1',
          name: 'Retro Hits',
          songIds: ['s1'],
          createdAt: DateTime.now(),
        ),
      ],
      isLoading: false,
    );
  }
}

class MockPlayerNotifierWithSong extends PlayerNotifier {
  @override
  PlayerStateModel build() {
    final song = Song(
      id: 's1',
      title: 'Chiptune',
      artist: 'Retro',
      album: 'Album',
      duration: const Duration(seconds: 30),
      uri: 'assets/audio/chiptune_quest.wav',
      quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
      isFavorite: true,
    );
    return PlayerStateModel(
      currentSong: song,
      isPlaying: true,
      duration: const Duration(seconds: 30),
      position: const Duration(seconds: 10),
    );
  }
}

class MockPlayerNotifierWithCustomSong extends PlayerNotifier {
  Song _song = const Song(
    id: 's1',
    title: 'A',
    artist: 'Retro',
    album: 'Album',
    duration: Duration(seconds: 30),
    uri: 'assets/audio/test.wav',
    quality: AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
  );

  @override
  PlayerStateModel build() {
    return PlayerStateModel(
      currentSong: _song,
      isPlaying: true,
      duration: const Duration(seconds: 30),
      position: const Duration(seconds: 10),
    );
  }

  void updateSong(Song song) {
    _song = song;
    state = state.copyWith(currentSong: song);
  }

  @override
  Future<void> toggleLoop() async {
    final next = switch (state.loopMode) {
      RetroLoopMode.off => RetroLoopMode.all,
      RetroLoopMode.all => RetroLoopMode.one,
      RetroLoopMode.one => RetroLoopMode.off,
    };
    state = state.copyWith(loopMode: next);
  }
}

class MockPlayerNotifierWithQueue extends PlayerNotifier {
  @override
  PlayerStateModel build() {
    final song1 = Song(
      id: 's1',
      title: 'Chiptune 1',
      artist: 'Retro',
      album: 'Album',
      duration: const Duration(seconds: 30),
      uri: 'assets/audio/chiptune_quest.wav',
      quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
    );
    final song2 = Song(
      id: 's2',
      title: 'Chiptune 2',
      artist: 'Retro',
      album: 'Album',
      duration: const Duration(seconds: 45),
      uri: 'assets/audio/neon_pixels.wav',
      quality: const AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
    );
    return PlayerStateModel(
      currentSong: song1,
      isPlaying: true,
      queue: [song1, song2],
      currentIndex: 0,
      duration: const Duration(seconds: 30),
      position: const Duration(seconds: 10),
    );
  }

  @override
  Future<void> toggleShuffle() async {
    state = state.copyWith(isShuffle: !state.isShuffle);
  }
}

class MockThemeNotifier extends ThemeNotifier {
  final bool initialDark;
  MockThemeNotifier({this.initialDark = false});

  @override
  bool build() => initialDark;
}

class MockSettingsRepository extends SettingsRepository {
  bool _onboardingCompleted = true;
  bool _isDarkMode = false;

  MockSettingsRepository({bool? onboardingCompleted, bool isDarkMode = false}) {
    if (onboardingCompleted != null) {
      _onboardingCompleted = onboardingCompleted;
    }
    _isDarkMode = isDarkMode;
  }

  @override
  bool isOnboardingCompleted() => _onboardingCompleted;

  @override
  Future<void> setOnboardingCompleted(bool completed) async {
    _onboardingCompleted = completed;
  }

  @override
  bool isDarkMode() => _isDarkMode;

  @override
  Future<void> setDarkMode(bool isDark) async {
    _isDarkMode = isDark;
  }

  String _darkPalette = 'warm_espresso';
  String _lightPalette = 'vintage_handheld';

  @override
  String getDarkPalette() => _darkPalette;

  @override
  Future<void> setDarkPalette(String id) async {
    _darkPalette = id;
  }

  @override
  String getLightPalette() => _lightPalette;

  @override
  Future<void> setLightPalette(String id) async {
    _lightPalette = id;
  }

  bool _fetchAllAudio = false;
  final List<String> _scanFolders = [];

  @override
  bool isFetchAllAudio() => _fetchAllAudio;

  @override
  Future<void> setFetchAllAudio(bool enabled) async {
    _fetchAllAudio = enabled;
  }

  @override
  List<String> getScanFolders() => _scanFolders;

  @override
  Future<void> addScanFolder(String folder) async {
    if (!_scanFolders.contains(folder)) {
      _scanFolders.add(folder);
    }
  }

  @override
  Future<void> removeScanFolder(String folder) async {
    _scanFolders.remove(folder);
  }

  @override
  bool isEqualizerEnabled() => false;

  @override
  String getEqualizerPreset() => 'FLAT';

  @override
  List<double> getEqualizerBands() => [0, 0, 0, 0, 0];

  bool _isGrid = false;
  @override
  bool isPlaylistGridView() => _isGrid;

  @override
  Future<void> setPlaylistGridView(bool isGrid) async {
    _isGrid = isGrid;
  }

  bool _albumGrid = true;
  @override
  bool isAlbumGridView() => _albumGrid;

  @override
  Future<void> setAlbumGridView(bool isGrid) async {
    _albumGrid = isGrid;
  }

  bool _artistGrid = false;
  @override
  bool isArtistGridView() => _artistGrid;

  @override
  Future<void> setArtistGridView(bool isGrid) async {
    _artistGrid = isGrid;
  }

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

  bool _onlineLyricsEnabled = true;
  String? _localLrcFolderPath;
  bool _prioritizeSyllableLyrics = false;
  List<String> _enabledLyricSources = ['LRCLIB', 'Musixmatch'];

  @override
  bool isOnlineLyricsEnabled() => _onlineLyricsEnabled;

  @override
  Future<void> setOnlineLyricsEnabled(bool enabled) async {
    _onlineLyricsEnabled = enabled;
  }

  @override
  String? getLocalLrcFolderPath() => _localLrcFolderPath;

  @override
  Future<void> setLocalLrcFolderPath(String? path) async {
    _localLrcFolderPath = path;
  }

  @override
  bool isPrioritizeSyllableLyrics() => _prioritizeSyllableLyrics;

  @override
  Future<void> setPrioritizeSyllableLyrics(bool prioritize) async {
    _prioritizeSyllableLyrics = prioritize;
  }

  @override
  List<String> getEnabledLyricSources() => _enabledLyricSources;

  @override
  Future<void> setEnabledLyricSources(List<String> sources) async {
    _enabledLyricSources = sources;
  }

  bool _spatialAudioEnabled = false;
  int _spatialAudioStrength = 1000;
  String _spatialAudioMode = 'binaural';
  String _spatialReverbPreset = 'DOLBY ATMOS CINEMA';

  @override
  bool isSpatialAudioEnabled({bool defaultValue = false}) => _spatialAudioEnabled;

  @override
  Future<void> setSpatialAudioEnabled(bool enabled) async {
    _spatialAudioEnabled = enabled;
  }

  @override
  int getSpatialAudioStrength({int defaultValue = 1000}) => _spatialAudioStrength;

  @override
  Future<void> setSpatialAudioStrength(int strength) async {
    _spatialAudioStrength = strength;
  }

  @override
  String getSpatialAudioMode({String defaultValue = 'binaural'}) => _spatialAudioMode;

  @override
  Future<void> setSpatialAudioMode(String mode) async {
    _spatialAudioMode = mode;
  }

  @override
  String getSpatialReverbPreset({String defaultValue = 'studio'}) => _spatialReverbPreset;

  @override
  Future<void> setSpatialReverbPreset(String preset) async {
    _spatialReverbPreset = preset;
  }

  String _appFont = 'PressStart2P';

  @override
  String getAppFont() => _appFont;

  @override
  Future<void> setAppFont(String fontId) async {
    _appFont = fontId;
  }
}


class MockLibraryWithCustomState extends LibraryNotifier {
  final LibraryState customState;
  MockLibraryWithCustomState(this.customState);

  @override
  LibraryState build() => customState;
}

class MockEqualizerNotifier extends EqualizerNotifier {
  @override
  EqualizerState build() => const EqualizerState();
}

class MockPlayerNotifierForPreferences extends PlayerNotifier {
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
    if (forceShuffle != null) {
      storage.savePlaylistPlaybackSettings(
        playlistId,
        isShuffle: targetShuffle,
        loopMode: savedLoop.name,
      );
    }

    state = state.copyWith(
      currentPlaylistId: playlistId,
      isShuffle: targetShuffle,
      loopMode: savedLoop,
      queue: songs,
    );
  }

  @override
  Future<void> toggleShuffle() async {
    final newShuffle = !state.isShuffle;
    state = state.copyWith(isShuffle: newShuffle);
    if (state.currentPlaylistId != null) {
      StorageService().savePlaylistPlaybackSettings(
        state.currentPlaylistId!,
        isShuffle: newShuffle,
        loopMode: state.loopMode.name,
      );
    }
  }
}

class MockPlaylistNotifierWithManyPlaylists extends PlaylistNotifier {
  @override
  PlaylistState build() {
    return PlaylistState(
      playlists: List.generate(
        20,
        (i) => Playlist(
          id: 'p_$i',
          name: 'Retro Playlist #$i',
          songIds: ['s1'],
          createdAt: DateTime.now(),
        ),
      ),
      isLoading: false,
    );
  }
}

class MockRecentlyPlayedNotifier extends RecentlyPlayedNotifier {
  final List<RecentlyPlayedItem> initialItems;
  MockRecentlyPlayedNotifier([this.initialItems = const []]);

  @override
  List<RecentlyPlayedItem> build() => initialItems;
}

class MockPlaylistNotifierWithCustomPlaylists extends PlaylistNotifier {
  final List<Playlist> customPlaylists;
  MockPlaylistNotifierWithCustomPlaylists(this.customPlaylists);

  @override
  PlaylistState build() {
    return PlaylistState(
      playlists: customPlaylists,
      isLoading: false,
    );
  }
}

class MockCustomLyricsForWidgetTest extends LyricsNotifier {
  final LyricsState custom;
  MockCustomLyricsForWidgetTest(this.custom);

  @override
  LyricsState build() => custom;
}
