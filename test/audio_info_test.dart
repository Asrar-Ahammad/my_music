import 'package:flutter_test/flutter_test.dart';
import 'package:my_music/core/utils/audio_info_parser.dart';
import 'package:my_music/core/utils/duration_formatter.dart';
import 'package:my_music/data/services/file_scanner_service.dart';

void main() {
  group('Audio Info & Duration Utilities', () {
    test('DurationFormatter formats timestamps correctly', () {
      expect(DurationFormatter.format(null), equals('00:00'));
      expect(DurationFormatter.format(const Duration(seconds: 0)), equals('00:00'));
      expect(DurationFormatter.format(const Duration(seconds: 45)), equals('00:45'));
      expect(DurationFormatter.format(const Duration(minutes: 3, seconds: 12)), equals('03:12'));
      expect(DurationFormatter.format(const Duration(hours: 1, minutes: 2, seconds: 5)), equals('01:02:05'));
    });

    test('AudioInfoParser resolves bundled audio qualities', () {
      final hiResQuality = AudioInfoParser.parseAssetQuality('assets/audio/neon_dungeon_hi_res.wav');
      expect(hiResQuality.bitDepth, equals(24));
      expect(hiResQuality.sampleRate, equals(96000));
      expect(hiResQuality.isHiRes, isTrue);

      final arcadeQuality = AudioInfoParser.parseAssetQuality('assets/audio/arcade_rush.wav');
      expect(arcadeQuality.sampleRate, equals(48000));
      expect(arcadeQuality.bitDepth, equals(16));
    });

    test('FileScannerService.normalizeFolderPath normalizes Android SAF URIs', () {
      expect(
        FileScannerService.normalizeFolderPath('content://com.android.externalstorage.documents/tree/primary%3AMusic'),
        equals('/storage/emulated/0/Music'),
      );
      expect(
        FileScannerService.normalizeFolderPath('/tree/primary:Download/MySongs'),
        equals('/storage/emulated/0/Download/MySongs'),
      );
      expect(
        FileScannerService.normalizeFolderPath('primary:Music/Favorites/'),
        equals('/storage/emulated/0/Music/Favorites'),
      );
      expect(
        FileScannerService.normalizeFolderPath('/storage/emulated/0/Music'),
        equals('/storage/emulated/0/Music'),
      );
    });
  });
}
