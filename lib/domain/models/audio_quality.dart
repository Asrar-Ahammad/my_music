/// Audio quality tiers based on digital audio engineering standards
enum AudioQualityTier {
  hiRes, // >= 24-bit or > 48kHz (Studio Master / Ultra HD)
  lossless, // 16-bit / 44.1-48kHz bit-perfect lossless (CD Quality)
  highQuality, // >= 256 kbps lossy (Transparent high bitrate)
  standard, // 128 - 255 kbps lossy
  low, // < 128 kbps lossy
}

/// Audio quality metadata model for displaying fidelity badges & specs
class AudioQuality {
  final String format; // FLAC, WAV, MP3, AAC, ALAC, E-AC3, AC-4
  final int bitDepth; // 16, 24, 32
  final int sampleRate; // 44100, 48000, 96000, 192000
  final int bitrateKbps; // e.g. 320, 1411, 4608
  final bool isDolbyAtmos;
  final bool isSpatialAudio;
  final int channels;

  const AudioQuality({
    required this.format,
    this.bitDepth = 16,
    this.sampleRate = 44100,
    this.bitrateKbps = 320,
    this.isDolbyAtmos = false,
    this.isSpatialAudio = false,
    this.channels = 2,
  });

  /// Hi-Res audio is defined as bit depth >= 24-bit or sample rate > 48 kHz
  bool get isHiRes => bitDepth >= 24 || sampleRate > 48000;

  /// Lossless audio preserves 100% of the original audio waveform (e.g. FLAC, WAV, ALAC, AIFF)
  bool get isLossless {
    final fmt = format.toUpperCase();
    return fmt.contains('FLAC') ||
        fmt.contains('WAV') ||
        fmt.contains('ALAC') ||
        fmt.contains('AIFF') ||
        fmt.contains('APE') ||
        fmt.contains('PCM') ||
        isHiRes;
  }

  /// High Quality indicates audibly transparent lossy compression (>= 256 kbps, e.g. 320 kbps MP3 or 256 kbps AAC)
  bool get isHighQuality => !isHiRes && !isLossless && bitrateKbps >= 256;

  /// Determine the standardized quality tier
  AudioQualityTier get qualityTier {
    if (isHiRes) return AudioQualityTier.hiRes;
    if (isLossless) return AudioQualityTier.lossless;
    if (bitrateKbps >= 256) return AudioQualityTier.highQuality;
    if (bitrateKbps >= 128) return AudioQualityTier.standard;
    return AudioQualityTier.low;
  }

  /// User-facing label for the quality tier
  String get tierLabel {
    switch (qualityTier) {
      case AudioQualityTier.hiRes:
        return 'HI-RES';
      case AudioQualityTier.lossless:
        return 'LOSSLESS';
      case AudioQualityTier.highQuality:
        return 'HQ';
      case AudioQualityTier.standard:
        return 'STANDARD';
      case AudioQualityTier.low:
        return 'LOW';
    }
  }

  String get sampleRateKhz {
    final khz = sampleRate / 1000.0;
    return khz == khz.roundToDouble()
        ? '${khz.toInt()}kHz'
        : '${khz.toStringAsFixed(1)}kHz';
  }

  /// Whether the track is multi-channel surround sound
  bool get isSurround => channels > 2;

  /// Channel layout descriptor (STEREO, 5.1 SURROUND, 7.1 SURROUND, etc.)
  String get channelLayout {
    if (channels == 6) return '5.1 SURROUND';
    if (channels == 8) return '7.1 SURROUND';
    if (channels > 2) return '$channels CH';
    return 'STEREO';
  }

  /// Compact quality and bitrate badge text for retro song cards & tiles (e.g. [HQ 320k], [LOSSLESS], [24-BIT 96kHz], [ATMOS])
  String get qualityBadge {
    if (isDolbyAtmos) {
      return 'ATMOS';
    }
    if (isSpatialAudio) {
      return 'SPATIAL';
    }
    if (isHiRes) {
      return '$bitDepth-BIT $sampleRateKhz';
    }
    if (isLossless) {
      return 'LOSSLESS';
    }
    if (bitrateKbps >= 256) {
      return 'HQ ${bitrateKbps}k';
    }
    if (bitrateKbps > 0) {
      return '$bitrateKbps kbps';
    }
    return sampleRateKhz;
  }

  /// Informative badge text emphasizing audio fidelity tier, bitrate, and sample rate
  String get badgeText {
    if (isDolbyAtmos) {
      return 'DOLBY ATMOS • $channelLayout';
    }
    if (isSpatialAudio) {
      return 'SPATIAL 3D • $channelLayout';
    }
    if (isHiRes) {
      return 'HI-RES • $bitDepth-BIT $sampleRateKhz';
    }
    if (isLossless) {
      final br = bitrateKbps > 0 ? ' • ${bitrateKbps}kbps' : '';
      return 'LOSSLESS$br';
    }
    if (bitrateKbps >= 256) {
      return 'HQ • ${bitrateKbps}kbps';
    }
    if (bitrateKbps > 0) {
      return '$bitrateKbps kbps • $sampleRateKhz';
    }
    return sampleRateKhz;
  }

  /// Detailed specs string for settings/now-playing
  String get fullSpecs {
    final khz = (sampleRate / 1000.0).toStringAsFixed(1);
    final br = bitrateKbps > 0 ? ' • ${bitrateKbps}kbps' : '';
    final spatialTag = isDolbyAtmos ? ' • DOLBY ATMOS' : (isSpatialAudio ? ' • SPATIAL 3D' : '');
    final chTag = channels > 2 ? ' • $channelLayout' : '';
    final tier = isHiRes
        ? 'HI-RES LOSSLESS'
        : (isLossless ? 'LOSSLESS (CD QUALITY)' : (isHighQuality ? 'HIGH QUALITY' : 'STANDARD'));
    return '$tier • $bitDepth-bit • $khz kHz$br • $format$spatialTag$chTag';
  }

  Map<String, dynamic> toMap() => {
        'format': format,
        'bitDepth': bitDepth,
        'sampleRate': sampleRate,
        'bitrateKbps': bitrateKbps,
        'isDolbyAtmos': isDolbyAtmos,
        'isSpatialAudio': isSpatialAudio,
        'channels': channels,
      };

  factory AudioQuality.fromMap(Map<String, dynamic> map) {
    return AudioQuality(
      format: (map['format'] as String?) ?? 'MP3',
      bitDepth: (map['bitDepth'] as int?) ?? 16,
      sampleRate: (map['sampleRate'] as int?) ?? 44100,
      bitrateKbps: (map['bitrateKbps'] as int?) ?? 320,
      isDolbyAtmos: (map['isDolbyAtmos'] as bool?) ?? false,
      isSpatialAudio: (map['isSpatialAudio'] as bool?) ?? false,
      channels: (map['channels'] as int?) ?? 2,
    );
  }
}
