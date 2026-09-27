/// Represents word or syllable level timing within an enhanced LRC line
class LrcWord {
  final Duration timestamp;
  final String text;

  const LrcWord({
    required this.timestamp,
    required this.text,
  });

  @override
  String toString() => 'LrcWord($timestamp, "$text")';
}

/// Represents a single timed lyric line
class LrcLine {
  final Duration timestamp;
  final String text;
  final List<LrcWord>? words;
  final Duration? endTime;
  final bool isSynthesized;

  const LrcLine({
    required this.timestamp,
    required this.text,
    this.words,
    this.endTime,
    this.isSynthesized = false,
  });

  bool get hasSyllableTimings => words != null && words!.isNotEmpty;
  bool get hasGenuineSyllableTimings => hasSyllableTimings && !isSynthesized;

  @override
  String toString() => 'LrcLine($timestamp, "$text")';
}

/// Parsed representation of an entire LRC lyric document
class LrcDocument {
  final String? title;
  final String? artist;
  final String? album;
  final String? creator;
  final int offsetMs;
  final List<LrcLine> lines;
  final bool isSynced;
  final String rawContent;

  const LrcDocument({
    this.title,
    this.artist,
    this.album,
    this.creator,
    this.offsetMs = 0,
    required this.lines,
    required this.isSynced,
    required this.rawContent,
  });

  /// Whether any line in this document contains syllable or word-level timings
  bool get hasSyllableTimings => lines.any((l) => l.hasSyllableTimings);

  /// Whether any line in this document contains genuine (non-synthesized) word-level timings
  bool get hasGenuineSyllableTimings => lines.any((l) => l.hasGenuineSyllableTimings);

  /// Binary search to find the active lyric line index for a given playback position.
  /// Returns -1 if playback position is before the first line or if lyrics are unsynced.
  /// [anticipatoryLead] shifts evaluation forward to allow smooth UI transitions and
  /// compensate for audio output latency.
  int findLineIndexAt(Duration position, {Duration anticipatoryLead = Duration.zero}) {
    if (lines.isEmpty || !isSynced) return -1;
    final effectivePos = position + anticipatoryLead;
    if (effectivePos < lines.first.timestamp) return -1;
    if (effectivePos >= lines.last.timestamp) return lines.length - 1;

    int low = 0;
    int high = lines.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final line = lines[mid];

      if (effectivePos < line.timestamp) {
        high = mid - 1;
      } else {
        // effectivePos >= line.timestamp
        if (mid == lines.length - 1 || effectivePos < lines[mid + 1].timestamp) {
          return mid;
        }
        low = mid + 1;
      }
    }

    return low.clamp(0, lines.length - 1);
  }

  /// Get the active lyric line at given position, or null if before first line or unsynced.
  LrcLine? findLineAt(Duration position, {Duration anticipatoryLead = Duration.zero}) {
    final idx = findLineIndexAt(position, anticipatoryLead: anticipatoryLead);
    if (idx >= 0 && idx < lines.length) {
      return lines[idx];
    }
    return null;
  }

  /// Enriches any synced line that lacks word-level timestamps with
  /// natural word timings based on singing pace and line duration.
  LrcDocument withSynthesizedWordTimings() {
    if (!isSynced || lines.isEmpty) return this;

    final updatedLines = <LrcLine>[];
    for (final line in lines) {
      if (line.hasSyllableTimings) {
        updatedLines.add(line);
      } else {
        final start = line.timestamp;
        final rawDuration = (line.endTime != null && line.endTime! > start)
            ? (line.endTime! - start)
            : const Duration(seconds: 4);

        // Vocal lines are typically sung in 2 to 6.5 seconds.
        // Clamping prevents multi-word lines from stretching awkwardly over long instrumental gaps.
        final trimmed = line.text.trim();
        final estimatedDurationMs = (trimmed.length * 130).clamp(2000, 6500);
        final effectiveDurationMs = (rawDuration.inMilliseconds > 0 &&
                rawDuration.inMilliseconds < estimatedDurationMs)
            ? rawDuration.inMilliseconds
            : estimatedDurationMs;

        final end = start + Duration(milliseconds: effectiveDurationMs);
        final words = _synthesizeLineWords(line.text, start, end);
        updatedLines.add(
          LrcLine(
            timestamp: line.timestamp,
            text: line.text,
            words: words.isNotEmpty ? words : null,
            endTime: line.endTime,
            isSynthesized: true,
          ),
        );
      }
    }

    return LrcDocument(
      title: title,
      artist: artist,
      album: album,
      creator: creator,
      offsetMs: offsetMs,
      lines: updatedLines,
      isSynced: isSynced,
      rawContent: rawContent,
    );
  }

  static List<LrcWord> _synthesizeLineWords(String text, Duration start, Duration end) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return [];

    // Split words while keeping trailing whitespace on each word token.
    // For non-spaced scripts (e.g. CJK), split character by character if no spaces present.
    final List<String> tokens;
    final hasWhitespace = trimmed.contains(RegExp(r'\s'));
    if (!hasWhitespace && trimmed.length > 1) {
      tokens = trimmed.runes.map(String.fromCharCode).toList();
    } else {
      tokens = RegExp(r'\S+\s*').allMatches(trimmed).map((m) => m.group(0)!).toList();
    }

    if (tokens.isEmpty) return [];

    final totalDurationMs = (end - start).inMilliseconds;
    if (totalDurationMs <= 0) {
      return tokens.map((t) => LrcWord(timestamp: start, text: t)).toList();
    }

    final totalChars = tokens.fold<int>(0, (sum, t) => sum + t.trim().length);
    final charWeight = totalChars > 0 ? totalDurationMs / totalChars : totalDurationMs / tokens.length;

    final words = <LrcWord>[];
    int elapsedMs = 0;

    for (int i = 0; i < tokens.length; i++) {
      final wordStr = tokens[i];
      final wordTime = start + Duration(milliseconds: elapsedMs);
      words.add(LrcWord(timestamp: wordTime, text: wordStr));

      final wordLen = wordStr.trim().length;
      final wordDurationMs = (wordLen * charWeight).round();
      elapsedMs += wordDurationMs;
    }

    return words;
  }
}
