import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_colors.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/core/utils/lrc_parser.dart';
import 'package:my_music/data/services/lyrics_service.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/lrc_model.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/lyrics_provider.dart';
import 'package:my_music/presentation/screens/lyrics/lyrics_screen.dart';
import 'package:my_music/presentation/widgets/retro_icon.dart';

void main() {
  group('LrcParser Tests', () {
    test('parses metadata headers correctly', () {
      const lrcContent = '''
[ti:Retro Wave Journey]
[ar:Chiptune Master]
[al:8-Bit Dreams]
[by:myMusic]
[offset:+500]
[00:05.00]First line of the song
''';

      final doc = LrcParser.parse(lrcContent);
      expect(doc.title, 'Retro Wave Journey');
      expect(doc.artist, 'Chiptune Master');
      expect(doc.album, '8-Bit Dreams');
      expect(doc.creator, 'myMusic');
      expect(doc.offsetMs, 500);
      expect(doc.lines.length, 1);
      // Adjusted timestamp: 5000ms + 500ms offset = 5500ms
      expect(doc.lines.first.timestamp, const Duration(milliseconds: 5500));
      expect(doc.lines.first.text, 'First line of the song');
    });

    test('parses multiple timestamps per line and sorts chronologically', () {
      const lrcContent = '''
[00:10.00][00:30.00]Repeated chorus hook
[00:02.50]Intro beats
[00:20.00]Verse one begins
''';

      final doc = LrcParser.parse(lrcContent);
      expect(doc.isSynced, isTrue);
      expect(doc.lines.length, 4);

      // Verify sorted order
      expect(doc.lines[0].timestamp, const Duration(milliseconds: 2500));
      expect(doc.lines[0].text, 'Intro beats');

      expect(doc.lines[1].timestamp, const Duration(seconds: 10));
      expect(doc.lines[1].text, 'Repeated chorus hook');

      expect(doc.lines[2].timestamp, const Duration(seconds: 20));
      expect(doc.lines[2].text, 'Verse one begins');

      expect(doc.lines[3].timestamp, const Duration(seconds: 30));
      expect(doc.lines[3].text, 'Repeated chorus hook');
    });

    test('handles 3-digit millisecond timestamps', () {
      const lrcContent = '''
[01:05.123]High precision timestamp
[02:15.999]End of measure
''';

      final doc = LrcParser.parse(lrcContent);
      expect(doc.lines.length, 2);
      expect(doc.lines[0].timestamp, const Duration(minutes: 1, seconds: 5, milliseconds: 123));
      expect(doc.lines[1].timestamp, const Duration(minutes: 2, seconds: 15, milliseconds: 999));
    });

    test('parses syllable / word-level timestamps', () {
      const lrcContent = '''
[00:15.50]<00:15.50>I <00:15.80>can <00:16.10>hear <00:16.50>the <00:17.00>music
''';

      final doc = LrcParser.parse(lrcContent);
      expect(doc.lines.length, 1);
      final line = doc.lines.first;
      expect(line.hasSyllableTimings, isTrue);
      expect(line.text, 'I can hear the music');
      expect(line.words!.length, 5);
      expect(line.words![0].text, 'I ');
      expect(line.words![0].timestamp, const Duration(milliseconds: 15500));
      expect(line.words![4].text, 'music');
      expect(line.words![4].timestamp, const Duration(seconds: 17));
    });

    test('parses leading text before first inline syllable tag and handles relative offsets', () {
      const lrcContent = '''
[01:10.00]Never <01:10.50>gonna <01:11.20>give
[02:00.00]<00:00.00>You <00:01.00>up
''';

      final doc = LrcParser.parse(lrcContent);
      expect(doc.lines.length, 2);

      // Line 1: leading text "Never " gets line timestamp (01:10.00 = 70s)
      final line1 = doc.lines[0];
      expect(line1.hasSyllableTimings, isTrue);
      expect(line1.text, 'Never gonna give');
      expect(line1.words!.length, 3);
      expect(line1.words![0].text, 'Never ');
      expect(line1.words![0].timestamp, const Duration(seconds: 70));
      expect(line1.words![1].text, 'gonna ');
      expect(line1.words![1].timestamp, const Duration(milliseconds: 70500));
      expect(line1.words![2].text, 'give');
      expect(line1.words![2].timestamp, const Duration(milliseconds: 71200));

      // Line 2: relative timestamps (<00:00.00>, <00:01.00>) get offset by line time (02:00.00 = 120s)
      final line2 = doc.lines[1];
      expect(line2.hasSyllableTimings, isTrue);
      expect(line2.text, 'You up');
      expect(line2.words!.length, 2);
      expect(line2.words![0].timestamp, const Duration(seconds: 120));
      expect(line2.words![1].timestamp, const Duration(seconds: 121));
    });

    test('parses square bracket formats in enhanced LRC', () {
      const lrcContent = '''
[00:20.00]First [00:21.00]second [00:22.00]third
[00:30.00]<00:30.50>Hello <00:31.00>world
''';

      final doc = LrcParser.parse(lrcContent);
      expect(doc.lines.length, 2);

      final line1 = doc.lines[0];
      expect(line1.hasSyllableTimings, isTrue);
      expect(line1.text, 'First second third');
      expect(line1.words!.length, 3);
      expect(line1.words![0].timestamp, const Duration(seconds: 20));
      expect(line1.words![1].timestamp, const Duration(seconds: 21));
      expect(line1.words![2].timestamp, const Duration(seconds: 22));

      final line2 = doc.lines[1];
      expect(line2.hasSyllableTimings, isTrue);
      expect(line2.words!.length, 2);
      expect(line2.words![0].timestamp, const Duration(milliseconds: 30500));
      expect(line2.words![1].timestamp, const Duration(milliseconds: 31000));
    });

    test('withSynthesizedWordTimings generates word timings based on duration', () {
      const lrcContent = '''
[00:10.00]One two three four
[00:14.00]Next line
''';

      final doc = LrcParser.parse(lrcContent);
      expect(doc.lines[0].hasSyllableTimings, isFalse);
      expect(doc.lines[0].hasGenuineSyllableTimings, isFalse);

      final enhanced = doc.withSynthesizedWordTimings();
      final line = enhanced.lines[0];
      expect(line.hasSyllableTimings, isTrue);
      expect(line.isSynthesized, isTrue);
      expect(line.hasGenuineSyllableTimings, isFalse);
      expect(line.words!.length, 4);
      expect(line.words![0].text.trim(), 'One');
      expect(line.words![0].timestamp, const Duration(seconds: 10));
      // Later words have monotonically increasing timestamps within the 4s window
      expect(line.words![1].timestamp, greaterThanOrEqualTo(line.words![0].timestamp));
      expect(line.words![2].timestamp, greaterThan(line.words![1].timestamp));
      expect(line.words![3].timestamp, lessThanOrEqualTo(const Duration(seconds: 14)));
    });

    test('parses plain unsynced text when no timestamps present', () {
      const unsyncedContent = '''
This is just plain text
With multiple lines
Of unsynced song lyrics
''';

      final doc = LrcParser.parse(unsyncedContent);
      expect(doc.isSynced, isFalse);
      expect(doc.lines.length, 3);
      expect(doc.lines[0].text, 'This is just plain text');
      expect(doc.lines[0].timestamp, Duration.zero);
      expect(doc.lines[1].text, 'With multiple lines');
      expect(doc.lines[2].text, 'Of unsynced song lyrics');
    });
  });

  group('LrcDocument Binary Search & Active Line Detection', () {
    late LrcDocument doc;

    setUp(() {
      doc = const LrcDocument(
        isSynced: true,
        rawContent: '',
        lines: [
          LrcLine(timestamp: Duration(seconds: 5), text: 'Line 1 (0:05)'),
          LrcLine(timestamp: Duration(seconds: 12), text: 'Line 2 (0:12)'),
          LrcLine(timestamp: Duration(seconds: 25), text: 'Line 3 (0:25)'),
          LrcLine(timestamp: Duration(seconds: 40), text: 'Line 4 (0:40)'),
        ],
      );
    });

    test('returns -1 before first line starts', () {
      expect(doc.findLineIndexAt(const Duration(seconds: 2)), -1);
      expect(doc.findLineAt(const Duration(seconds: 2)), isNull);
    });

    test('finds exact timestamp matches', () {
      expect(doc.findLineIndexAt(const Duration(seconds: 5)), 0);
      expect(doc.findLineAt(const Duration(seconds: 5))?.text, 'Line 1 (0:05)');

      expect(doc.findLineIndexAt(const Duration(seconds: 12)), 1);
      expect(doc.findLineAt(const Duration(seconds: 12))?.text, 'Line 2 (0:12)');

      expect(doc.findLineIndexAt(const Duration(seconds: 40)), 3);
      expect(doc.findLineAt(const Duration(seconds: 40))?.text, 'Line 4 (0:40)');
    });

    test('finds correct active line between timestamps', () {
      // 8s is between 5s and 12s -> line 0
      expect(doc.findLineIndexAt(const Duration(seconds: 8)), 0);

      // 18s is between 12s and 25s -> line 1
      expect(doc.findLineIndexAt(const Duration(seconds: 18)), 1);

      // 30s is between 25s and 40s -> line 2
      expect(doc.findLineIndexAt(const Duration(seconds: 30)), 2);

      // 55s is after 40s -> line 3
      expect(doc.findLineIndexAt(const Duration(seconds: 55)), 3);
    });

    test('handles unsynced document index gracefully', () {
      const unsynced = LrcDocument(
        isSynced: false,
        rawContent: '',
        lines: [
          LrcLine(timestamp: Duration.zero, text: 'Line A'),
          LrcLine(timestamp: Duration.zero, text: 'Line B'),
        ],
      );
      expect(unsynced.findLineIndexAt(const Duration(seconds: 10)), -1);
      expect(unsynced.findLineAt(const Duration(seconds: 10)), isNull);
    });

    test('parses Zulfe unsynced sample LRC file with metadata and Hindi text', () {
      const zulfeContent = '''[ti:Zulfe]
[ar:Saahel, Trosk]
[by:SpotiFLAC-Mobile (source: LRCLIB)]

Hm-mm, hm-mm
Hm-mm, hm-mm
होश में, बेहोशी में तू ही तू
गहरी-सी रातें हैं, मैं बेक़ाबू
''';

      final doc = LrcParser.parse(zulfeContent);
      expect(doc.title, 'Zulfe');
      expect(doc.artist, 'Saahel, Trosk');
      expect(doc.creator, 'SpotiFLAC-Mobile (source: LRCLIB)');
      expect(doc.isSynced, isFalse);
      expect(doc.lines.length, 4);
      expect(doc.lines[0].text, 'Hm-mm, hm-mm');
      expect(doc.lines[2].text, 'होश में, बेहोशी में तू ही तू');

      // Unsynced documents have activeLineIndex = -1 so no line is highlighted
      final state = LyricsState(lyrics: doc, activeLineIndex: -1);
      expect(state.currentLine, isNull);
    });
  });

  group('LyricsService File Matching Tests', () {
    const testSong = Song(
      id: 'song-zulfe',
      title: 'Zulfe',
      artist: 'Saahel, Trosk',
      album: 'Zulfe',
      duration: Duration(minutes: 3),
      uri: '/storage/emulated/0/Music/Zulfe.mp3',
      quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100, bitrateKbps: 320),
    );

    test('matches Zulfe - Saahel, Trosk filename against Zulfe song', () {
      expect(LyricsService.matchesSong('Zulfe - Saahel, Trosk', testSong), isTrue);
      expect(LyricsService.matchesSong('Zulfe', testSong), isTrue);
      expect(LyricsService.matchesSong('Saahel, Trosk - Zulfe', testSong), isTrue);
      expect(LyricsService.matchesSong('01 - Zulfe', testSong), isTrue);
    });

    test('matches when song has single artist and LRC has featured artists', () {
      const singleArtistSong = Song(
        id: 'song-1',
        title: 'Zulfe',
        artist: 'Saahel',
        album: 'Zulfe',
        duration: Duration(minutes: 3),
        uri: '/storage/emulated/0/Music/Zulfe.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100, bitrateKbps: 320),
      );
      expect(LyricsService.matchesSong('Zulfe - Saahel, Trosk', singleArtistSong), isTrue);
    });

    test('matches non-Latin unicode titles without erasing text', () {
      const hindiSong = Song(
        id: 'song-h',
        title: 'होश में',
        artist: 'Saahel',
        album: 'Single',
        duration: Duration(minutes: 3),
        uri: '/storage/emulated/0/Music/hosh.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100, bitrateKbps: 320),
      );
      expect(LyricsService.matchesSong('होश में - Saahel', hindiSong), isTrue);
      expect(LyricsService.matchesSong('होश में', hindiSong), isTrue);
    });

    test('strictly prevents substring false positives (e.g. One vs Someone Like You)', () {
      const someoneLikeYou = Song(
        id: 'song-adele',
        title: 'Someone Like You',
        artist: 'Adele',
        album: '21',
        duration: Duration(minutes: 4),
        uri: '/storage/emulated/0/Music/Adele - Someone Like You.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100, bitrateKbps: 320),
      );

      // "One" or "You" should NOT match "Someone Like You"
      expect(LyricsService.matchesSong('One', someoneLikeYou), isFalse);
      expect(LyricsService.matchesSong('You', someoneLikeYou), isFalse);
      expect(LyricsService.matchesSong('Like', someoneLikeYou), isFalse);
      expect(LyricsService.matchesSong('Bad', someoneLikeYou), isFalse);
      expect(LyricsService.matchesSong('One - Metallica', someoneLikeYou), isFalse);

      // Exact title, cleaned title, and Artist - Title SHOULD match
      expect(LyricsService.matchesSong('Someone Like You', someoneLikeYou), isTrue);
      expect(LyricsService.matchesSong('Adele - Someone Like You', someoneLikeYou), isTrue);
      expect(LyricsService.matchesSong('Someone Like You - Adele', someoneLikeYou), isTrue);
      expect(LyricsService.matchesSong('01. Someone Like You', someoneLikeYou), isTrue);
    });

    test('cleans song titles and artist names effectively', () {
      expect(LyricsService.cleanSongTitle('01 - Blinding Lights.mp3'), 'Blinding Lights');
      expect(LyricsService.cleanSongTitle('Blinding Lights [Official Music Video]'), 'Blinding Lights');
      expect(LyricsService.cleanSongTitle('Blinding Lights (Lyrics)'), 'Blinding Lights');
      expect(LyricsService.cleanSongTitle('02. Blinding Lights (320kbps) [Songs.pk]'), 'Blinding Lights');
      expect(LyricsService.cleanSongTitle('Blinding Lights (Remastered 2021)'), 'Blinding Lights');

      expect(LyricsService.cleanArtistName('The Weeknd www.music.com'), 'The Weeknd');
      expect(LyricsService.cleanArtistName('Unknown Artist'), '');
      expect(LyricsService.cleanArtistName('Unknown'), '');
    });
  });

  group('LyricsScreen Scroll and Sync Behavior', () {
    testWidgets('does not auto-snap when user has scrolled until SYNC button tapped', (tester) async {
      final lrcDoc = LrcDocument(
        isSynced: true,
        rawContent: '',
        lines: List.generate(
          30,
          (i) => LrcLine(
            timestamp: Duration(seconds: i * 5),
            text: 'Lyric line number ${i + 1} with retro words',
          ),
        ),
      );

      final mockLyricsState = LyricsState(
        lyrics: lrcDoc,
        activeLineIndex: 2,
        sourceName: 'LOCAL LRC',
        songId: 'test-song',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith(() => MockCustomLyricsNotifier(mockLyricsState)),
          ],
          child: MaterialApp(
            theme: RetroTheme.lightTheme(),
            home: const LyricsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially SYNC button is not shown
      expect(find.text('SYNC'), findsNothing);

      // User scrolls manually
      await tester.drag(find.text('Lyric line number 3 with retro words'), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Now SYNC button is visible because user has scrolled
      expect(find.text('SYNC'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is RetroIcon && w.iconName == 'arrow_down'),
        findsOneWidget,
      );

      // Tap SYNC button
      await tester.tap(find.text('SYNC'));
      await tester.pumpAndSettle();

      // After SYNC, button is hidden again
      expect(find.text('SYNC'), findsNothing);
    });

    testWidgets('displays WORD SYNC badge and highlights sung words in song color when syllable timings exist', (tester) async {
      const syllableLrc = '''
[ti:Pixel Love]
[ar:Chiptune Hero]
[00:00.00]<00:00.00>Never <00:01.00>gonna <00:02.00>give <00:03.00>you <00:04.00>up
''';
      final doc = LrcParser.parse(syllableLrc);
      expect(doc.hasSyllableTimings, isTrue);

      final mockLyricsState = LyricsState(
        lyrics: doc,
        activeLineIndex: 0,
        sourceName: 'LRCLIB',
        songId: 'song-123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith(() => MockCustomLyricsNotifier(mockLyricsState)),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const LyricsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // WORD SYNC badge is visible
      expect(find.text('WORD SYNC'), findsOneWidget);

      // Verify RichText with words is present
      final richTextFinder = find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText().contains('Never gonna give you up'),
      );
      expect(richTextFinder, findsOneWidget);
    });

    testWidgets('synthesizes word timings for standard synced lyrics and highlights word by word', (tester) async {
      const standardSyncedLrc = '''
[ti:Retro Anthem]
[00:00.00]First line playing now
[00:04.00]Second line starts later
''';
      final doc = LrcParser.parse(standardSyncedLrc).withSynthesizedWordTimings();
      expect(doc.hasSyllableTimings, isTrue);
      expect(doc.lines.first.hasSyllableTimings, isTrue);
      expect(doc.lines.first.words, isNotNull);
      expect(doc.lines.first.words!.length, 4);

      final mockLyricsState = LyricsState(
        lyrics: doc,
        activeLineIndex: 0,
        sourceName: 'LRCLIB',
        songId: 'anthem-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith(() => MockCustomLyricsNotifier(mockLyricsState)),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const LyricsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WORD SYNC'), findsOneWidget);
      final richText = find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText().contains('First line playing now'),
      );
      expect(richText, findsOneWidget);
    });

    testWidgets('displays UNSYNCED badge and renders unsynced lyric lines', (tester) async {
      final doc = LrcParser.parse('''[ti:Zulfe]
[ar:Saahel, Trosk]
Hm-mm, hm-mm
होश में, बेहोशी में तू ही तू
''');
      final mockLyricsState = LyricsState(
        lyrics: doc,
        activeLineIndex: 1,
        sourceName: 'LOCAL FILE',
        songId: 'song-zulfe',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith(() => MockCustomLyricsNotifier(mockLyricsState)),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const LyricsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('UNSYNCED'), findsOneWidget);
      expect(find.text('LOCAL FILE'), findsOneWidget);
      expect(find.text('Hm-mm, hm-mm'), findsOneWidget);
      expect(find.text('होश में, बेहोशी में तू ही तू'), findsOneWidget);
      expect(find.text('▶'), findsNothing);
    });

    testWidgets('displays SYNCED badge and highlights active line for standard line-synced lyrics', (tester) async {
      const standardSyncedLrc = '''
[ti:Line Synced Track]
[00:00.00]First line currently sung
[00:05.00]Second line starts later
''';
      final doc = LrcParser.parse(standardSyncedLrc);
      expect(doc.hasSyllableTimings, isFalse);
      expect(doc.hasGenuineSyllableTimings, isFalse);
      expect(doc.isSynced, isTrue);

      final mockLyricsState = LyricsState(
        lyrics: doc,
        activeLineIndex: 0,
        sourceName: 'LRCLIB',
        songId: 'track-sync-1',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            lyricsProvider.overrideWith(() => MockCustomLyricsNotifier(mockLyricsState)),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const LyricsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SYNCED'), findsOneWidget);
      expect(find.text('LRCLIB'), findsOneWidget);
      expect(find.text('First line currently sung'), findsOneWidget);
      expect(find.text('Second line starts later'), findsOneWidget);
    });
  });

  group('RetroColors Song Accent Color Tests', () {
    test('produces deterministic color based on song ID and title', () {
      final color1 = RetroColors.getSongAccentColor('song-abc', 'Retro Journey', isDark: true);
      final color2 = RetroColors.getSongAccentColor('song-abc', 'Retro Journey', isDark: true);
      expect(color1, equals(color2));

      final colorDark = RetroColors.getSongAccentColor('song-xyz', 'Pixel Funk', isDark: true);
      final colorLight = RetroColors.getSongAccentColor('song-xyz', 'Pixel Funk', isDark: false);
      expect(colorDark, isNotNull);
      expect(colorLight, isNotNull);
    });
  });
}

class MockCustomLyricsNotifier extends LyricsNotifier {
  final LyricsState custom;
  MockCustomLyricsNotifier(this.custom);

  @override
  LyricsState build() => custom;
}

