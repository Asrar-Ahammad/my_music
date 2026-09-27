import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/library_provider.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/screens/now_playing/queue_sheet.dart';
import 'package:my_music/presentation/widgets/retro_song_tile.dart';

class _MockPlayerNotifier extends PlayerNotifier {
  final Song? testSong;
  final List<Song> testQueue;
  _MockPlayerNotifier({this.testSong, this.testQueue = const []});

  @override
  PlayerStateModel build() => PlayerStateModel(
        currentSong: testSong,
        queue: testQueue,
        isPlaying: false,
      );
}

class _MockLibraryNotifier extends LibraryNotifier {
  @override
  LibraryState build() => const LibraryState();
}

Song _createTestSong(String id, String title) {
  return Song(
    id: id,
    title: title,
    artist: 'Artist',
    album: 'Album',
    duration: const Duration(seconds: 180),
    uri: '/path/$id.mp3',
    quality: const AudioQuality(format: 'FLAC', bitDepth: 24, sampleRate: 44100),
  );
}

void main() {
  testWidgets('RetroSongTile renders 2, 3, and 4-digit numbers on a single line without breaking', (tester) async {
    final song2 = _createTestSong('s99', 'Track 99');
    final song3 = _createTestSong('s100', 'Track 100');
    final song4 = _createTestSong('s1000', 'Track 1000');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(_MockPlayerNotifier.new),
          libraryProvider.overrideWith(_MockLibraryNotifier.new),
        ],
        child: MaterialApp(
          theme: RetroTheme.darkTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  // 2-digit index (98 -> "99")
                  RetroSongTile(
                    song: song2,
                    index: 98,
                    queue: [song2],
                  ),
                  // 3-digit index (99 -> "100")
                  RetroSongTile(
                    song: song3,
                    index: 99,
                    queue: [song3],
                  ),
                  // 4-digit index (999 -> "1000")
                  RetroSongTile(
                    song: song4,
                    index: 999,
                    queue: [song4],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify all 3 numbers are rendered
    expect(find.text('99'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
    expect(find.text('1000'), findsOneWidget);

    // Verify heights do NOT double (not wrapped to multiple lines)
    final renderBox99 = tester.renderObject(find.text('99')) as RenderBox;
    final renderBox100 = tester.renderObject(find.text('100')) as RenderBox;
    final renderBox1000 = tester.renderObject(find.text('1000')) as RenderBox;

    // Single line text height is around 11-16px, whereas multi-line wrapped text was 32px
    expect(renderBox99.size.height, lessThanOrEqualTo(16.0));
    expect(renderBox100.size.height, lessThanOrEqualTo(16.0));
    expect(renderBox1000.size.height, lessThanOrEqualTo(16.0));

    // Verify parent SizedBox widths accommodate 3-digit and 4-digit numbers
    final sizedBox100 = tester.widget<SizedBox>(
      find.ancestor(of: find.text('100'), matching: find.byType(SizedBox)).first,
    );
    expect(sizedBox100.width, equals(36.0));

    final sizedBox1000 = tester.widget<SizedBox>(
      find.ancestor(of: find.text('1000'), matching: find.byType(SizedBox)).first,
    );
    expect(sizedBox1000.width, equals(44.0));
  });

  testWidgets('RetroSongTile aligns column width when queue has >= 100 tracks (like 116 tracks in library)', (tester) async {
    // Generate 116 dummy songs
    final songs = List.generate(116, (i) => _createTestSong('s_$i', 'Track ${i + 1}'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(_MockPlayerNotifier.new),
          libraryProvider.overrideWith(_MockLibraryNotifier.new),
        ],
        child: MaterialApp(
          theme: RetroTheme.darkTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                // Track 99 (index 98)
                RetroSongTile(
                  song: songs[98],
                  index: 98,
                  queue: songs,
                ),
                // Track 100 (index 99)
                RetroSongTile(
                  song: songs[99],
                  index: 99,
                  queue: songs,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // In a 116 track list, both track 99 and track 100 should have uniform width 36
    // so that their album art thumbnails align vertically
    final sizedBox99 = tester.widget<SizedBox>(
      find.ancestor(of: find.text('99'), matching: find.byType(SizedBox)).first,
    );
    final sizedBox100 = tester.widget<SizedBox>(
      find.ancestor(of: find.text('100'), matching: find.byType(SizedBox)).first,
    );

    expect(sizedBox99.width, equals(36.0));
    expect(sizedBox100.width, equals(36.0));

    final renderBox100 = tester.renderObject(find.text('100')) as RenderBox;
    expect(renderBox100.size.height, lessThanOrEqualTo(16.0));
  });

  testWidgets('RetroSongTile aligns column width for 4-digit queues (>= 1000 tracks)', (tester) async {
    final songs = List.generate(1050, (i) => _createTestSong('s_$i', 'Track ${i + 1}'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(_MockPlayerNotifier.new),
          libraryProvider.overrideWith(_MockLibraryNotifier.new),
        ],
        child: MaterialApp(
          theme: RetroTheme.darkTheme(),
          home: Scaffold(
            body: ListView(
              children: [
                RetroSongTile(
                  song: songs[9],
                  index: 9,
                  queue: songs,
                ),
                RetroSongTile(
                  song: songs[999],
                  index: 999,
                  queue: songs,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final sizedBox10 = tester.widget<SizedBox>(
      find.ancestor(of: find.text('10'), matching: find.byType(SizedBox)).first,
    );
    final sizedBox1000 = tester.widget<SizedBox>(
      find.ancestor(of: find.text('1000'), matching: find.byType(SizedBox)).first,
    );

    expect(sizedBox10.width, equals(44.0));
    expect(sizedBox1000.width, equals(44.0));
  });

  testWidgets('RetroSongTile preserves spacing in selectionMode with 3-digit queue', (tester) async {
    final songs = List.generate(116, (i) => _createTestSong('s_$i', 'Track ${i + 1}'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(_MockPlayerNotifier.new),
          libraryProvider.overrideWith(_MockLibraryNotifier.new),
        ],
        child: MaterialApp(
          theme: RetroTheme.darkTheme(),
          home: Scaffold(
            body: RetroSongTile(
              song: songs[100],
              index: 100,
              queue: songs,
              selectionMode: true,
              isSelected: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.check), findsOneWidget);
    final checkboxBox = tester.widget<SizedBox>(
      find.ancestor(of: find.byIcon(Icons.check), matching: find.byType(SizedBox)).first,
    );
    expect(checkboxBox.width, equals(36.0));
  });

  testWidgets('QueueSheet displays 3-digit track numbers without line wrap', (tester) async {
    final songs = List.generate(105, (i) => _createTestSong('qs_$i', 'Queue Track ${i + 1}'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          playerProvider.overrideWith(() => _MockPlayerNotifier(
                testSong: songs[99],
                testQueue: songs,
              )),
          libraryProvider.overrideWith(_MockLibraryNotifier.new),
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

    final text100 = find.text('100');
    await tester.scrollUntilVisible(text100, 500, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(text100, findsOneWidget);

    final textWidget = tester.widget<Text>(text100);
    expect(textWidget.maxLines, equals(1));
    expect(textWidget.softWrap, isFalse);

    final renderBox100 = tester.renderObject(text100) as RenderBox;
    expect(renderBox100.size.height, lessThanOrEqualTo(16.0));
  });
}
