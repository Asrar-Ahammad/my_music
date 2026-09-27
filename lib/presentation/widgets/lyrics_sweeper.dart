import 'package:flutter/material.dart';
import '../../domain/models/lrc_model.dart';
import '../../core/theme/retro_typography.dart';

/// Helper to render Apple Music-style progressive color sweep across lyrics.
///
/// This utility is stateless — callers are responsible for driving smooth
/// re-renders (e.g. via a [Ticker] or [AnimationController]) to achieve
/// 60 fps character-level color interpolation.
class LyricsSweeper {
  LyricsSweeper._();

  static List<InlineSpan> buildSweptWordSpans({
    required LrcLine line,
    required bool isActive,
    required Duration currentPosition,
    required Color songColor,
    required Color unsungColor,
    required double fontSize,
    bool isTicker = false,
  }) {
    final words = line.words;
    if (words == null || words.isEmpty) {
      return [
        TextSpan(
          text: line.text,
          style: RetroTypography.lyricsStyle(
            text: line.text,
            color: isActive ? songColor : unsungColor,
            fontSize: fontSize,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            isTicker: isTicker,
          ),
        ),
      ];
    }

    final spans = <InlineSpan>[];

    for (int i = 0; i < words.length; i++) {
      final word = words[i];
      final wordStart = word.timestamp;

      Duration wordEnd;
      if (i < words.length - 1) {
        wordEnd = words[i + 1].timestamp;
      } else if (line.endTime != null && line.endTime! > wordStart) {
        wordEnd = line.endTime!;
      } else {
        wordEnd = wordStart + const Duration(milliseconds: 800);
      }

      final durationMs = (wordEnd - wordStart).inMilliseconds;
      final effectiveDurationMs = durationMs > 0 ? durationMs : 300;
      final elapsedMs = (currentPosition - wordStart).inMilliseconds;
      final wordProgress = (elapsedMs / effectiveDurationMs).clamp(0.0, 1.0);

      if (!isActive) {
        spans.add(
          TextSpan(
            text: word.text,
            style: RetroTypography.lyricsStyle(
              text: line.text,
              color: unsungColor,
              fontSize: fontSize,
              fontWeight: FontWeight.normal,
              isTicker: isTicker,
            ),
          ),
        );
      } else if (wordProgress >= 1.0) {
        spans.add(
          TextSpan(
            text: word.text,
            style: RetroTypography.lyricsStyle(
              text: line.text,
              color: songColor,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              isTicker: isTicker,
            ),
          ),
        );
      } else if (wordProgress <= 0.0) {
        spans.add(
          TextSpan(
            text: word.text,
            style: RetroTypography.lyricsStyle(
              text: line.text,
              color: unsungColor,
              fontSize: fontSize,
              fontWeight: FontWeight.normal,
              isTicker: isTicker,
            ),
          ),
        );
      } else {
        final chars = word.text.characters.toList();
        final numChars = chars.length;
        final charPos = wordProgress * numChars;

        for (int j = 0; j < numChars; j++) {
          final charProgress = ((charPos - j) / 1.2).clamp(0.0, 1.0);
          final charColor = Color.lerp(unsungColor, songColor, charProgress)!;
          final charWeight =
              charProgress > 0.5 ? FontWeight.bold : FontWeight.normal;

          spans.add(
            TextSpan(
              text: chars[j],
              style: RetroTypography.lyricsStyle(
                text: line.text,
                color: charColor,
                fontSize: fontSize,
                fontWeight: charWeight,
                isTicker: isTicker,
              ),
            ),
          );
        }
      }
    }

    return spans;
  }
}
