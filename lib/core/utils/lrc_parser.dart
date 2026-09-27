import '../../domain/models/lrc_model.dart';

/// Comprehensive parser for standard and enhanced LRC (Lyrics) files.
/// Conforms to the LRC specification with support for multiple timestamp tags,
/// millisecond precision, metadata headers, and word-by-word/syllable timings.
class LrcParser {
  static final RegExp _tagRegex = RegExp(r'\[([^\]]+)\]');
  static final RegExp _extendedTimeRegex = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?$');
  static final RegExp _inlineTagRegex = RegExp(r'[<\[\(](?:(\d{1,2}:\d{2}(?:[.:]\d{1,3})?)|(?:\+?(\d{1,6})))[>\]\)]');

  /// Parses raw LRC text into a structured [LrcDocument].
  static LrcDocument parse(String content) {
    if (content.trim().isEmpty) {
      return const LrcDocument(
        lines: [],
        isSynced: false,
        rawContent: '',
      );
    }

    String? title;
    String? artist;
    String? album;
    String? creator;
    int offsetMs = 0;

    final parsedLines = <LrcLine>[];
    final rawLines = content.split(RegExp(r'\r?\n'));
    bool hasTimestamps = false;

    for (final rawLine in rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Extract all leading [...] tags
      final tags = <String>[];
      int textStartIndex = 0;

      final matches = _tagRegex.allMatches(line);
      if (matches.isEmpty) {
        // Plain unsynced text line
        continue;
      }

      int lastEnd = 0;
      for (final m in matches) {
        // Check if tags are contiguous from start
        if (m.start == lastEnd) {
          tags.add(m.group(1)!);
          lastEnd = m.end;
          textStartIndex = m.end;
        } else {
          break;
        }
      }

      final remainingText = line.substring(textStartIndex).trim();
      final lineTimestamps = <Duration>[];

      for (final tag in tags) {
        final lower = tag.toLowerCase();

        // Check for ID / metadata headers
        if (lower.startsWith('ti:')) {
          title = tag.substring(3).trim();
        } else if (lower.startsWith('ar:')) {
          artist = tag.substring(3).trim();
        } else if (lower.startsWith('al:')) {
          album = tag.substring(3).trim();
        } else if (lower.startsWith('by:')) {
          creator = tag.substring(3).trim();
        } else if (lower.startsWith('offset:')) {
          final offsetStr = tag.substring(7).trim();
          offsetMs = int.tryParse(offsetStr) ?? 0;
        } else {
          // Attempt parsing as timestamp
          final duration = _parseTimestamp(tag);
          if (duration != null) {
            lineTimestamps.add(duration);
            hasTimestamps = true;
          }
        }
      }

      if (lineTimestamps.isNotEmpty) {
        // Check for syllable / word-by-word timings in remainingText
        List<LrcWord>? words;
        String cleanText = remainingText;

        final inlineMatches = _inlineTagRegex.allMatches(remainingText).toList();
        if (inlineMatches.isNotEmpty) {
          words = [];
          final cleanBuffer = StringBuffer();
          final primaryLineTime = lineTimestamps.first;

          // 1. Text preceding the first inline tag belongs to the line's start timestamp
          if (inlineMatches.first.start > 0) {
            final leadingText = remainingText.substring(0, inlineMatches.first.start);
            if (leadingText.trim().isNotEmpty) {
              words.add(LrcWord(timestamp: primaryLineTime, text: leadingText));
              cleanBuffer.write(leadingText);
            }
          }

          // 2. Iterate through each tag and its subsequent word text
          for (int mIdx = 0; mIdx < inlineMatches.length; mIdx++) {
            final match = inlineMatches[mIdx];
            Duration? wTime;
            if (match.group(1) != null) {
              wTime = _parseTimestamp(match.group(1)!);
            } else if (match.group(2) != null) {
              final ms = int.tryParse(match.group(2)!);
              if (ms != null) wTime = Duration(milliseconds: ms);
            }

            final textStart = match.end;
            final textEnd = (mIdx < inlineMatches.length - 1)
                ? inlineMatches[mIdx + 1].start
                : remainingText.length;
            final wordText = remainingText.substring(textStart, textEnd);

            if (wTime != null) {
              // If word timestamp is smaller than line timestamp, it is relative to line start
              Duration finalTime = wTime;
              if (finalTime < primaryLineTime) {
                finalTime = primaryLineTime + finalTime;
              }
              if (wordText.isNotEmpty) {
                words.add(LrcWord(timestamp: finalTime, text: wordText));
              }
            }
            cleanBuffer.write(wordText);
          }

          cleanText = cleanBuffer.toString().trim();
          if (words.isEmpty) {
            words = null;
          }
        } else {
          // Remove any stray unparsed bracket markers
          cleanText = remainingText.replaceAll(RegExp(r'[<\[\(][^>\]\)]*[>\]\)]'), '').trim();
        }

        for (final timestamp in lineTimestamps) {
          List<LrcWord>? adjustedWords = words;
          if (words != null && timestamp != lineTimestamps.first) {
            final diff = timestamp - lineTimestamps.first;
            adjustedWords = words
                .map((w) => LrcWord(timestamp: w.timestamp + diff, text: w.text))
                .toList();
          }
          parsedLines.add(
            LrcLine(
              timestamp: timestamp,
              text: cleanText,
              words: adjustedWords,
            ),
          );
        }
      }
    }

    if (!hasTimestamps) {
      // Fallback: create plain text lines without timing
      final plainLines = <LrcLine>[];
      for (final rawLine in rawLines) {
        final text = rawLine.trim().replaceAll(RegExp(r'\[[^\]]+\]'), '').trim();
        if (text.isNotEmpty) {
          plainLines.add(LrcLine(timestamp: Duration.zero, text: text));
        }
      }
      return LrcDocument(
        title: title,
        artist: artist,
        album: album,
        creator: creator,
        offsetMs: offsetMs,
        lines: plainLines,
        isSynced: false,
        rawContent: content,
      );
    }

    // Apply offset if specified
    List<LrcLine> adjustedLines = parsedLines;
    if (offsetMs != 0) {
      adjustedLines = parsedLines.map((line) {
        final adjustedMs = line.timestamp.inMilliseconds + offsetMs;
        final newTimestamp = Duration(milliseconds: adjustedMs > 0 ? adjustedMs : 0);
        final adjustedWords = line.words?.map((w) {
          final wMs = w.timestamp.inMilliseconds + offsetMs;
          return LrcWord(
            timestamp: Duration(milliseconds: wMs > 0 ? wMs : 0),
            text: w.text,
          );
        }).toList();
        return LrcLine(
          timestamp: newTimestamp,
          text: line.text,
          words: adjustedWords,
        );
      }).toList();
    }

    // Sort chronologically by timestamp
    adjustedLines.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Calculate endTimes for smooth transitions
    final finalizedLines = <LrcLine>[];
    for (int i = 0; i < adjustedLines.length; i++) {
      final current = adjustedLines[i];
      Duration? endTime;
      if (i < adjustedLines.length - 1) {
        endTime = adjustedLines[i + 1].timestamp;
      } else {
        endTime = current.timestamp + const Duration(seconds: 4);
      }

      finalizedLines.add(
        LrcLine(
          timestamp: current.timestamp,
          text: current.text,
          words: current.words,
          endTime: endTime,
        ),
      );
    }

    return LrcDocument(
      title: title,
      artist: artist,
      album: album,
      creator: creator,
      offsetMs: offsetMs,
      lines: finalizedLines,
      isSynced: true,
      rawContent: content,
    );
  }

  /// Parses strings formatted like "01:23.45", "1:23.456", or "01:23"
  static Duration? _parseTimestamp(String tag) {
    final match = _extendedTimeRegex.firstMatch(tag);
    if (match == null) return null;

    int hours = 0;
    int minutes = 0;
    int seconds = 0;
    int milliseconds = 0;

    if (match.group(1) != null) {
      // hh:mm:ss
      hours = int.tryParse(match.group(1)!) ?? 0;
      minutes = int.tryParse(match.group(2)!) ?? 0;
      seconds = int.tryParse(match.group(3)!) ?? 0;
    } else {
      // mm:ss
      minutes = int.tryParse(match.group(2)!) ?? 0;
      seconds = int.tryParse(match.group(3)!) ?? 0;
    }

    final fractionStr = match.group(4);
    if (fractionStr != null) {
      if (fractionStr.length == 1) {
        milliseconds = (int.tryParse(fractionStr) ?? 0) * 100;
      } else if (fractionStr.length == 2) {
        milliseconds = (int.tryParse(fractionStr) ?? 0) * 10;
      } else {
        milliseconds = int.tryParse(fractionStr.substring(0, 3)) ?? 0;
      }
    }

    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }
}
