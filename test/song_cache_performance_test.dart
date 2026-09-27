import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/data/repositories/audio_repository.dart';
import 'package:my_music/data/services/file_scanner_service.dart';
import 'package:my_music/data/services/storage_service.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late StorageService storageService;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('song_cache_test_');
    storageService = StorageService();
    await storageService.clearCachedSongs();
  });

  tearDown(() async {
    await storageService.clearCachedSongs();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Persistent Song Cache & StorageService Tests', () {
    test('StorageService saves, retrieves, and clears cached song entries', () async {
      const song1 = Song(
        id: 'file_1',
        title: 'Retro Pulse',
        artist: '8-Bit Hero',
        album: 'Cyber Zone',
        duration: Duration(seconds: 120),
        uri: '/music/song1.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100, bitrateKbps: 320),
        folderPath: '/music',
      );

      final entries = {
        song1.uri: {
          'song': song1.toMap(),
          'mtime': 1700000000000,
          'size': 5000000,
        },
      };

      await storageService.saveCachedSongEntries(entries);

      final cached = storageService.getCachedSongEntries();
      expect(cached.containsKey(song1.uri), isTrue);
      expect(cached[song1.uri]!['mtime'], equals(1700000000000));
      expect(cached[song1.uri]!['size'], equals(5000000));

      final restoredSong = Song.fromMap(Map<String, dynamic>.from(cached[song1.uri]!['song'] as Map));
      expect(restoredSong.id, equals(song1.id));
      expect(restoredSong.title, equals('Retro Pulse'));
      expect(restoredSong.artist, equals('8-Bit Hero'));

      await storageService.removeCachedSongEntries([song1.uri]);
      expect(storageService.getCachedSongEntries().containsKey(song1.uri), isFalse);
    });
  });

  group('FileScannerService Incremental Scanning Tests', () {
    test('Reuses cached song metadata on rescan without re-reading file when mtime and size match', () async {
      // Create a test audio file
      final audioFile = File('${tempDir.path}/Test Track.mp3');
      await audioFile.writeAsBytes(List.filled(1024, 0));

      final scanner = FileScannerService(storageService: storageService);

      // First scan: parses file and saves to cache
      final firstScan = await scanner.scanDirectory(tempDir.path);
      expect(firstScan.length, equals(1));
      expect(firstScan.first.uri, equals(audioFile.path));

      final cachedEntriesAfterFirstScan = storageService.getCachedSongEntries();
      expect(cachedEntriesAfterFirstScan.containsKey(audioFile.path), isTrue);

      // Modify the cached title in storage to verify that second scan uses cache rather than reading disk
      final cachedEntry = Map<String, dynamic>.from(cachedEntriesAfterFirstScan[audioFile.path]!);
      final cachedSongMap = Map<String, dynamic>.from(cachedEntry['song'] as Map);
      cachedSongMap['title'] = 'Cached Fast Title';
      cachedEntry['song'] = cachedSongMap;
      await storageService.saveCachedSongEntries({audioFile.path: cachedEntry});

      // Second scan: mtime & size match -> MUST return cached entry with 'Cached Fast Title'
      final secondScan = await scanner.scanDirectory(tempDir.path);
      expect(secondScan.length, equals(1));
      expect(secondScan.first.title, equals('Cached Fast Title'));
    });

    test('Detects modified file when mtime changes and refreshes metadata', () async {
      final audioFile = File('${tempDir.path}/Artist - Dynamic Track.mp3');
      await audioFile.writeAsBytes(List.filled(2048, 0));

      final scanner = FileScannerService(storageService: storageService);

      final firstScan = await scanner.scanDirectory(tempDir.path);
      expect(firstScan.length, equals(1));

      // Overwrite file with new content & updated timestamp
      await Future.delayed(const Duration(milliseconds: 50));
      await audioFile.writeAsBytes(List.filled(4096, 1));

      // Second scan detects updated size / mtime and re-evaluates
      final secondScan = await scanner.scanDirectory(tempDir.path);
      expect(secondScan.length, equals(1));

      final updatedCache = storageService.getCachedSongEntries();
      expect(updatedCache[audioFile.path]!['size'], equals(4096));
    });

    test('Handles batch parallel scanning of multiple files correctly', () async {
      final filePaths = <String>[];
      for (int i = 1; i <= 25; i++) {
        final f = File('${tempDir.path}/Track $i.mp3');
        await f.writeAsBytes(List.filled(512, i));
        filePaths.add(f.path);
      }

      final scanner = FileScannerService(storageService: storageService);
      final songs = await scanner.scanFiles(filePaths);

      expect(songs.length, equals(25));
      final cachedEntries = storageService.getCachedSongEntries();
      expect(cachedEntries.length, equals(25));
    });
  });

  group('AudioRepository Cache & Pruning Tests', () {
    test('loadLibrary prunes dead cache entries for deleted audio files', () async {
      final audioFile = File('${tempDir.path}/Temporary Track.mp3');
      await audioFile.writeAsBytes(List.filled(1024, 0));

      await storageService.saveScanFolders([tempDir.path]);

      final repo = AudioRepository(
        scannerService: FileScannerService(storageService: storageService),
        storageService: storageService,
      );

      final initialSongs = await repo.loadLibrary();
      expect(initialSongs.any((s) => s.uri == audioFile.path), isTrue);
      expect(storageService.getCachedSongEntries().containsKey(audioFile.path), isTrue);

      // Delete the file
      await audioFile.delete();

      // Rescan library
      final updatedSongs = await repo.loadLibrary();
      expect(updatedSongs.any((s) => s.uri == audioFile.path), isFalse);

      // Dead cache entry must be pruned
      expect(storageService.getCachedSongEntries().containsKey(audioFile.path), isFalse);
    });

    test('getCachedSongs returns immediately available songs before scanning', () async {
      const song1 = Song(
        id: 'file_cached_1',
        title: 'Instant Play Track',
        artist: 'Neon Wave',
        album: 'Fast Audio',
        duration: Duration(seconds: 180),
        uri: '/mock/path/song.mp3',
        quality: AudioQuality(format: 'MP3', bitDepth: 16, sampleRate: 44100, bitrateKbps: 320),
      );

      await storageService.saveCachedSongEntries({
        song1.uri: {
          'song': song1.toMap(),
          'mtime': 123456,
          'size': 7890,
        },
      });

      final repo = AudioRepository(
        scannerService: FileScannerService(storageService: storageService),
        storageService: storageService,
      );

      final cachedSongs = repo.getCachedSongs();
      // Should include bundled tracks + our cached track
      expect(cachedSongs.any((s) => s.id == 'file_cached_1'), isTrue);
      expect(cachedSongs.firstWhere((s) => s.id == 'file_cached_1').title, equals('Instant Play Track'));
    });
  });
}
