import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:my_music/core/theme/monet_engine.dart';
import 'package:my_music/domain/models/audio_quality.dart';
import 'package:my_music/domain/models/song.dart';

void main() {
  group('AndroidMonetEngine Tests', () {
    test('derives deterministic HCT seed and generates Monet color scheme', () {
      const song = Song(
        id: 'monet-song-1',
        title: 'Retro Highway',
        artist: 'Chiptune Hero',
        album: '8-Bit Dreams',
        duration: Duration(seconds: 180),
        uri: 'file:///music/retro.mp3',
        quality: AudioQuality(format: 'MP3'),
      );

      final darkColor = AndroidMonetEngine.getLyricsHighlightColor(
        song: song,
        isDark: true,
      );
      final lightColor = AndroidMonetEngine.getLyricsHighlightColor(
        song: song,
        isDark: false,
      );

      expect(darkColor, isNotNull);
      expect(lightColor, isNotNull);
      expect(darkColor, isNot(equals(lightColor)));

      // Consistent seed reproduction
      final darkColorAgain = AndroidMonetEngine.getLyricsHighlightColor(
        song: song,
        isDark: true,
      );
      expect(darkColor, equals(darkColorAgain));
    });

    test('generates Monet border color blended with default border', () {
      const song = Song(
        id: 'monet-song-2',
        title: 'Cyber City',
        artist: 'Pixel Wave',
        album: 'Synth Nights',
        duration: Duration(seconds: 210),
        uri: 'file:///music/cyber.mp3',
        quality: AudioQuality(format: 'FLAC', bitDepth: 24, sampleRate: 96000),
      );

      const defaultBorder = Color(0xFF2C2824);
      final borderColor = AndroidMonetEngine.getLyricsBorderColor(
        song: song,
        defaultBorderColor: defaultBorder,
        isDark: true,
      );

      expect(borderColor, isNotNull);
    });

    test('QuantizerCelebi and Score work seamlessly for Monet extraction', () async {
      final pixels = [0xFF112233, 0xFF445566, 0xFF445566, 0xFFAABBCC];
      final result = await QuantizerCelebi().quantize(pixels, 16);
      expect(result.colorToCount, isNotEmpty);

      final scored = Score.score(result.colorToCount);
      expect(scored, isNotEmpty);
      expect(scored.first, isNotNull);
    });
  });
}
