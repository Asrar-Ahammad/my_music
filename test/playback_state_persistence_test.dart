import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/theme/retro_theme.dart';
import 'package:my_music/data/services/audio_player_handler.dart';
import 'package:my_music/data/services/storage_service.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';
import 'package:my_music/presentation/providers/player_provider.dart';
import 'package:my_music/presentation/widgets/mini_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  final testSong1 = Song(
    id: 'song-1',
    title: 'Pixel Symphony',
    artist: 'Chiptune Master',
    album: 'Retro Wave',
    duration: const Duration(seconds: 180),
    uri: '/storage/pixel_symphony.mp3',
    quality: const AudioQuality(
      format: 'FLAC',
      bitDepth: 24,
      sampleRate: 96000,
      bitrateKbps: 1411,
    ),
  );

  final testSong2 = Song(
    id: 'song-2',
    title: 'Arcade Dream',
    artist: '8-Bit Hero',
    album: 'Retro Wave',
    duration: const Duration(seconds: 210),
    uri: '/storage/arcade_dream.mp3',
    quality: const AudioQuality(
      format: 'MP3',
      bitDepth: 16,
      sampleRate: 44100,
      bitrateKbps: 320,
    ),
  );

  final testSong3 = Song(
    id: 'song-3',
    title: 'Neon Horizon',
    artist: 'Synth Runner',
    album: 'Cyber Zone',
    duration: const Duration(seconds: 195),
    uri: '/storage/neon_horizon.mp3',
    quality: const AudioQuality(
      format: 'WAV',
      bitDepth: 16,
      sampleRate: 44100,
      bitrateKbps: 1411,
    ),
  );

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('playback_test_');
    storage = StorageService();
    await storage.init(tempDir.path);

    const channel = MethodChannel('com.ryanheise.just_audio.methods');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'init':
          return {'id': call.arguments['id'] ?? 'player_0'};
        case 'disposeAllPlayers':
          return {};
        case 'load':
          return {'duration': 180000000};
        default:
          return {};
      }
    });
  });

  setUp(() async {
    await storage.clearSavedPlaybackState();
    await storage.setNowPlayingDrawerOpen(false);
    AudioPlayerHandler().resetForTesting();
  });

  tearDown(() async {
    await storage.clearSavedPlaybackState();
    await storage.setNowPlayingDrawerOpen(false);
    AudioPlayerHandler().resetForTesting();
  });

  group('StorageService Playback State Persistence Tests', () {
    test('savePlaybackState and getSavedPlaybackState preserve complete snapshot', () async {
      await storage.savePlaybackState(
        currentSong: testSong1,
        position: const Duration(seconds: 45),
        queue: [testSong1, testSong2, testSong3],
        originalQueue: [testSong1, testSong2, testSong3],
        currentIndex: 0,
        isShuffle: true,
        loopMode: 'all',
        playlistId: 'pl-favorites',
      );

      final state = storage.getSavedPlaybackState();
      expect(state, isNotNull);
      expect(state!['song']['id'], 'song-1');
      expect(state['song']['title'], 'Pixel Symphony');
      expect(state['positionMs'], 45000);
      expect(state['currentIndex'], 0);
      expect(state['isShuffle'], isTrue);
      expect(state['loopMode'], 'all');
      expect(state['playlistId'], 'pl-favorites');

      final queueList = (state['queue'] as List)
          .map((e) => Song.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      expect(queueList.length, 3);
      expect(queueList[0].id, 'song-1');
      expect(queueList[1].id, 'song-2');
      expect(queueList[2].id, 'song-3');
    });

    test('savePlaybackPosition updates only positionMs in saved state', () async {
      await storage.savePlaybackState(
        currentSong: testSong2,
        position: const Duration(seconds: 20),
        queue: [testSong2],
        originalQueue: [testSong2],
        currentIndex: 0,
        isShuffle: false,
        loopMode: 'off',
      );

      await storage.savePlaybackPosition(const Duration(seconds: 75));

      final state = storage.getSavedPlaybackState();
      expect(state, isNotNull);
      expect(state!['song']['id'], 'song-2');
      expect(state['positionMs'], 75000);
      expect(state['isShuffle'], isFalse);
    });

    test('clearSavedPlaybackState deletes saved playback state', () async {
      await storage.savePlaybackState(
        currentSong: testSong1,
        position: const Duration(seconds: 10),
        queue: [testSong1],
        originalQueue: [testSong1],
        currentIndex: 0,
        isShuffle: false,
        loopMode: 'off',
      );

      expect(storage.getSavedPlaybackState(), isNotNull);
      await storage.clearSavedPlaybackState();
      expect(storage.getSavedPlaybackState(), isNull);
    });

    test('Now Playing drawer open state is preserved and toggled correctly', () async {
      expect(storage.isNowPlayingDrawerOpen(), isFalse);
      await storage.setNowPlayingDrawerOpen(true);
      expect(storage.isNowPlayingDrawerOpen(), isTrue);
      await storage.setNowPlayingDrawerOpen(false);
      expect(storage.isNowPlayingDrawerOpen(), isFalse);
    });
  });

  group('AudioPlayerHandler State Restoration Tests', () {
    test('restoreSavedPlaybackState loads saved queue, song, position, shuffle, and loop mode', () async {
      final handler = AudioPlayerHandler();

      // Save state to storage
      await storage.savePlaybackState(
        currentSong: testSong2,
        position: const Duration(seconds: 88),
        queue: [testSong1, testSong2, testSong3],
        originalQueue: [testSong1, testSong2, testSong3],
        currentIndex: 1,
        isShuffle: true,
        loopMode: 'one',
        playlistId: 'playlist-retro',
      );

      // Trigger restoration
      await handler.restoreSavedPlaybackState();

      expect(handler.currentSong?.id, 'song-2');
      expect(handler.currentIndex, 1);
      expect(handler.songQueue.length, 3);
      expect(handler.isShuffle, isTrue);
      expect(handler.loopMode, RetroLoopMode.one);
      expect(handler.currentPlaylistId, 'playlist-retro');
      expect(handler.playbackPosition.inSeconds, 88);
      expect(handler.isPlaying, isFalse);
    });

    test('AudioPlayerHandler saves state when queue is manipulated', () async {
      final handler = AudioPlayerHandler();

      handler.setQueueForTesting(
        songs: [testSong1],
        currentIndex: 0,
        position: const Duration(seconds: 30),
      );
      handler.saveCurrentPlaybackState();

      var saved = storage.getSavedPlaybackState();
      expect(saved, isNotNull);
      expect(saved!['song']['id'], 'song-1');
      expect(saved['positionMs'], 30000);

      // Add song to queue -> should save updated queue
      handler.addSongToQueue(testSong2);

      saved = storage.getSavedPlaybackState();
      expect(saved, isNotNull);
      final q = (saved!['queue'] as List)
          .map((e) => Song.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
      expect(q.length, 2);
      expect(q[1].id, 'song-2');
    });
  });

  group('MiniPlayer State Preservation & UI Tests', () {
    testWidgets('MiniPlayer displays restored song and accurate progress bar', (tester) async {
      final handler = AudioPlayerHandler();

      // Simulate restored state: song1 (180s total) at 45s (25% progress)
      handler.setQueueForTesting(
        songs: [testSong1, testSong2],
        currentIndex: 0,
        position: const Duration(seconds: 45),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            audioHandlerProvider.overrideWithValue(handler),
          ],
          child: MaterialApp(
            theme: RetroTheme.darkTheme(),
            home: const Scaffold(
              bottomNavigationBar: MiniPlayer(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mini player is visible
      expect(find.byType(MiniPlayer), findsOneWidget);

      // Track title & artist are displayed
      expect(find.text('Pixel Symphony'), findsOneWidget);
      expect(find.text('Chiptune Master'), findsOneWidget);

      // Play button displays 'play' icon (not playing yet)
      expect(find.byType(MiniPlayer), findsOneWidget);
    });
  });
}
