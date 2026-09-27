import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/monet_engine.dart';
import '../../core/theme/retro_theme.dart';
import '../../core/theme/retro_typography.dart';
import '../../domain/models/song.dart';
import '../providers/lyrics_provider.dart';
import '../providers/player_provider.dart';
import 'lyrics_sweeper.dart';
import 'retro_icon.dart';

/// A self-contained widget that renders the mini lyrics ticker on the
/// Now Playing screen with smooth 60fps character-level color interpolation,
/// matching the Apple Music approach: an audio-clock anchor is corrected every
/// ~200ms by the Riverpod position stream, and a [Ticker] interpolates
/// wall-clock elapsed time between those corrections.
class SmoothLyricsTicker extends ConsumerStatefulWidget {
  final Song song;
  final RetroThemeTokens retro;
  final ThemeData theme;
  final VoidCallback onTap;

  const SmoothLyricsTicker({
    super.key,
    required this.song,
    required this.retro,
    required this.theme,
    required this.onTap,
  });

  @override
  ConsumerState<SmoothLyricsTicker> createState() =>
      _SmoothLyricsTickerState();
}

class _SmoothLyricsTickerState extends ConsumerState<SmoothLyricsTicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<Duration> _smoothPosition =
      ValueNotifier(Duration.zero);

  Duration _anchorPosition = Duration.zero;
  final Stopwatch _stopwatch = Stopwatch();
  bool _isPlaying = false;
  bool _hasActiveSyllables = false;

  ProviderSubscription<Duration>? _positionSub;
  ProviderSubscription<bool>? _playingSub;
  ProviderSubscription<LyricsState>? _lyricsSub;

  int _lastLineIndex = 0;
  bool _isMovingForward = true;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    final ps = ref.read(playerProvider);
    _anchorPosition = ps.position;
    _isPlaying = ps.isPlaying;
    _smoothPosition.value = _anchorPosition;

    final ls = ref.read(lyricsProvider);
    final isSongMatching = ls.songId == widget.song.id;
    final currentLine = isSongMatching ? ls.currentLine : null;
    _hasActiveSyllables = currentLine != null &&
        currentLine.hasGenuineSyllableTimings &&
        currentLine.words != null &&
        currentLine.words!.isNotEmpty;

    _syncTicker();
  }

  void _syncTicker() {
    final shouldTick = _isPlaying && _hasActiveSyllables;
    if (shouldTick) {
      if (!_ticker.isActive) {
        _stopwatch.reset();
        _stopwatch.start();
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) {
        _ticker.stop();
        _stopwatch.stop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant SmoothLyricsTicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.id != widget.song.id) {
      final ls = ref.read(lyricsProvider);
      final isSongMatching = ls.songId == widget.song.id;
      final currentLine = isSongMatching ? ls.currentLine : null;
      _hasActiveSyllables = currentLine != null &&
          currentLine.hasGenuineSyllableTimings &&
          currentLine.words != null &&
          currentLine.words!.isNotEmpty;
      _syncTicker();
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_isPlaying) {
      _smoothPosition.value = _anchorPosition + _stopwatch.elapsed;
    }
  }

  void _onAudioPositionUpdate(Duration pos) {
    _anchorPosition = pos;
    _stopwatch.reset();
    _smoothPosition.value = pos;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _positionSub?.close();
    _positionSub = ref.listenManual<Duration>(
      playerProvider.select((s) => s.position),
      (_, next) => _onAudioPositionUpdate(next),
      fireImmediately: true,
    );

    _playingSub?.close();
    _playingSub = ref.listenManual<bool>(
      playerProvider.select((s) => s.isPlaying),
      (_, next) {
        _isPlaying = next;
        if (!next) {
          _smoothPosition.value = _anchorPosition;
        }
        _syncTicker();
      },
      fireImmediately: true,
    );

    _lyricsSub?.close();
    _lyricsSub = ref.listenManual<LyricsState>(
      lyricsProvider,
      (_, next) {
        final isSongMatching = next.songId == widget.song.id;
        final currentLine = isSongMatching ? next.currentLine : null;
        _hasActiveSyllables = currentLine != null &&
            currentLine.hasGenuineSyllableTimings &&
            currentLine.words != null &&
            currentLine.words!.isNotEmpty;
        _syncTicker();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    _smoothPosition.dispose();
    _positionSub?.close();
    _playingSub?.close();
    _lyricsSub?.close();
    super.dispose();
  }

  static bool _isRTL(String text) {
    return RegExp(
      r'[\u0590-\u05FF\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text);
  }

  @override
  Widget build(BuildContext context) {
    final lyricsState = ref.watch(lyricsProvider);
    final currentSong = widget.song;
    final retro = widget.retro;
    final theme = widget.theme;

    final isSongMatching =
        lyricsState.songId == currentSong.id;
    final hasLyrics = isSongMatching &&
        lyricsState.lyrics != null &&
        lyricsState.lyrics!.lines.isNotEmpty;
    final currentLine =
        isSongMatching ? lyricsState.currentLine : null;
    final isSynced =
        hasLyrics && (lyricsState.lyrics?.isSynced ?? false);

    return ValueListenableBuilder<int>(
      valueListenable: AndroidMonetEngine.extractionNotifier,
      builder: (context, extractionVersion, _) {
        final monetLyricColor = AndroidMonetEngine.getLyricsHighlightColor(
          song: currentSong,
          isDark: retro.isDark,
        );

        String activeText = '';
        if (lyricsState.isLoading || !isSongMatching) {
          activeText = 'FETCHING LYRICS...';
        } else if (hasLyrics && !isSynced) {
          activeText = 'UNSYNCED';
        } else if (currentLine != null && currentLine.text.isNotEmpty) {
          activeText = currentLine.text;
        }
        final bool isRtl = _isRTL(activeText);
        final textAlign = isRtl ? TextAlign.right : TextAlign.left;
        final textAlignment = isRtl ? Alignment.centerRight : Alignment.centerLeft;

        final activeIndex = lyricsState.activeLineIndex;
        if (activeIndex != _lastLineIndex) {
          _isMovingForward = activeIndex >= _lastLineIndex;
          _lastLineIndex = activeIndex;
        }
        final currentKey = ValueKey(
          '${lyricsState.activeLineIndex}_${lyricsState.isLoading}_${!isSynced}',
        );

        return InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            key: const ValueKey('now_playing_lyrics_ticker'),
            width: double.infinity,
            height: 52.0,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: widget.retro.cardColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isRtl) ...[
                  RetroIcon(
                    'chevron_left',
                    size: 16,
                    color: hasLyrics
                        ? monetLyricColor.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Align(
                    alignment: textAlignment,
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        layoutBuilder: (currentChild, previousChildren) {
                          return Stack(
                            alignment: textAlignment,
                            children: [
                              ...previousChildren,
                              ?currentChild,
                            ],
                          );
                        },
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                            child: SlideTransition(
                              position: _SpotifyLyricsSlideAnimation(
                                animation,
                                isMovingForward: _isMovingForward,
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: currentKey,
                          child: _buildTickerContent(
                            lyricsState: lyricsState,
                            currentLine: currentLine,
                            hasLyrics: hasLyrics,
                            isSynced: isSynced,
                            isSongMatching: isSongMatching,
                            monetLyricColor: monetLyricColor,
                            theme: theme,
                            textAlign: textAlign,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isRtl) ...[
                  const SizedBox(width: 8),
                  RetroIcon(
                    'chevron_right',
                    size: 16,
                    color: hasLyrics
                        ? monetLyricColor.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTickerContent({
    required LyricsState lyricsState,
    required dynamic currentLine,
    required bool hasLyrics,
    required bool isSynced,
    required bool isSongMatching,
    required Color monetLyricColor,
    required ThemeData theme,
    required TextAlign textAlign,
  }) {
    if (lyricsState.isLoading || !isSongMatching) {
      return Text(
        'FETCHING LYRICS...',
        style: RetroTypography.pixelHeader(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          fontSize: 12.5,
          height: 1.35,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    if (hasLyrics && !isSynced) {
      return Text(
        'UNSYNCED',
        style: RetroTypography.pixelHeader(
          color: monetLyricColor,
          fontSize: 12.5,
          height: 1.35,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
      );
    }

    if (currentLine != null &&
        currentLine.hasGenuineSyllableTimings &&
        currentLine.words != null &&
        currentLine.words!.isNotEmpty) {
      final isLineNonLatin = RetroTypography.isNonLatin(currentLine.text);
      final fontSize = isLineNonLatin ? 16.5 : 12.5;

      // Use ValueListenableBuilder so the sweep updates at 60fps
      return ValueListenableBuilder<Duration>(
        valueListenable: _smoothPosition,
        builder: (context, smoothPos, _) {
          return Text.rich(
            TextSpan(
              children: LyricsSweeper.buildSweptWordSpans(
                line: currentLine,
                isActive: true,
                currentPosition: smoothPos,
                songColor: monetLyricColor,
                unsungColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.38),
                fontSize: fontSize,
                isTicker: true,
              ),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
          );
        },
      );
    }

    final lineText = currentLine != null && currentLine.text.isNotEmpty
        ? currentLine.text
        : (hasLyrics ? '♪ ♪ ♪' : 'LYRICS NOT AVAILABLE');

    return Text(
      lineText,
      style: RetroTypography.lyricsStyle(
        text: lineText,
        color: hasLyrics
            ? monetLyricColor
            : theme.colorScheme.onSurface.withValues(alpha: 0.6),
        isTicker: true,
        fontWeight:
            (hasLyrics && isSynced) ? FontWeight.bold : FontWeight.normal,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}

/// Animates incoming lyric lines from the bottom upwards into view, and
/// outgoing lyric lines upwards and out of view (matching the Spotify approach).
class _SpotifyLyricsSlideAnimation extends Animation<Offset>
    with AnimationWithParentMixin<double> {
  @override
  final Animation<double> parent;
  final bool isMovingForward;

  _SpotifyLyricsSlideAnimation(this.parent, {this.isMovingForward = true});

  @override
  Offset get value {
    final t = parent.value;
    final isReverse = parent.status == AnimationStatus.reverse ||
        parent.status == AnimationStatus.dismissed;
    if (isReverse) {
      // Old line goes UP: from center (0.0) up to -0.85
      final progress = Curves.easeInCubic.transform((1.0 - t).clamp(0.0, 1.0));
      final dy = isMovingForward ? -0.85 * progress : 0.85 * progress;
      return Offset(0.0, dy);
    } else {
      // Next line appears from BOTTOM: from bottom (0.85) up to center (0.0)
      final progress = Curves.easeOutCubic.transform((1.0 - t).clamp(0.0, 1.0));
      final dy = isMovingForward ? 0.85 * progress : -0.85 * progress;
      return Offset(0.0, dy);
    }
  }
}
