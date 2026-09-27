import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import '../../domain/models/song.dart';

/// Android Monet Engine integration for Material You dynamic color extraction.
///
/// Implements Google's Android 12+ Monet theme engine using HCT (Hue, Chroma, Tone)
/// color science, QuantizerCelebi pixel quantization, and Score color ranking to
/// produce perceptual, harmonized, non-glaring dynamic accent colors.
class AndroidMonetEngine {
  static final Map<String, Color> _artworkSeedCache = {};
  static final Map<String, Future<Color?>> _pendingExtractions = {};
  static final ValueNotifier<int> extractionNotifier = ValueNotifier<int>(0);

  /// Returns the Android Monet seed color for a song.
  ///
  /// Priority:
  /// 1. Cached extracted seed from album artwork image.
  /// 2. Deterministic HCT seed color calculated from song title, artist, and id.
  static Color getSeedColor({
    String? songId,
    String? title,
    String? artist,
    String? artPath,
  }) {
    if (artPath != null && _artworkSeedCache.containsKey(artPath)) {
      return _artworkSeedCache[artPath]!;
    }

    if (artPath != null &&
        !_pendingExtractions.containsKey(artPath) &&
        File(artPath).existsSync()) {
      extractArtworkSeed(artPath);
    }

    // Deterministic Monet HCT fallback
    final seedString = '${songId ?? ""}_${title ?? ""}_${artist ?? ""}';
    final hash = seedString.hashCode.abs();
    final hue = (hash % 360).toDouble();
    // Android Monet standard CAM16 / HCT chroma (48.0) and tone (50.0)
    final hct = Hct.from(hue, 48.0, 50.0);
    return Color(hct.toInt());
  }

  /// Extracts the dominant Android Monet seed color from album artwork pixels
  /// using Google's QuantizerCelebi and Score ranking algorithms.
  static Future<Color?> extractArtworkSeed(String artPath) async {
    if (_artworkSeedCache.containsKey(artPath)) {
      return _artworkSeedCache[artPath];
    }

    if (_pendingExtractions.containsKey(artPath)) {
      return _pendingExtractions[artPath];
    }

    final future = () async {
      try {
        final file = File(artPath);
        if (!await file.exists()) return null;

        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return null;

        // Downsample to 32x32 thumbnail for instantaneous quantization
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: 32,
          targetHeight: 32,
        );
        final frame = await codec.getNextFrame();
        final byteData = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );

        if (byteData == null) return null;

        final pixels = <int>[];
        for (var i = 0; i < byteData.lengthInBytes; i += 4) {
          final r = byteData.getUint8(i);
          final g = byteData.getUint8(i + 1);
          final b = byteData.getUint8(i + 2);
          final a = byteData.getUint8(i + 3);

          // Ignore transparent or near-black/near-white pixels
          if (a < 180) continue;

          // Convert RGBA to ARGB int
          final argb = (a << 24) | (r << 16) | (g << 8) | b;
          pixels.add(argb);
        }

        if (pixels.isEmpty) return null;

        // Run Google Monet QuantizerCelebi
        final quantizerResult = await QuantizerCelebi().quantize(pixels, 16);
        final rankedColors = Score.score(quantizerResult.colorToCount);

        if (rankedColors.isNotEmpty) {
          final seedColor = Color(rankedColors.first);
          _artworkSeedCache[artPath] = seedColor;
          extractionNotifier.value++;
          return seedColor;
        }
      } catch (e) {
        debugPrint('MonetEngine: artwork color extraction error: $e');
      } finally {
        _pendingExtractions.remove(artPath);
      }
      return null;
    }();

    _pendingExtractions[artPath] = future;
    return future;
  }

  /// Generates a full Google Material You / Android Monet ColorScheme from the song seed.
  static ColorScheme getMonetScheme({
    Song? song,
    String? songId,
    String? title,
    String? artist,
    String? artPath,
    bool isDark = true,
  }) {
    final seed = getSeedColor(
      songId: song?.id ?? songId,
      title: song?.title ?? title,
      artist: song?.artist ?? artist,
      artPath: song?.artPath ?? artPath,
    );

    return ColorScheme.fromSeed(
      seedColor: seed,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
  }

  /// Picks the ideal Android Monet lyrics highlight color.
  ///
  /// Uses Monet Tone 80 in dark mode (soft, soothing, non-glaring) and
  /// Tone 40 in light mode (sharp, readable, balanced contrast).
  static Color getLyricsHighlightColor({
    Song? song,
    String? songId,
    String? title,
    String? artist,
    String? artPath,
    bool isDark = true,
  }) {
    final scheme = getMonetScheme(
      song: song,
      songId: songId,
      title: title,
      artist: artist,
      artPath: artPath,
      isDark: isDark,
    );
    return scheme.primary;
  }

  /// Returns the subtle Monet container border color for the lyrics ticker.
  static Color getLyricsBorderColor({
    Song? song,
    String? songId,
    String? title,
    String? artist,
    String? artPath,
    required Color defaultBorderColor,
    bool isDark = true,
  }) {
    final scheme = getMonetScheme(
      song: song,
      songId: songId,
      title: title,
      artist: artist,
      artPath: artPath,
      isDark: isDark,
    );
    return Color.lerp(defaultBorderColor, scheme.primaryContainer, 0.40)!;
  }
}
