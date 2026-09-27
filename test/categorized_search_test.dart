import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/domain/models/ai_song_tags.dart';
import 'package:my_music/domain/models/album.dart';
import 'package:my_music/domain/models/artist.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/playlist.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/library_tagger_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/providers/playlist_provider.dart';
import 'package:my_music/presentation/screens/library/album_detail_screen.dart';
import 'package:my_music/presentation/screens/search/category_detail_screen.dart';
import 'package:my_music/presentation/screens/search/search_screen.dart';
import 'package:my_music/presentation/widgets/retro_song_tile.dart';

const _songA = Song(
  id: 'song_a',
  title: 'Arcade Adventure',
  artist: 'Retro Master',
  album: 'Cyber Zone',
  duration: Duration(seconds: 180),
  uri: 'assets/audio/arcade.wav',
  quality: AudioQuality(format: 'FLAC', bitDepth: 24, sampleRate: 96000),
);

const _songB = Song(
  id: 'song_b',
  title: 'Neon Nights',
  artist: 'Synth Wave',
  album: 'Neon Lights',
  duration: Duration(seconds: 210),
  uri: 'assets/audio/neon.wav',
  quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
);

final _albumA = Album(
  title: 'Cyber Zone',
  artist: 'Retro Master',
  songs: const [_songA],
);

final _albumB = Album(
  title: 'Neon Lights',
  artist: 'Synth Wave',
  songs: const [_songB],
);

final _artistA = Artist(
  name: 'Retro Master',
  songs: const [_songA],
);

final _artistB = Artist(
  name: 'Synth Wave',
  songs: const [_songB],
);

final _playlistA = Playlist(
  id: 'pl_1',
  name: 'Cyber Hits',
  songIds: const ['song_a'],
  createdAt: DateTime(2026, 1, 1),
);

final _playlistB = Playlist(
  id: 'pl_2',
  name: 'Chill Vibes',
  songIds: const ['song_b'],
  createdAt: DateTime(2026, 1, 2),
);

class MockLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() {
    return LibraryState(
      allSongs: const [_songA, _songB],
      albums: [_albumA, _albumB],
      artists: [_artistA, _artistB],
      isLoading: false,
    );
  }
}

class MockPlaylistNotifier extends PlaylistNotifier {
  @override
  PlaylistState build() {
    return PlaylistState(
      playlists: [_playlistA, _playlistB],
      isLoading: false,
    );
  }
}

class MockPlayerNotifier extends PlayerNotifier {
  @override
  PlayerStateModel build() {
    return const PlayerStateModel(
      currentSong: _songA,
      isPlaying: false,
      queue: [_songA, _songB],
    );
  }
}

class MockLibraryTaggerNotifier extends LibraryTaggerNotifier {
  final Map<String, AiSongTags> initialTags;
  MockLibraryTaggerNotifier({this.initialTags = const {}});

  @override
  LibraryTaggerState build() {
    return LibraryTaggerState(
      taggedSongs: initialTags,
      isComplete: initialTags.isNotEmpty,
    );
  }
}

Widget _buildSearchApp({Map<String, AiSongTags> taggedSongs = const {}}) {
  return ProviderScope(
    overrides: [
      libraryProvider.overrideWith(MockLibraryNotifier.new),
      playlistProvider.overrideWith(MockPlaylistNotifier.new),
      playerProvider.overrideWith(MockPlayerNotifier.new),
      libraryTaggerProvider.overrideWith(() => MockLibraryTaggerNotifier(initialTags: taggedSongs)),
    ],
    child: MaterialApp(
      theme: RetroTheme.darkTheme(),
      home: const SearchScreen(isActive: true),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Categorized Search Screen Tests', () {
    testWidgets('Empty query displays CATEGORIES cards and filter chips', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      expect(find.text('CATEGORIES'), findsOneWidget);
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('MOODS'), findsOneWidget);
      expect(find.text('GENRES'), findsOneWidget);
      expect(find.text('ENERGY'), findsOneWidget);

      // Standard preview cards when not tagged
      expect(find.text('CHILL'), findsOneWidget);
      expect(find.text('LO-FI'), findsOneWidget);
    });

    testWidgets('Tapping a category card opens CategoryDetailScreen with PLAY ALL and SHUFFLE PLAY', (tester) async {
      final tags = {
        'song_a': const AiSongTags(
          songId: 'song_a',
          mood: 'Chill',
          genre: 'Lo-Fi',
          energyLevel: 'Low',
        ),
      };

      await tester.pumpWidget(_buildSearchApp(taggedSongs: tags));
      await tester.pumpAndSettle();

      // Tap on CHILL category card
      await tester.tap(find.text('CHILL'));
      await tester.pumpAndSettle();

      // CategoryDetailScreen is displayed
      expect(find.byType(CategoryDetailScreen), findsOneWidget);
      expect(find.text('PLAY ALL'), findsOneWidget);
      expect(find.text('SHUFFLE PLAY'), findsOneWidget);
      expect(find.text('Arcade Adventure'), findsOneWidget);

      // Back navigation
      final backBtn = find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(IconButton),
      ).first;
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      expect(find.byType(CategoryDetailScreen), findsNothing);
      expect(find.text('CATEGORIES'), findsOneWidget);
    });

    testWidgets('When user searches, category chips appear with no count next to ALL', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      // Type search query
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Cyber');
      await tester.pumpAndSettle();

      // Category chips shown for active search
      expect(find.text('ALL'), findsOneWidget);
      expect(find.text('SONGS'), findsWidgets);
      expect(find.text('ALBUMS'), findsWidgets);
      expect(find.text('ARTISTS'), findsOneWidget);
      expect(find.text('PLAYLISTS'), findsWidgets);

      // Songs chip has count badge (1 match for Arcade Adventure)
      expect(find.text('1'), findsWidgets);

      // Matches are shown
      expect(find.text('Arcade Adventure'), findsOneWidget);
      expect(find.text('Cyber Zone'), findsWidgets);
      expect(find.text('CYBER HITS'), findsOneWidget);

      // Non matching should not appear
      expect(find.text('Neon Nights'), findsNothing);
    });

    testWidgets('Switching category tab to ALBUMS filters view to only albums', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      // Type query 'e' to activate search view matching both albums
      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'e');
      await tester.pumpAndSettle();

      // Tap ALBUMS tab chip
      await tester.tap(find.text('ALBUMS').first);
      await tester.pumpAndSettle();

      // Should show both albums
      expect(find.text('Cyber Zone'), findsOneWidget);
      expect(find.text('Neon Lights'), findsOneWidget);

      // Songs should not be listed as RetroSongTile
      expect(find.byType(RetroSongTile), findsNothing);
    });

    testWidgets('Switching category tab to ARTISTS filters view to only artists', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'e');
      await tester.pumpAndSettle();

      // Tap ARTISTS tab chip
      await tester.tap(find.text('ARTISTS').first);
      await tester.pumpAndSettle();

      expect(find.text('Retro Master'), findsOneWidget);
      expect(find.text('Synth Wave'), findsOneWidget);
    });

    testWidgets('Switching category tab to PLAYLISTS filters view to only playlists', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'e');
      await tester.pumpAndSettle();

      // Tap PLAYLISTS tab chip
      await tester.tap(find.text('PLAYLISTS').first);
      await tester.pumpAndSettle();

      expect(find.text('CYBER HITS'), findsOneWidget);
      expect(find.text('CHILL VIBES'), findsOneWidget);
    });

    testWidgets('Tapping SEE ALL on Albums section switches tab to ALBUMS', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'Cyber');
      await tester.pumpAndSettle();

      // Find the SEE ALL buttons
      final seeAllButtons = find.text('SEE ALL');
      expect(seeAllButtons, findsWidgets);

      // Tap the second SEE ALL button (Albums section)
      await tester.tap(seeAllButtons.at(1));
      await tester.pumpAndSettle();

      // Now we should be in ALBUMS category view
      expect(find.text('Cyber Zone'), findsOneWidget);
      expect(find.byType(RetroSongTile), findsNothing);
    });

    testWidgets('Tapping an album tile navigates to AlbumDetailScreen', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'e');
      await tester.pumpAndSettle();

      // Go to ALBUMS tab
      await tester.tap(find.text('ALBUMS').first);
      await tester.pumpAndSettle();

      // Tap album Cyber Zone
      await tester.tap(find.text('Cyber Zone'));
      await tester.pumpAndSettle();

      expect(find.byType(AlbumDetailScreen), findsOneWidget);
    });

    testWidgets('Search query with no matches shows retro empty state', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'NonExistentTermXYZ');
      await tester.pumpAndSettle();

      expect(find.textContaining('NO MATCHES FOUND'), findsOneWidget);
    });

    testWidgets('Dynamic quality filter chips appear in search and filter results on tap', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'e');
      await tester.pumpAndSettle();

      // In _testSongs: _songA is Hi-Res (24-bit 96k FLAC), _songB is MP3 44.1k standard/HQ
      expect(find.text('HI-RES'), findsOneWidget);

      // Tap HI-RES filter chip
      await tester.tap(find.text('HI-RES'));
      await tester.pumpAndSettle();

      // Only Arcade Adventure should appear in ALL view
      expect(find.text('Arcade Adventure'), findsOneWidget);
      expect(find.text('Neon Nights'), findsNothing);

      // Untoggle HI-RES
      await tester.tap(find.text('HI-RES'));
      await tester.pumpAndSettle();

      // Both should appear again
      expect(find.text('Arcade Adventure'), findsOneWidget);
      expect(find.text('Neon Nights'), findsOneWidget);
    });

    testWidgets('Search input does not have focus when navigating to search screen', (tester) async {
      await tester.pumpWidget(_buildSearchApp());
      await tester.pumpAndSettle();

      final searchField = tester.widget<TextField>(find.byType(TextField));
      expect(searchField.focusNode?.hasFocus ?? false, isFalse);
    });

    testWidgets('Tapping RE-SCAN button triggers library rescan', (tester) async {
      final tags = {
        'song_a': const AiSongTags(
          songId: 'song_a',
          mood: 'Chill',
          genre: 'Lo-Fi',
          energyLevel: 'Low',
        ),
      };

      await tester.pumpWidget(_buildSearchApp(taggedSongs: tags));
      await tester.pumpAndSettle();

      expect(find.text('RE-SCAN'), findsOneWidget);
      await tester.tap(find.text('RE-SCAN'));
      await tester.pump();

      expect(find.byType(SearchScreen), findsOneWidget);
    });
  });
}
