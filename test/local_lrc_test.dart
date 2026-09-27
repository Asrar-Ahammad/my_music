import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/data/repositories/settings_repository.dart';
import 'package:my_music/data/services/file_scanner_service.dart';
import 'package:my_music/data/services/lyrics_service.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';

class MockSettingsRepositoryWithLrc extends SettingsRepository {
  String? lrcFolder;
  bool onlineEnabled = false;

  MockSettingsRepositoryWithLrc(this.lrcFolder);

  @override
  String? getLocalLrcFolderPath() => lrcFolder;

  @override
  bool isOnlineLyricsEnabled() => onlineEnabled;

  @override
  bool isPrioritizeSyllableLyrics() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('myMusic_lrc_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  const testSong = Song(
    id: 'sample_01',
    title: 'Chiptune Quest',
    artist: 'Pixel Audio',
    album: '8-Bit Adventures',
    duration: Duration(seconds: 30),
    uri: 'assets/audio/chiptune_quest.wav',
    quality: AudioQuality(format: 'WAV', bitDepth: 16, sampleRate: 44100),
  );

  const lrcBody = '''[00:01.00]First verse in pixel town
[00:05.50]Quest has just begun
[00:10.00]Victory fanfare plays
''';

  group('Local LRC Folder Offline Loading Tests', () {
    test('Loads LRC file matching title directly (Chiptune Quest.lrc) in offline mode', () async {
      final lrcFile = File('${tempDir.path}/Chiptune Quest.lrc');
      await lrcFile.writeAsString(lrcBody);

      final repo = MockSettingsRepositoryWithLrc(tempDir.path);
      final service = LyricsService(settingsRepository: repo);

      final result = await service.getLyrics(testSong);
      expect(result, isNotNull);
      expect(result!.sourceName, equals('LOCAL FOLDER'));
      expect(result.document.lines.length, equals(3));
      expect(result.document.lines[0].text, equals('First verse in pixel town'));
    });

    test('Loads LRC file matching audio file basename with underscores (chiptune_quest.lrc)', () async {
      final lrcFile = File('${tempDir.path}/chiptune_quest.lrc');
      await lrcFile.writeAsString(lrcBody);

      final repo = MockSettingsRepositoryWithLrc(tempDir.path);
      final service = LyricsService(settingsRepository: repo);

      final result = await service.getLyrics(testSong);
      expect(result, isNotNull);
      expect(result!.sourceName, equals('LOCAL FOLDER'));
      expect(result.document.lines.first.text, equals('First verse in pixel town'));
    });

    test('Loads LRC file matching Artist - Title (Pixel Audio - Chiptune Quest.lrc)', () async {
      final lrcFile = File('${tempDir.path}/Pixel Audio - Chiptune Quest.lrc');
      await lrcFile.writeAsString(lrcBody);

      final repo = MockSettingsRepositoryWithLrc(tempDir.path);
      final service = LyricsService(settingsRepository: repo);

      final result = await service.getLyrics(testSong);
      expect(result, isNotNull);
      expect(result!.sourceName, equals('LOCAL FOLDER'));
    });

    test('Loads LRC file inside a nested subfolder', () async {
      final subDir = Directory('${tempDir.path}/Pixel Audio/2026');
      await subDir.create(recursive: true);
      final lrcFile = File('${subDir.path}/Chiptune Quest.lrc');
      await lrcFile.writeAsString(lrcBody);

      final repo = MockSettingsRepositoryWithLrc(tempDir.path);
      final service = LyricsService(settingsRepository: repo);

      final result = await service.getLyrics(testSong);
      expect(result, isNotNull);
      expect(result!.sourceName, equals('LOCAL FOLDER'));
    });

    test('Loads LRC file containing UTF-8 BOM bytes without error', () async {
      final lrcFile = File('${tempDir.path}/Chiptune Quest.lrc');
      final bomBytes = [0xEF, 0xBB, 0xBF, ...lrcBody.codeUnits];
      await lrcFile.writeAsBytes(bomBytes);

      final repo = MockSettingsRepositoryWithLrc(tempDir.path);
      final service = LyricsService(settingsRepository: repo);

      final result = await service.getLyrics(testSong);
      expect(result, isNotNull);
      expect(result!.document.lines.first.text, equals('First verse in pixel town'));
    });

    test('Loads LRC file with track number prefix (01. Chiptune Quest.lrc)', () async {
      final lrcFile = File('${tempDir.path}/01. Chiptune Quest.lrc');
      await lrcFile.writeAsString(lrcBody);

      final repo = MockSettingsRepositoryWithLrc(tempDir.path);
      final service = LyricsService(settingsRepository: repo);

      final result = await service.getLyrics(testSong);
      expect(result, isNotNull);
      expect(result!.sourceName, equals('LOCAL FOLDER'));
    });

    test('Loads from local folder even when online lyrics setting is ON but internet is offline', () async {
      final lrcFile = File('${tempDir.path}/Chiptune Quest.lrc');
      await lrcFile.writeAsString(lrcBody);

      // Default setting is online lyrics enabled = true
      final repo = MockSettingsRepositoryWithLrc(tempDir.path)..onlineEnabled = true;
      final service = LyricsService(settingsRepository: repo);

      final result = await service.getLyrics(testSong);
      expect(result, isNotNull);
      expect(result!.sourceName, equals('LOCAL FOLDER'));
      expect(result.document.lines.length, equals(3));
    });

    test('Normalizes SAF content path correctly to POSIX path', () {
      const rawSaf = 'content://com.android.externalstorage.documents/tree/primary%3AMusic%2FLrc';
      final normalized = FileScannerService.normalizeFolderPath(rawSaf);
      expect(normalized, equals('/storage/emulated/0/Music/Lrc'));
    });
  });
}
