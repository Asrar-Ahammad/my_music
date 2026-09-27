import 'dart:io';
import 'dart:typed_data';
import '../../domain/models/audio_quality.dart';

/// Parses audio headers or file attributes to extract genuine audio quality details.
class AudioInfoParser {
  AudioInfoParser._();

  static Future<AudioQuality> parseFileQuality(
    String filePath, {
    int? parsedBitrate,
    int? parsedSampleRate,
    Duration? duration,
  }) async {
    final lower = filePath.toLowerCase();
    final ext = lower.split('.').last;

    int sampleRate = parsedSampleRate ?? 44100;
    int bitDepth = 16;
    int bitrateKbps = 0;

    if (parsedBitrate != null && parsedBitrate > 0) {
      bitrateKbps = parsedBitrate > 1000 ? (parsedBitrate / 1000).round() : parsedBitrate;
    }

    final isDolbyAtmos = lower.contains('atmos') ||
        lower.contains('eac3') ||
        lower.contains('ec-3') ||
        lower.contains('e-ac3') ||
        ext == 'eac3' ||
        ext == 'ec3';
    final isSpatial = isDolbyAtmos ||
        lower.contains('spatial') ||
        lower.contains('3d') ||
        lower.contains('binaural') ||
        lower.contains('surround') ||
        lower.contains('5.1') ||
        lower.contains('7.1');
    final channels = (lower.contains('7.1') || lower.contains('8ch'))
        ? 8
        : ((lower.contains('5.1') || lower.contains('6ch') || isDolbyAtmos) ? 6 : 2);

    if (ext == 'wav') {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final raf = await file.open(mode: FileMode.read);
          final header = await raf.read(44);
          await raf.close();

          if (header.length >= 44) {
            final bd = ByteData.sublistView(Uint8List.fromList(header));
            // Check RIFF and WAVE
            final isRiff = header[0] == 82 && header[1] == 73 && header[2] == 70 && header[3] == 70;
            if (isRiff) {
              final sr = bd.getUint32(24, Endian.little);
              final byteRate = bd.getUint32(28, Endian.little);
              final bitsPerSample = bd.getUint16(34, Endian.little);

              if (sr > 0) sampleRate = sr;
              if (bitsPerSample > 0) bitDepth = bitsPerSample;
              if (byteRate > 0 && bitrateKbps == 0) {
                bitrateKbps = (byteRate * 8 ~/ 1000);
              }
            }
          }
        }
      } catch (_) {}
      if (bitrateKbps == 0) {
        bitrateKbps = bitDepth == 24 ? 4608 : 1411;
      }
      return AudioQuality(
        format: 'WAV',
        bitDepth: bitDepth,
        sampleRate: sampleRate,
        bitrateKbps: bitrateKbps,
        isDolbyAtmos: isDolbyAtmos,
        isSpatialAudio: isSpatial,
        channels: channels,
      );
    } else if (ext == 'flac') {
      try {
        final file = File(filePath);
        if (await file.exists()) {
          final raf = await file.open(mode: FileMode.read);
          // FLAC STREAMINFO header is at offset 4 to 26
          final header = await raf.read(26);
          await raf.close();

          if (header.length >= 22 &&
              header[0] == 0x66 &&
              header[1] == 0x4C &&
              header[2] == 0x61 &&
              header[3] == 0x43) {
            final b18 = header[18];
            final b19 = header[19];
            final b20 = header[20];
            final b21 = header[21];

            final sr = (b18 << 12) | (b19 << 4) | (b20 >> 4);
            final bps = (((b20 & 0x01) << 4) | (b21 >> 4)) + 1;

            if (sr > 0) sampleRate = sr;
            if (bps > 0) bitDepth = bps;
          }
        }
      } catch (_) {}

      if (lower.contains('24bit') || lower.contains('96k') || lower.contains('192k') || lower.contains('hi_res')) {
        if (bitDepth < 24) bitDepth = 24;
        if (sampleRate < 96000) sampleRate = 96000;
      }

      // If bitrateKbps was not found, calculate from file size & duration or estimate
      if (bitrateKbps == 0 && duration != null && duration > Duration.zero) {
        try {
          final file = File(filePath);
          final size = await file.length();
          final sec = duration.inMilliseconds / 1000.0;
          if (sec > 0) {
            bitrateKbps = (size * 8 / sec / 1000).round();
          }
        } catch (_) {}
      }
      if (bitrateKbps == 0) {
        bitrateKbps = bitDepth >= 24 ? 4608 : 900;
      }

      return AudioQuality(
        format: 'FLAC',
        bitDepth: bitDepth,
        sampleRate: sampleRate,
        bitrateKbps: bitrateKbps,
        isDolbyAtmos: isDolbyAtmos,
        isSpatialAudio: isSpatial,
        channels: channels,
      );
    } else if (ext == 'ac3' || ext == 'eac3' || ext == 'ec3') {
      if (bitrateKbps == 0 && duration != null && duration > Duration.zero) {
        try {
          final file = File(filePath);
          final size = await file.length();
          final sec = duration.inMilliseconds / 1000.0;
          if (sec > 0) {
            bitrateKbps = (size * 8 / sec / 1000).round();
          }
        } catch (_) {}
      }
      if (bitrateKbps == 0) bitrateKbps = ext == 'ac3' ? 640 : 768;

      return AudioQuality(
        format: ext == 'ac3' ? 'AC-3' : 'E-AC-3',
        bitDepth: 24,
        sampleRate: sampleRate,
        bitrateKbps: bitrateKbps,
        isDolbyAtmos: isDolbyAtmos || ext == 'eac3' || ext == 'ec3',
        isSpatialAudio: true,
        channels: channels,
      );
    } else if (ext == 'aac' || ext == 'm4a') {
      if (bitrateKbps == 0 && duration != null && duration > Duration.zero) {
        try {
          final file = File(filePath);
          final size = await file.length();
          final sec = duration.inMilliseconds / 1000.0;
          if (sec > 0) {
            bitrateKbps = (size * 8 / sec / 1000).round();
          }
        } catch (_) {}
      }
      if (bitrateKbps == 0) bitrateKbps = 256;

      return AudioQuality(
        format: ext.toUpperCase(),
        bitDepth: 16,
        sampleRate: sampleRate,
        bitrateKbps: bitrateKbps,
        isDolbyAtmos: isDolbyAtmos,
        isSpatialAudio: isSpatial,
        channels: channels,
      );
    } else {
      // MP3 or other formats
      if (bitrateKbps == 0 && duration != null && duration > Duration.zero) {
        try {
          final file = File(filePath);
          final size = await file.length();
          final sec = duration.inMilliseconds / 1000.0;
          if (sec > 0) {
            bitrateKbps = (size * 8 / sec / 1000).round();
          }
        } catch (_) {}
      }
      if (bitrateKbps == 0) bitrateKbps = 320;

      return AudioQuality(
        format: ext.toUpperCase(),
        bitDepth: 16,
        sampleRate: sampleRate,
        bitrateKbps: bitrateKbps,
        isDolbyAtmos: isDolbyAtmos,
        isSpatialAudio: isSpatial,
        channels: channels,
      );
    }
  }

  /// Resolve quality for bundled assets
  static AudioQuality parseAssetQuality(String assetPath) {
    final lower = assetPath.toLowerCase();
    if (lower.contains('hi_res') || lower.contains('96')) {
      return const AudioQuality(
        format: 'FLAC',
        bitDepth: 24,
        sampleRate: 96000,
        bitrateKbps: 4608,
      );
    }
    if (lower.contains('atmos') || lower.contains('eac3')) {
      return const AudioQuality(
        format: 'E-AC-3',
        bitDepth: 24,
        sampleRate: 48000,
        bitrateKbps: 768,
        isDolbyAtmos: true,
        isSpatialAudio: true,
        channels: 6,
      );
    }
    if (lower.endsWith('.wav')) {
      return const AudioQuality(
        format: 'WAV',
        bitDepth: 16,
        sampleRate: 48000,
        bitrateKbps: 1536,
      );
    }
    return const AudioQuality(
      format: 'MP3',
      bitDepth: 16,
      sampleRate: 44100,
      bitrateKbps: 320,
    );
  }
}
