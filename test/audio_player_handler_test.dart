import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/data/services/audio_player_handler.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/domain/models/audio_quality.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('System AudioPlayerHandler Media Notification Controls', () {
    test('PlaybackState controls expose retro repeat icon instead of stop square', () async {
      final handler = AudioPlayerHandler();
      final controls = handler.playbackState.value.controls;

      // Ensure 5 controls: prev, play/pause, next, repeat, shuffle
      expect(controls.length, 5);
      expect(controls[0].action, MediaAction.skipToPrevious);
      expect(controls[1].action, MediaAction.play);
      expect(controls[2].action, MediaAction.skipToNext);

      // The 4th control should be custom action 'toggle_repeat' with retro ic_repeat icon
      final repeatControl = controls[3];
      expect(repeatControl.androidIcon, 'drawable/ic_repeat');
      expect(repeatControl.customAction?.name, 'toggle_repeat');

      // The 5th control should be custom action 'toggle_shuffle' with retro ic_shuffle icon
      final shuffleControl = controls[4];
      expect(shuffleControl.androidIcon, 'drawable/ic_shuffle');
      expect(shuffleControl.customAction?.name, 'toggle_shuffle');

      // System actions must advertise seek, repeat, and shuffle
      expect(handler.playbackState.value.systemActions.contains(MediaAction.setRepeatMode), isTrue);
      expect(handler.playbackState.value.systemActions.contains(MediaAction.setShuffleMode), isTrue);
    });

    test('customAction toggle_repeat toggles repeat modes and updates icon to ic_repeat_one', () async {
      final handler = AudioPlayerHandler();

      // Initial state is off (none)
      expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.none);
      expect(handler.playbackState.value.controls[3].androidIcon, 'drawable/ic_repeat');

      // Toggle 1: All
      await handler.customAction('toggle_repeat');
      expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.all);
      expect(handler.playbackState.value.controls[3].androidIcon, 'drawable/ic_repeat_dot');

      // Toggle 2: One
      await handler.customAction('toggle_repeat');
      expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.one);
      expect(handler.playbackState.value.controls[3].androidIcon, 'drawable/ic_repeat_one');

      // Toggle 3: Off
      await handler.customAction('toggle_repeat');
      expect(handler.playbackState.value.repeatMode, AudioServiceRepeatMode.none);
      expect(handler.playbackState.value.controls[3].androidIcon, 'drawable/ic_repeat');
    });

    setUp(() {
      AudioPlayerHandler().resetForTesting();
    });

    test('clearQueue keeps the currently playing song at index 0 and clears other songs', () async {
      final handler = AudioPlayerHandler();
      const song1 = Song(
        id: 's1',
        title: 'Track 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Track 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song3 = Song(
        id: 's3',
        title: 'Track 3',
        artist: 'Artist 3',
        album: 'Album 3',
        duration: Duration(seconds: 140),
        uri: 'assets/audio/test3.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      handler.setQueueForTesting(
        songs: [song1, song2, song3],
        currentIndex: 1,
      );
      expect(handler.songQueue.length, 3);
      expect(handler.currentIndex, 1);
      expect(handler.currentSong?.id, 's2');

      // Clear the queue while Track 2 is active
      await handler.clearQueue();

      // Track 2 should remain the only item in the queue at index 0
      expect(handler.songQueue.length, 1);
      expect(handler.currentIndex, 0);
      expect(handler.currentSong?.id, 's2');
      expect(handler.mediaItem.value?.id, 's2');
    });

    test('clearQueue when queue is empty or no song is active clears everything', () async {
      final handler = AudioPlayerHandler();
      await handler.clearQueue();
      expect(handler.songQueue.isEmpty, isTrue);
      expect(handler.currentIndex, -1);
      expect(handler.currentSong, isNull);
      expect(handler.mediaItem.value, isNull);
    });

    test('removeQueueAt updates currentIndex correctly when removing items before current', () async {
      final handler = AudioPlayerHandler();
      const song1 = Song(
        id: 's1',
        title: 'Track 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Track 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      handler.setQueueForTesting(
        songs: [song1, song2],
        currentIndex: 1,
      );
      expect(handler.currentIndex, 1);
      expect(handler.currentSong?.id, 's2');

      // Remove song at index 0 (before current)
      handler.removeQueueAt(0);

      // Current index should now adjust to 0 and currentSong should still be song2
      expect(handler.currentIndex, 0);
      expect(handler.currentSong?.id, 's2');
      expect(handler.songQueue.length, 1);
    });

    test('toggleShuffle keeps currently playing song active at index 0 and untoggle restores original order', () async {
      final handler = AudioPlayerHandler();
      const song1 = Song(
        id: 's1',
        title: 'Track 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Track 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song3 = Song(
        id: 's3',
        title: 'Track 3',
        artist: 'Artist 3',
        album: 'Album 3',
        duration: Duration(seconds: 140),
        uri: 'assets/audio/test3.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song4 = Song(
        id: 's4',
        title: 'Track 4',
        artist: 'Artist 4',
        album: 'Album 4',
        duration: Duration(seconds: 160),
        uri: 'assets/audio/test4.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      handler.setQueueForTesting(
        songs: [song1, song2, song3, song4],
        currentIndex: 1,
      );
      expect(handler.currentIndex, 1);
      expect(handler.currentSong?.id, 's2');
      expect(handler.isShuffle, isFalse);

      // Toggle shuffle ON
      await handler.toggleShuffle();
      expect(handler.isShuffle, isTrue);

      // Current playing song must remain 's2' without interruption, positioned at index 0 with remaining songs shuffled
      expect(handler.currentSong?.id, 's2');
      expect(handler.currentIndex, 0);
      expect(handler.songQueue[0].id, 's2');
      expect(handler.songQueue.length, 4);
      // All 4 tracks should still be in queue
      expect(handler.songQueue.map((s) => s.id).toSet(), {'s1', 's2', 's3', 's4'});

      // Untoggle shuffle OFF
      await handler.toggleShuffle();
      expect(handler.isShuffle, isFalse);

      // Original queue order should be completely restored [s1, s2, s3, s4]
      expect(handler.songQueue.map((s) => s.id).toList(), ['s1', 's2', 's3', 's4']);
      // Current playing song must still be 's2', positioned at its index 1 in the original queue
      expect(handler.currentSong?.id, 's2');
      expect(handler.currentIndex, 1);
    });

    test('User scenario: 1,2,3,4 shuffled to 2,3,1,4 with 3 playing, unshuffle restores 1,2,3,4 and next track is 4', () async {
      final handler = AudioPlayerHandler();
      const song1 = Song(
        id: 's1',
        title: 'Track 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Track 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song3 = Song(
        id: 's3',
        title: 'Track 3',
        artist: 'Artist 3',
        album: 'Album 3',
        duration: Duration(seconds: 140),
        uri: 'assets/audio/test3.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song4 = Song(
        id: 's4',
        title: 'Track 4',
        artist: 'Artist 4',
        album: 'Album 4',
        duration: Duration(seconds: 160),
        uri: 'assets/audio/test4.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      final originalList = [song1, song2, song3, song4];
      final shuffledList = [song2, song3, song1, song4];

      // Play with shuffle queue [s2, s3, s1, s4] and originalList [s1, s2, s3, s4]
      // Currently song 3 is playing (which is at index 1 in shuffled list)
      handler.setQueueForTesting(
        songs: shuffledList,
        currentIndex: 1,
        originalList: originalList,
        isShuffle: true,
      );

      expect(handler.isShuffle, isTrue);
      expect(handler.currentSong?.id, 's3');
      expect(handler.currentIndex, 1);
      expect(handler.songQueue.map((s) => s.id).toList(), ['s2', 's3', 's1', 's4']);
      // If shuffle was ON, next song would be s1 (at index 2)
      expect(handler.songQueue[handler.currentIndex + 1].id, 's1');

      // Now toggle unshuffle OFF
      await handler.toggleShuffle();
      expect(handler.isShuffle, isFalse);

      // Queue must now be the original unshuffled list [s1, s2, s3, s4]
      expect(handler.songQueue.map((s) => s.id).toList(), ['s1', 's2', 's3', 's4']);
      // Song 3 must continue playing
      expect(handler.currentSong?.id, 's3');
      // Song 3's index in the unshuffled queue is 2
      expect(handler.currentIndex, 2);
      // Once song 3 finishes, song 4 (at index 3) will play next!
      expect(handler.songQueue[handler.currentIndex + 1].id, 's4');
    });

    test('currentIndexStream emits verified index matching currentSong and preserves currentSong across shuffle toggle and untoggle', () async {
      final handler = AudioPlayerHandler();
      const song1 = Song(
        id: 's1',
        title: 'Track 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Track 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song3 = Song(
        id: 's3',
        title: 'Track 3',
        artist: 'Artist 3',
        album: 'Album 3',
        duration: Duration(seconds: 140),
        uri: 'assets/audio/test3.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song4 = Song(
        id: 's4',
        title: 'Track 4',
        artist: 'Artist 4',
        album: 'Album 4',
        duration: Duration(seconds: 160),
        uri: 'assets/audio/test4.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      final originalList = [song1, song2, song3, song4];
      handler.setQueueForTesting(
        songs: originalList,
        currentIndex: 2, // Song 3 playing
        originalList: originalList,
        isShuffle: false,
      );

      final emittedIndices = <int?>[];
      final sub = handler.currentIndexStream.listen((idx) {
        emittedIndices.add(idx);
      });

      expect(handler.currentSong?.id, 's3');
      expect(handler.currentIndex, 2);

      // Toggle shuffle ON
      await handler.toggleShuffle();
      expect(handler.isShuffle, isTrue);
      expect(handler.currentSong?.id, 's3');
      expect(handler.currentIndex, 0);
      expect(handler.songQueue[0].id, 's3');

      // Toggle shuffle OFF
      await handler.toggleShuffle();
      expect(handler.isShuffle, isFalse);
      expect(handler.currentSong?.id, 's3');
      expect(handler.currentIndex, 2);
      expect(handler.songQueue[2].id, 's3');
      expect(handler.songQueue.map((s) => s.id).toList(), ['s1', 's2', 's3', 's4']);

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();
      // Emitted indices must only be the clean, settled states (0 then 2)
      expect(emittedIndices, containsAllInOrder([0, 2]));
    });

    test('toggleShuffle and unshuffle with duplicate songs preserves queue length and all songs', () async {
      final handler = AudioPlayerHandler();
      const song1 = Song(
        id: 's1',
        title: 'Track 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Track 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 120),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song1Dup = Song(
        id: 's1',
        title: 'Track 1 (Reprise)',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 100),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      final listWithDup = [song1, song2, song1Dup];
      handler.setQueueForTesting(
        songs: listWithDup,
        currentIndex: 0,
        originalList: listWithDup,
        isShuffle: false,
      );

      expect(handler.songQueue.length, 3);
      await handler.toggleShuffle();
      expect(handler.isShuffle, isTrue);
      // Queue length must not decrease due to duplicate id
      expect(handler.songQueue.length, 3);
      expect(handler.currentSong?.id, 's1');

      await handler.toggleShuffle();
      expect(handler.isShuffle, isFalse);
      expect(handler.songQueue.length, 3);
      expect(handler.currentSong?.id, 's1');
      expect(handler.currentIndex, 0);
    });

    test('onTaskRemoved stops playback and transitions player state', () async {
      final handler = AudioPlayerHandler();
      await handler.onTaskRemoved();
      expect(handler.isPlaying, isFalse);
    });

    test('systemActions advertises skipToNext and skipToPrevious', () async {
      final handler = AudioPlayerHandler();
      expect(handler.playbackState.value.systemActions.contains(MediaAction.skipToNext), isTrue);
      expect(handler.playbackState.value.systemActions.contains(MediaAction.skipToPrevious), isTrue);
    });

    test('wired headset double-click skips to next song', () async {
      final handler = AudioPlayerHandler();
      handler.mediaClickTimeout = const Duration(milliseconds: 50);

      const song1 = Song(
        id: 's1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 180),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 200),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      handler.setQueueForTesting(
        songs: [song1, song2],
        currentIndex: 0,
      );

      expect(handler.currentIndex, 0);

      // Simulate wired earphone double-click (two MediaButton.media within timeout)
      await handler.click(MediaButton.media);
      await Future.delayed(const Duration(milliseconds: 15));
      await handler.click(MediaButton.media);

      // Wait for debounce timeout to fire
      await Future.delayed(const Duration(milliseconds: 80));

      expect(handler.currentIndex, 1);
      expect(handler.currentSong?.id, 's2');
    });

    test('wired headset triple-click skips to previous song', () async {
      final handler = AudioPlayerHandler();
      handler.mediaClickTimeout = const Duration(milliseconds: 50);

      const song1 = Song(
        id: 's1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 180),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 200),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      handler.setQueueForTesting(
        songs: [song1, song2],
        currentIndex: 1,
      );

      expect(handler.currentIndex, 1);

      // Simulate wired earphone triple-click (three MediaButton.media within timeout)
      await handler.click(MediaButton.media);
      await Future.delayed(const Duration(milliseconds: 10));
      await handler.click(MediaButton.media);
      await Future.delayed(const Duration(milliseconds: 10));
      await handler.click(MediaButton.media);

      // Wait for debounce timeout to fire
      await Future.delayed(const Duration(milliseconds: 80));

      expect(handler.currentIndex, 0);
      expect(handler.currentSong?.id, 's1');
    });

    test('wireless earphone MediaButton.next immediately skips without debounce', () async {
      final handler = AudioPlayerHandler();

      const song1 = Song(
        id: 's1',
        title: 'Song 1',
        artist: 'Artist 1',
        album: 'Album 1',
        duration: Duration(seconds: 180),
        uri: 'assets/audio/test1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );
      const song2 = Song(
        id: 's2',
        title: 'Song 2',
        artist: 'Artist 2',
        album: 'Album 2',
        duration: Duration(seconds: 200),
        uri: 'assets/audio/test2.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100),
      );

      handler.setQueueForTesting(
        songs: [song1, song2],
        currentIndex: 0,
      );

      expect(handler.currentIndex, 0);

      // Direct next command from wireless headphones
      await handler.click(MediaButton.next);

      expect(handler.currentIndex, 1);
      expect(handler.currentSong?.id, 's2');
    });
  });
}

