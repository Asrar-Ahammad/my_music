import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/data/services/audio_player_handler.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/widgets/retro_song_tile.dart';

Song _createSong(String id, String title) {
  return Song(
    id: id,
    title: title,
    artist: 'Artist',
    album: 'Album',
    duration: const Duration(seconds: 180),
    uri: 'file://$id.mp3',
    quality: const AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
  );
}

class _TestPlayerNotifier extends PlayerNotifier {
  final List<String> calls = [];

  @override
  PlayerStateModel build() {
    return PlayerStateModel(
      currentSong: _createSong('current', 'Current Song'),
      isPlaying: true,
      queue: [_createSong('current', 'Current Song')],
      currentIndex: 0,
      userQueueCount: 0,
    );
  }

  @override
  void addToQueue(Song song) {
    calls.add('addToQueue:${song.title}');
    state = state.copyWith(userQueueCount: state.userQueueCount + 1);
  }

  @override
  void addNext(Song song) {
    calls.add('addNext:${song.title}');
    state = state.copyWith(userQueueCount: state.userQueueCount + 1);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RetroSongTile Swipe Gestures', () {
    testWidgets('Swipe right triggers addToQueue and card remains in view', (tester) async {
      final notifier = _TestPlayerNotifier();
      final songToSwipe = _createSong('s1', 'Song Number One');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: Scaffold(
              body: RetroSongTile(
                song: songToSwipe,
                index: 0,
                queue: [songToSwipe],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Song Number One'), findsOneWidget);

      // Perform swipe right (start to end)
      await tester.drag(find.text('Song Number One'), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('addToQueue:Song Number One'));
      // Confirm card was NOT dismissed / deleted
      expect(find.text('Song Number One'), findsOneWidget);
    });

    testWidgets('Swipe left triggers addNext and card remains in view', (tester) async {
      final notifier = _TestPlayerNotifier();
      final songToSwipe = _createSong('s2', 'Song Number Two');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: Scaffold(
              body: RetroSongTile(
                song: songToSwipe,
                index: 0,
                queue: [songToSwipe],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Song Number Two'), findsOneWidget);

      // Perform swipe left (end to start)
      await tester.drag(find.text('Song Number Two'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('addNext:Song Number Two'));
      // Confirm card was NOT dismissed / deleted
      expect(find.text('Song Number Two'), findsOneWidget);
    });
  });

  group('AudioPlayerHandler Spotify-style Queue Logic', () {
    test('Add to queue builds a secondary queue on top of context queue', () {
      final handler = AudioPlayerHandler();
      final s0 = _createSong('s0', 'Song 0');
      final s1 = _createSong('s1', 'Song 1');
      final s2 = _createSong('s2', 'Song 2');

      handler.setQueueAndPlay([s0, s1, s2], 0);

      expect(handler.songQueue.map((s) => s.id).toList(), ['s0', 's1', 's2']);
      expect(handler.userQueueCount, 0);

      // 1. User adds Song A to queue
      final sA = _createSong('sa', 'Song A');
      handler.addSongToQueue(sA);
      // Song A placed after current song (s0), before original playlist (s1, s2)
      expect(handler.songQueue.map((s) => s.id).toList(), ['s0', 'sa', 's1', 's2']);
      expect(handler.userQueueCount, 1);

      // 2. User adds Song B to queue
      final sB = _createSong('sb', 'Song B');
      handler.addSongToQueue(sB);
      // Song B appended to user queue after Song A, before original playlist (s1, s2)
      expect(handler.songQueue.map((s) => s.id).toList(), ['s0', 'sa', 'sb', 's1', 's2']);
      expect(handler.userQueueCount, 2);

      // 3. User selects Play Next for Song C
      final sC = _createSong('sc', 'Song C');
      handler.addSongNext(sC);
      // Song C placed immediately after current song (s0) at top of user queue
      expect(handler.songQueue.map((s) => s.id).toList(), ['s0', 'sc', 'sa', 'sb', 's1', 's2']);
      expect(handler.userQueueCount, 3);

      // 4. Playback advances: skip to next item (index 1 -> Song C)
      handler.playAtIndex(1);
      expect(handler.currentSong?.id, 'sc');
      expect(handler.userQueueCount, 2);

      // 5. Playback advances: skip to next item (index 2 -> Song A)
      handler.playAtIndex(2);
      expect(handler.currentSong?.id, 'sa');
      expect(handler.userQueueCount, 1);

      // 6. Playback advances: skip to next item (index 3 -> Song B)
      handler.playAtIndex(3);
      expect(handler.currentSong?.id, 'sb');
      expect(handler.userQueueCount, 0);

      // 7. Playback advances: all user-queued songs played, now resumes original context queue (Song 1)
      handler.playAtIndex(4);
      expect(handler.currentSong?.id, 's1');
      expect(handler.userQueueCount, 0);
    });
  });
}
