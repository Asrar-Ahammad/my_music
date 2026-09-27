import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/monet_engine.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../domain/models/lrc_model.dart';
import '../../providers/lyrics_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/lyrics_sweeper.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../settings/settings_screen.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _lineKeys = {};
  bool _userHasScrolled = false;
  Timer? _userScrollResetTimer;
  int _lastActiveIndex = -1;
  String? _lastSongId;

  GlobalKey _getKeyForIndex(int index) {
    return _lineKeys.putIfAbsent(index, () => GlobalKey());
  }

  // ── Ticker-driven smooth position ─────────────────────────────────────────
  // We keep a local "smooth" position that is corrected by the real audio
  // clock each time the Riverpod playerProvider emits a new position, then
  // interpolated forward at 60 fps using wall-clock elapsed time.
  late final Ticker _ticker;
  final ValueNotifier<Duration> _smoothPosition =
      ValueNotifier(Duration.zero);

  /// The last position value received from the audio engine.
  Duration _anchorPosition = Duration.zero;

  /// Stopwatch to measure wall-clock elapsed time since the last audio clock
  /// correction ([_anchorPosition] was captured).
  final Stopwatch _stopwatch = Stopwatch();

  /// Whether the player is currently playing (used to freeze interpolation
  /// when paused so we don't drift forward while audio is stopped).
  bool _isPlaying = false;
  bool _hasActiveSyllables = false;

  ProviderSubscription<Duration>? _positionSub;
  ProviderSubscription<bool>? _playingSub;
  ProviderSubscription<LyricsState>? _lyricsSub;

  @override
  void initState() {
    super.initState();

    _ticker = createTicker(_onTick);

    // Seed the anchor with the current known position.
    final ps = ref.read(playerProvider);
    _anchorPosition = ps.position;
    _isPlaying = ps.isPlaying;
    _smoothPosition.value = _anchorPosition;

    final ls = ref.read(lyricsProvider);
    final currentLine = ls.currentLine;
    _hasActiveSyllables = currentLine != null &&
        currentLine.hasSyllableTimings &&
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

  /// Called every frame by the [Ticker].
  void _onTick(Duration elapsed) {
    if (!mounted) return;
    if (_isPlaying) {
      // Interpolate: smooth = anchor + wall-clock elapsed since last audio update
      _smoothPosition.value =
          _anchorPosition + _stopwatch.elapsed;
    }
    // When paused, keep _smoothPosition frozen at last anchor.
  }

  /// Called when the audio engine emits a new position (typically ~200 ms).
  void _onAudioPositionUpdate(Duration pos) {
    // Correct anchor with real audio clock and reset the wall-clock stopwatch.
    _anchorPosition = pos;
    _stopwatch.reset();
    // Snap the smooth position immediately to avoid visible jumps.
    _smoothPosition.value = pos;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Subscribe to position updates; re-anchor on each new value.
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
          // Snap smooth position to anchor when pausing.
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
        final currentLine = next.currentLine;
        _hasActiveSyllables = currentLine != null &&
            currentLine.hasSyllableTimings &&
            currentLine.words != null &&
            currentLine.words!.isNotEmpty;
        _syncTicker();
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _userScrollResetTimer?.cancel();
    _ticker.dispose();
    _stopwatch.stop();
    _smoothPosition.dispose();
    _positionSub?.close();
    _playingSub?.close();
    _lyricsSub?.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToActiveLine(int index, int totalLines, {bool force = false}) {
    if ((!force && _userHasScrolled) ||
        !_scrollController.hasClients ||
        index < 0 ||
        index >= totalLines) {
      return;
    }

    final key = _lineKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        alignment: 0.5,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    } else {
      final viewportHeight = _scrollController.position.viewportDimension;
      final verticalPadding = (viewportHeight * 0.45).clamp(180.0, 500.0);
      const approxItemHeight = 56.0;
      final targetOffset =
          (verticalPadding + (index * approxItemHeight) - (viewportHeight * 0.5))
              .clamp(0.0, _scrollController.position.maxScrollExtent);

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      ).then((_) {
        if (!mounted) return;
        final currentKey = _lineKeys[index];
        if (currentKey?.currentContext != null) {
          Scrollable.ensureVisible(
            currentKey!.currentContext!,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final song = ref.watch(playerProvider.select((s) => s.currentSong));
    final lyricsState = ref.watch(lyricsProvider);
    final isSongMatching = song == null || lyricsState.songId == song.id;
    final songColor = AndroidMonetEngine.getLyricsHighlightColor(
      song: song,
      isDark: retro.isDark,
    );

    // Reset user scroll state if song changed
    if (song?.id != _lastSongId) {
      _lastSongId = song?.id;
      _userHasScrolled = false;
      _lastActiveIndex = -1;
      _lineKeys.clear();
    }

    // Auto-scroll when activeLineIndex changes only if synced and user hasn't scrolled
    if (isSongMatching &&
        lyricsState.lyrics != null &&
        lyricsState.lyrics!.isSynced &&
        lyricsState.activeLineIndex >= 0 &&
        lyricsState.activeLineIndex != _lastActiveIndex) {
      _lastActiveIndex = lyricsState.activeLineIndex;
      if (!_userHasScrolled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToActiveLine(
            lyricsState.activeLineIndex,
            lyricsState.lyrics!.lines.length,
          );
        });
      }
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              song?.title.toUpperCase() ?? 'LYRICS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song?.artist.toUpperCase() ?? 'RETRO AUDIO',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 9,
              ),
            ),
          ],
        ),
        actions: [
          if (isSongMatching && lyricsState.lyrics?.hasSyllableTimings == true)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: RetroBadge(
                  text: 'WORD SYNC',
                  backgroundColor: songColor,
                  textColor: retro.isDark ? Colors.black : Colors.white,
                  fontSize: 7.5,
                ),
              ),
            )
          else if (isSongMatching &&
              lyricsState.lyrics != null &&
              !lyricsState.lyrics!.isSynced)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: RetroBadge(
                  text: 'UNSYNCED',
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  textColor: theme.colorScheme.onSurfaceVariant,
                  fontSize: 7.5,
                ),
              ),
            )
          else if (isSongMatching &&
              lyricsState.lyrics != null &&
              lyricsState.lyrics!.isSynced)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: RetroBadge(
                  text: 'SYNCED',
                  backgroundColor: songColor.withValues(alpha: 0.2),
                  textColor: songColor,
                  fontSize: 7.5,
                ),
              ),
            ),
          if (isSongMatching && lyricsState.sourceName != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: RetroBadge(
                  text: lyricsState.sourceName!,
                  backgroundColor: theme.colorScheme.primary,
                  textColor: theme.colorScheme.onPrimary,
                  fontSize: 8,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh Lyrics',
            icon: const RetroIcon('refresh', size: 18),
            onPressed: () {
              ref.read(lyricsProvider.notifier).refreshLyrics();
            },
          ),
        ],
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _userScrollResetTimer?.cancel();
            if (!_userHasScrolled) {
              setState(() {
                _userHasScrolled = true;
              });
            }
          } else if (notification is UserScrollNotification &&
              notification.direction != ScrollDirection.idle) {
            _userScrollResetTimer?.cancel();
            if (!_userHasScrolled) {
              setState(() {
                _userHasScrolled = true;
              });
            }
          } else if (notification is ScrollEndNotification) {
            if (_userHasScrolled) {
              _userScrollResetTimer?.cancel();
              _userScrollResetTimer = Timer(const Duration(seconds: 4), () {
                if (mounted) {
                  setState(() => _userHasScrolled = false);
                  final curLyrics = ref.read(lyricsProvider);
                  if (curLyrics.lyrics != null &&
                      curLyrics.activeLineIndex >= 0) {
                    _scrollToActiveLine(
                      curLyrics.activeLineIndex,
                      curLyrics.lyrics!.lines.length,
                      force: true,
                    );
                  }
                }
              });
            }
          }
          return false;
        },
        child: Stack(
          children: [
            _buildBody(
              context,
              theme,
              retro,
              lyricsState,
              songColor,
              isSongMatching,
            ),

            // Floating "Sync to current" button when user scrolled away
            if (isSongMatching &&
                _userHasScrolled &&
                lyricsState.lyrics?.isSynced == true &&
                lyricsState.activeLineIndex >= 0)
              Positioned(
                bottom: 24,
                right: 20,
                child: RetroButton(
                  label: 'SYNC',
                  icon: const RetroIcon(
                    'arrow_down',
                    size: 14,
                    color: Colors.black,
                  ),
                  backgroundColor: retro.accentYellow,
                  textColor: Colors.black,
                  borderColor: retro.borderColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  onPressed: () {
                    setState(() => _userHasScrolled = false);
                    _scrollToActiveLine(
                      lyricsState.activeLineIndex,
                      lyricsState.lyrics?.lines.length ?? 0,
                      force: true,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    LyricsState lyricsState,
    Color songColor,
    bool isSongMatching,
  ) {
    if (lyricsState.isLoading || !isSongMatching) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          child: RetroCard(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
                const SizedBox(height: 16),
                Text(
                  'FETCHING SYNCHRONIZED LYRICS...',
                  style: RetroTypography.pixelHeader(
                    color: theme.colorScheme.onSurface,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final doc = lyricsState.lyrics;
    if (doc == null || doc.lines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: RetroCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const RetroIcon('music', size: 36),
                const SizedBox(height: 12),
                Text(
                  'NO LYRICS AVAILABLE',
                  style: RetroTypography.pixelHeader(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lyricsState.errorMessage ??
                      'No matching LRC file found locally or online for this song.',
                  textAlign: TextAlign.center,
                  style: RetroTypography.pixelBadge(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontSize: 9.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RetroButton(
                      label: 'RETRY SEARCH',
                      icon: const RetroIcon('refresh',
                          size: 14, color: Colors.black),
                      backgroundColor: retro.accentYellow,
                      textColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      onPressed: () {
                        ref.read(lyricsProvider.notifier).refreshLyrics();
                      },
                    ),
                    const SizedBox(width: 8),
                    RetroButton(
                      label: 'SETTINGS',
                      icon: RetroIcon('settings',
                          size: 14,
                          color: theme.colorScheme.onSurface),
                      backgroundColor: retro.cardColor,
                      textColor: theme.colorScheme.onSurface,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenHeight = MediaQuery.sizeOf(context).height;
    final verticalPadding = (screenHeight * 0.45).clamp(180.0, 500.0);

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(
          top: verticalPadding, bottom: verticalPadding, left: 20, right: 20),
      itemCount: doc.lines.length,
      itemBuilder: (context, index) {
        final line = doc.lines[index];
        final isSynced = doc.isSynced;
        final isActive = isSynced && (index == lyricsState.activeLineIndex);

        Widget lineContent;

        if (isActive && line.hasSyllableTimings && line.words != null) {
          // ── Active line with word-level timings: 60fps via ValueListenable ──
          lineContent = ValueListenableBuilder<Duration>(
            valueListenable: _smoothPosition,
            builder: (context, smoothPos, _) {
              return _buildLyricLineContent(
                line: line,
                isActive: true,
                isSynced: true,
                currentPosition: smoothPos + const Duration(milliseconds: 150),
                songColor: songColor,
                theme: theme,
              );
            },
          );
        } else {
          // Non-active lines or lines without word timings don't need 60fps.
          lineContent = _buildLyricLineContent(
            line: line,
            isActive: isActive,
            isSynced: isSynced,
            // For non-active lines the exact sub-ms position doesn't matter
            // (they are just colored uniformly), so we can use the last anchor.
            currentPosition: _smoothPosition.value,
            songColor: songColor,
            theme: theme,
          );
        }

        if (isSynced) {
          if (!isActive) {
            lineContent = AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: 0.35,
              child: lineContent,
            );
          } else {
            lineContent = AnimatedScale(
              scale: 1.05,
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.centerLeft,
              curve: Curves.easeOutCubic,
              child: lineContent,
            );
          }
        }

        return Padding(
          key: _getKeyForIndex(index),
          padding: EdgeInsets.symmetric(
            vertical: isSynced ? 11.0 : 7.0,
          ),
          child: InkWell(
            onTap: isSynced
                ? () {
                    ref
                        .read(playerProvider.notifier)
                        .seek(line.timestamp);
                    setState(() => _userHasScrolled = false);
                    _scrollToActiveLine(
                      index,
                      doc.lines.length,
                      force: true,
                    );
                  }
                : null,
            borderRadius: BorderRadius.circular(6),
            splashColor: songColor.withValues(alpha: 0.12),
            highlightColor: songColor.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: lineContent,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLyricLineContent({
    required LrcLine line,
    required bool isActive,
    required bool isSynced,
    required Duration currentPosition,
    required Color songColor,
    required ThemeData theme,
  }) {
    final isNonLatin = RetroTypography.isNonLatin(line.text);
    final activeSize = isNonLatin ? 20.0 : 15.5;
    final inactiveSize = isNonLatin ? 16.5 : 12.5;

    // Unsynced lyrics: plain rendering without highlighting
    if (!isSynced) {
      final unsyncedSize = isNonLatin ? 17.5 : 13.5;
      return Text(
        line.text.isEmpty ? '♪ ♪ ♪' : line.text,
        style: RetroTypography.lyricsStyle(
          text: line.text,
          color: theme.colorScheme.onSurface,
          fontSize: unsyncedSize,
          fontWeight: FontWeight.normal,
        ),
      );
    }

    if (line.hasSyllableTimings &&
        line.words != null &&
        line.words!.isNotEmpty) {
      return Text.rich(
        TextSpan(
          children: LyricsSweeper.buildSweptWordSpans(
            line: line,
            isActive: isActive,
            currentPosition: currentPosition,
            songColor: songColor,
            unsungColor: isActive
                ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                : theme.colorScheme.onSurface,
            fontSize: isActive ? activeSize : inactiveSize,
          ),
        ),
      );
    }

    return Text(
      line.text.isEmpty ? '♪ ♪ ♪' : line.text,
      style: RetroTypography.lyricsStyle(
        text: line.text,
        color: isActive ? songColor : theme.colorScheme.onSurface,
        fontSize: isActive ? activeSize : inactiveSize,
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
