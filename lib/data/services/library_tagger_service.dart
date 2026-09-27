import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../domain/models/ai_song_tags.dart';
import '../../domain/models/song.dart';
import 'storage_service.dart';

/// Payload for the background isolate DSP analysis.
class _TaggerPayload {
  final String filePath;
  final Duration duration;
  const _TaggerPayload(this.filePath, this.duration);
}

/// Result from the background isolate analysis.
class _RawTaggerResult {
  final double rmsEnergy;        // 0.0–1.0
  final double zeroCrossingRate; // 0.0–1.0  (high = high-freq content)
  final double midEnergy;        // energy in mid-file 5s window
  final int estimatedBpm;
  const _RawTaggerResult({
    required this.rmsEnergy,
    required this.zeroCrossingRate,
    required this.midEnergy,
    required this.estimatedBpm,
  });
}

/// State snapshot emitted during a library scan.
class LibraryTaggerScanProgress {
  final int scanned;
  final int total;
  final String? currentSongTitle;
  final bool isComplete;
  final String? error;

  const LibraryTaggerScanProgress({
    required this.scanned,
    required this.total,
    this.currentSongTitle,
    this.isComplete = false,
    this.error,
  });
}

/// Pure-Dart heuristic library tagger.
///
/// Analyses a 5-second PCM window from the middle of each audio file using
/// windowed RMS energy and zero-crossing rate to classify:
///   - Mood:        Chill | Melancholy | Focus | High Energy | Euphoric
///   - Genre:       Lo-Fi | Acoustic | Classical | Electronic | Synthwave | Hip-Hop | Rock
///   - Energy Level: Low | Medium | High
///   - Estimated BPM (rough estimate via onset counting)
///
/// The scan runs in a background Dart Isolate so the UI thread is never blocked.
/// The service automatically yields between songs and pauses if audio is playing.
class LibraryTaggerService {
  static final LibraryTaggerService _instance = LibraryTaggerService._internal();
  factory LibraryTaggerService() => _instance;
  LibraryTaggerService._internal();

  final StorageService _storage = StorageService();
  bool _cancelRequested = false;

  final _progressController = StreamController<LibraryTaggerScanProgress>.broadcast();
  Stream<LibraryTaggerScanProgress> get progressStream => _progressController.stream;

  /// Returns all currently cached tags from Hive.
  Map<String, AiSongTags> loadAllCachedTags() {
    final raw = _storage.getAllAiSongTags();
    return raw.map((k, v) => MapEntry(k, AiSongTags.fromMap(v)));
  }

  /// Returns a single cached tag for [songId], or null if not yet analysed.
  AiSongTags? getCachedTags(String songId) {
    final raw = _storage.getAiSongTags(songId);
    if (raw == null) return null;
    return AiSongTags.fromMap(raw);
  }

  /// Starts a full library scan on [songs].
  ///
  /// [isPlayingCallback] is called before each song; if it returns true the
  /// scan pauses for [pauseWhilePlayingMs] ms to avoid competing with audio.
  /// [onlyUntagged] skips songs that already have tags in Hive.
  Future<void> scanLibrary(
    List<Song> songs, {
    bool Function()? isPlayingCallback,
    int pauseWhilePlayingMs = 500,
    bool onlyUntagged = true,
  }) async {
    _cancelRequested = false;

    final toScan = onlyUntagged
        ? songs.where((s) => _storage.getAiSongTags(s.id) == null).toList()
        : List<Song>.from(songs);

    final total = toScan.length;
    int scanned = 0;

    for (final song in toScan) {
      if (_cancelRequested) break;

      // Pause if audio is actively playing to avoid CPU contention
      if (isPlayingCallback != null && isPlayingCallback()) {
        await Future.delayed(Duration(milliseconds: pauseWhilePlayingMs));
        if (_cancelRequested) break;
      }

      _progressController.add(LibraryTaggerScanProgress(
        scanned: scanned,
        total: total,
        currentSongTitle: song.title,
      ));

      try {
        final tags = await _analyzeAndTag(song);
        if (tags != null) {
          await _storage.saveAiSongTags(tags.toMap());
        }
      } catch (e) {
        debugPrint('[LibraryTagger] Failed to tag "${song.title}": $e');
      }

      scanned++;
      // Yield to event loop between songs
      await Future.delayed(Duration.zero);
    }

    _progressController.add(LibraryTaggerScanProgress(
      scanned: scanned,
      total: total,
      isComplete: true,
    ));
  }

  void cancelScan() {
    _cancelRequested = true;
  }

  Future<void> clearAllTags() async {
    await _storage.clearAllAiSongTags();
  }

  Future<AiSongTags?> _analyzeAndTag(Song song) async {
    if (song.isAsset) {
      // Asset tracks are bundled WAVs — use title-based heuristics only
      return _titleHeuristicTag(song);
    }

    final file = File(song.uri);
    if (!await file.exists()) return _titleHeuristicTag(song);

    final fileLength = await file.length();
    if (fileLength < 44 * 1024) return _titleHeuristicTag(song); // < 44 KB → skip

    final payload = _TaggerPayload(song.uri, song.duration);
    final rawResult = await compute(_analyzeAudioWindow, payload);

    return _mapToTags(song.id, song.title, song.artist, song.album, rawResult);
  }

  AiSongTags _mapToTags(
    String songId,
    String title,
    String artist,
    String album,
    _RawTaggerResult raw,
  ) {
    // --- Energy Level ---
    final String energyLevel;
    if (raw.rmsEnergy < 0.25) {
      energyLevel = 'Low';
    } else if (raw.rmsEnergy < 0.60) {
      energyLevel = 'Medium';
    } else {
      energyLevel = 'High';
    }

    // --- Genre (rough classification) ---
    String genre;
    final allText = '${title.toLowerCase()} ${artist.toLowerCase()} ${album.toLowerCase()}';

    if (allText.contains('lo-fi') || allText.contains('lofi') || allText.contains('lo fi')) {
      genre = 'Lo-Fi';
    } else if (allText.contains('synthwave') || allText.contains('synth') || allText.contains('retrowave')) {
      genre = 'Synthwave';
    } else if (allText.contains('classical') || allText.contains('orchestra') || allText.contains('symphony') || allText.contains('sonata')) {
      genre = 'Classical';
    } else if (allText.contains('hip-hop') || allText.contains('hip hop') || allText.contains('rap') || allText.contains('trap')) {
      genre = 'Hip-Hop';
    } else if (allText.contains('acoustic') || allText.contains('unplugged') || allText.contains('folk')) {
      genre = 'Acoustic';
    } else if (allText.contains('rock') || allText.contains('metal') || allText.contains('punk') || allText.contains('grunge')) {
      genre = 'Rock';
    } else {
      // Fallback: use audio features
      if (raw.zeroCrossingRate > 0.65 && raw.rmsEnergy > 0.55) {
        genre = 'Rock';
      } else if (raw.zeroCrossingRate > 0.55 && raw.rmsEnergy > 0.45) {
        genre = 'Electronic';
      } else if (raw.zeroCrossingRate < 0.30 && raw.rmsEnergy < 0.35) {
        genre = 'Classical';
      } else if (raw.rmsEnergy < 0.30) {
        genre = 'Acoustic';
      } else {
        genre = 'Electronic';
      }
    }

    // --- Mood ---
    String mood;
    if (energyLevel == 'High' && raw.zeroCrossingRate > 0.55) {
      mood = 'Euphoric';
    } else if (energyLevel == 'High') {
      mood = 'High Energy';
    } else if (energyLevel == 'Low' && raw.zeroCrossingRate < 0.35) {
      mood = 'Melancholy';
    } else if (energyLevel == 'Low') {
      mood = 'Chill';
    } else {
      // Medium energy
      mood = raw.zeroCrossingRate > 0.5 ? 'Focus' : 'Chill';
    }

    // Override mood from title keywords
    final titleLower = title.toLowerCase();
    if (titleLower.contains('sad') || titleLower.contains('cry') || titleLower.contains('melanchol') || titleLower.contains('lonely')) {
      mood = 'Melancholy';
    } else if (titleLower.contains('hype') || titleLower.contains('pump') || titleLower.contains('banger')) {
      mood = 'Euphoric';
    } else if (titleLower.contains('chill') || titleLower.contains('relax') || titleLower.contains('calm') || titleLower.contains('sleep')) {
      mood = 'Chill';
    } else if (titleLower.contains('focus') || titleLower.contains('study') || titleLower.contains('work')) {
      mood = 'Focus';
    }

    return AiSongTags(
      songId: songId,
      mood: mood,
      genre: genre,
      energyLevel: energyLevel,
      estimatedBpm: raw.estimatedBpm > 0 ? raw.estimatedBpm : null,
      taggedAt: DateTime.now(),
    );
  }

  /// Title/metadata-only heuristic for asset tracks or unreadable files.
  AiSongTags _titleHeuristicTag(Song song) {
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();

    String mood = 'Chill';
    String genre = 'Electronic';
    String energyLevel = 'Medium';

    if (title.contains('8bit') || title.contains('chiptune') || title.contains('pixel') || artist.contains('pixel')) {
      genre = 'Electronic';
      mood = 'Euphoric';
      energyLevel = 'High';
    } else if (title.contains('arcade') || title.contains('rush') || title.contains('neon')) {
      genre = 'Synthwave';
      mood = 'High Energy';
      energyLevel = 'High';
    }

    return AiSongTags(
      songId: song.id,
      mood: mood,
      genre: genre,
      energyLevel: energyLevel,
      taggedAt: DateTime.now(),
    );
  }

  void dispose() {
    _progressController.close();
  }
}

// ─── Isolate-safe static function ───────────────────────────────────────────

/// Reads a 5-second PCM window from the middle of the audio file and computes
/// RMS energy, zero-crossing rate, and a rough BPM estimate.
///
/// This function runs in a background Dart Isolate via [compute()].
Future<_RawTaggerResult> _analyzeAudioWindow(_TaggerPayload payload) async {
  const windowDurationSecs = 5;
  const bytesPerSecEstimate = 176400; // 16-bit 44.1 kHz stereo PCM
  const windowBytes = windowDurationSecs * bytesPerSecEstimate;

  try {
    final file = File(payload.filePath);
    final fileLength = await file.length();
    if (fileLength < windowBytes) {
      return const _RawTaggerResult(rmsEnergy: 0.3, zeroCrossingRate: 0.3, midEnergy: 0.3, estimatedBpm: 0);
    }

    // Seek to middle of file
    final midOffset = max(0, (fileLength ~/ 2) - (windowBytes ~/ 2));
    final raf = await file.open();
    await raf.setPosition(midOffset);
    final bytes = Uint8List(windowBytes);
    final bytesRead = await raf.readInto(bytes);
    await raf.close();

    if (bytesRead < 1024) {
      return const _RawTaggerResult(rmsEnergy: 0.3, zeroCrossingRate: 0.3, midEnergy: 0.3, estimatedBpm: 0);
    }

    // Compute RMS energy
    double sumSq = 0.0;
    int prevSign = 0;
    int crossings = 0;
    int sampleCount = 0;

    // Onset detection for BPM estimation
    final List<double> energyFrames = [];
    const frameSize = 4410; // 100 ms frames at 44.1 kHz
    double frameSumSq = 0.0;
    int frameCount = 0;

    for (int i = 0; i < bytesRead - 1; i += 2) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      int sample = (hi << 8) | lo;
      if (sample >= 32768) sample -= 65536;
      final normalized = sample / 32768.0;

      sumSq += normalized * normalized;
      frameSumSq += normalized * normalized;
      frameCount++;
      sampleCount++;

      // Zero-crossing detection
      final sign = normalized >= 0 ? 1 : -1;
      if (prevSign != 0 && sign != prevSign) crossings++;
      prevSign = sign;

      // Energy frame collection for BPM
      if (frameCount >= frameSize) {
        energyFrames.add(sqrt(frameSumSq / frameCount));
        frameSumSq = 0.0;
        frameCount = 0;
      }
    }

    final rmsEnergy = sampleCount > 0 ? sqrt(sumSq / sampleCount) : 0.0;
    final zcr = sampleCount > 1 ? crossings / (sampleCount - 1) : 0.0;

    // Rough BPM estimation via onset counting in energy frames
    int estimatedBpm = 0;
    if (energyFrames.length > 4) {
      final avgEnergy = energyFrames.reduce((a, b) => a + b) / energyFrames.length;
      int onsets = 0;
      for (int i = 1; i < energyFrames.length; i++) {
        if (energyFrames[i] > avgEnergy * 1.4 && energyFrames[i] > energyFrames[i - 1] * 1.2) {
          onsets++;
        }
      }
      // Each 100ms frame → onsets per second = onsets / (energyFrames.length * 0.1)
      // BPM = onsets per minute
      if (energyFrames.isNotEmpty) {
        final opsec = onsets / (energyFrames.length * 0.1);
        estimatedBpm = (opsec * 60).round().clamp(40, 220);
      }
    }

    // Mid-window energy (center 1 second)
    final midStart = bytesRead ~/ 2 - bytesPerSecEstimate ~/ 2;
    double midSumSq = 0.0;
    int midCount = 0;
    for (int i = midStart.clamp(0, bytesRead - 2); i < min(midStart + bytesPerSecEstimate, bytesRead - 1); i += 2) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      int sample = (hi << 8) | lo;
      if (sample >= 32768) sample -= 65536;
      final n = sample / 32768.0;
      midSumSq += n * n;
      midCount++;
    }
    final midEnergy = midCount > 0 ? sqrt(midSumSq / midCount) : rmsEnergy;

    return _RawTaggerResult(
      rmsEnergy: rmsEnergy.clamp(0.0, 1.0),
      zeroCrossingRate: zcr.clamp(0.0, 1.0),
      midEnergy: midEnergy.clamp(0.0, 1.0),
      estimatedBpm: estimatedBpm,
    );
  } catch (e) {
    return const _RawTaggerResult(rmsEnergy: 0.3, zeroCrossingRate: 0.3, midEnergy: 0.3, estimatedBpm: 0);
  }
}
