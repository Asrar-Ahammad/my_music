import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/playlist.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/screens/playlists/playlist_detail_screen.dart';
import 'package:my_music/presentation/widgets/retro_scroll_thumb.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testSongs = [
    const Song(
      id: 'song_1',
      title: 'Zebra Song',
      artist: 'Charlie Artist',
      album: 'Zoo Album',
      duration: Duration(seconds: 180),
      uri: 'file:///zebra.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    ),
    const Song(
      id: 'song_2',
      title: 'Alpha Song',
      artist: 'Bob Artist',
      album: 'Beginning Album',
      duration: Duration(seconds: 120),
      uri: 'file:///alpha.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    ),
    const Song(
      id: 'song_3',
      title: 'Middle Song',
      artist: 'Alice Artist',
      album: 'Middle Album',
      duration: Duration(seconds: 240),
      uri: 'file:///middle.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
    ),
  ];

  final testPlaylist = Playlist(
    id: 'p1',
    name: 'My Retro Playlist',
    songIds: ['song_2'], // song_2 is already in playlist
    createdAt: DateTime.now(),
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        libraryProvider.overrideWith(
          () => _MockLibraryNotifier(
            LibraryState(allSongs: testSongs, isLoading: false),
          ),
        ),
        playlistProvider.overrideWith(
          () => _MockPlaylistNotifier([testPlaylist]),
        ),
      ],
      child: MaterialApp(
        theme: RetroTheme.darkTheme(),
        home: Scaffold(
          body: PlaylistDetailScreen(
            playlist: testPlaylist,
          ),
        ),
      ),
    );
  }

  testWidgets('Add Songs Sheet displays retro handle, top border, filter chips, and sort menu', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createTestWidget());
    await tester.pumpAndSettle();

    // Tap "ADD MORE SONGS"
    final addMoreBtn = find.text('ADD MORE SONGS');
    expect(addMoreBtn, findsOneWidget);
    await tester.tap(addMoreBtn);
    await tester.pumpAndSettle();

    // Verify Add Songs Sheet opened
    expect(find.text('ADD SONGS'), findsOneWidget);
    expect(find.text('TO: MY RETRO PLAYLIST'), findsOneWidget);

    // Verify sheet has top, left, and right retro borders
    final sheetContainer = tester.widget<Container>(
      find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Container),
      ).first,
    );
    final decoration = sheetContainer.decoration as BoxDecoration;
    final border = decoration.border as Border;
    expect(border.top.width, greaterThan(0));
    expect(border.left.width, greaterThan(0));
    expect(border.right.width, greaterThan(0));

    // Verify filter chips exist
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('UNADDED'), findsOneWidget);
    expect(find.text('IN LIST'), findsOneWidget);

    // Verify sort controls exist
    expect(find.text('▲'), findsWidgets);
    expect(find.text('▼'), findsWidgets);

    final sheetFinder = find.byType(DraggableScrollableSheet);
    Finder inSheet(String text) => find.descendant(of: sheetFinder, matching: find.text(text));

    // Verify by default sorted by Title Ascending: Alpha Song, Middle Song, Zebra Song
    expect(inSheet('Alpha Song'), findsOneWidget);
    expect(inSheet('Middle Song'), findsOneWidget);
    expect(inSheet('Zebra Song'), findsOneWidget);

    // Filter by UNADDED (song_1 and song_3 only)
    await tester.tap(inSheet('UNADDED'));
    await tester.pumpAndSettle();

    expect(inSheet('Zebra Song'), findsOneWidget);
    expect(inSheet('Middle Song'), findsOneWidget);
    expect(inSheet('Alpha Song'), findsNothing); // already in playlist, so filtered out

    // Filter by IN LIST (song_2 only)
    await tester.tap(inSheet('IN LIST'));
    await tester.pumpAndSettle();

    expect(inSheet('Alpha Song'), findsOneWidget);
    expect(inSheet('Zebra Song'), findsNothing);
    expect(inSheet('Middle Song'), findsNothing);

    // Reset back to ALL
    await tester.tap(inSheet('ALL'));
    await tester.pumpAndSettle();
    expect(inSheet('Alpha Song'), findsOneWidget);
    expect(inSheet('Middle Song'), findsOneWidget);
    expect(inSheet('Zebra Song'), findsOneWidget);

    // Toggle descending sort by tapping '▼'
    final descButtons = find.descendant(of: sheetFinder, matching: find.text('▼'));
    await tester.tap(descButtons.first);
    await tester.pumpAndSettle();

    // Verify RetroScrollThumb exists in sheet
    expect(find.descendant(of: sheetFinder, matching: find.byType(RetroScrollThumb)), findsOneWidget);
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

  @override
  Future<void> addSongsToPlaylist(String playlistId, List<String> songIds) async {}
}
