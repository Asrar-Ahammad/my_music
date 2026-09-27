import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_colors.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../data/services/audio_player_handler.dart' show RetroLoopMode;
import '../../../data/services/storage_service.dart';
import '../../providers/font_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_now_playing_art.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_scanline_overlay.dart';
import '../../widgets/retro_slider.dart';
import '../../widgets/retro_toast.dart';
import '../../widgets/retro_volume_slider.dart';
import '../../widgets/retro_clock_timer_dialog.dart';
import '../equalizer/equalizer_screen.dart';
import '../lyrics/lyrics_screen.dart';
import '../spatial_audio/spatial_audio_screen.dart';
import '../../providers/spatial_audio_provider.dart';
import '../../widgets/smooth_lyrics_ticker.dart';
import 'queue_sheet.dart';
import '../../../domain/models/song.dart';
import '../../widgets/retro_song_tile.dart';
import '../home_scaffold.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  final bool isDrawer;
  final double? topPadding;
  final void Function({double? velocityY})? onCollapse;
  final bool hideCoverArt;
  final bool isExpanded;

  const NowPlayingScreen({
    super.key,
    this.isDrawer = false,
    this.topPadding,
    this.onCollapse,
    this.hideCoverArt = false,
    this.isExpanded = true,
  });

  /// Opens the full-screen music player as an expandable full-screen bottom sheet
  static Future<void> showBottomSheet(BuildContext context) async {
    final home = HomeScaffold.of(context);
    if (home != null) {
      await home.expandNowPlaying();
      return;
    }
    StorageService().setNowPlayingDrawerOpen(true);
    final topPadding = MediaQuery.paddingOf(context).top;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: false,
        enableDrag: true,
        isDismissible: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          side: BorderSide.none,
        ),
        builder: (context) => NowPlayingScreen(
          isDrawer: false,
          topPadding: topPadding,
        ),
      );
    } finally {
      StorageService().setNowPlayingDrawerOpen(false);
    }
  }

  /// Alias for showBottomSheet for backwards compatibility
  static Future<void> showAsDrawer(BuildContext context) => showBottomSheet(context);

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scrollController;
  late final AnimationController _animController;
  Animation<double>? _dragAnimation;

  double _dragOffsetY = 0.0;
  double? _dragStartY;
  double? _dragStartX;
  DateTime? _dragStartTime;
  bool _isAtTopWhenDragStarted = true;
  bool _isDismissing = false;
  bool _isQueueOpening = false;
  bool _hasStartedCollapseDrag = false;
  double _maxDownDrag = 0.0;
  DateTime? _lastCollapseCancelTime;



  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_dragAnimation != null) {
          setState(() {
            _dragOffsetY = _dragAnimation!.value;
          });
        }
      });
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _animateBack() {
    _lastCollapseCancelTime = DateTime.now();
    if (_dragOffsetY <= 0.0) {
      _hasStartedCollapseDrag = false;
      return;
    }
    _animController.stop();
    _dragAnimation = Tween<double>(
      begin: _dragOffsetY,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0).then((_) {
      _lastCollapseCancelTime = DateTime.now();
      _hasStartedCollapseDrag = false;
    });
  }

  void _animateAndDismiss({double? velocityY}) {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    final home = HomeScaffold.of(context);
    if (widget.onCollapse != null) {
      widget.onCollapse!(velocityY: velocityY);
      return;
    }
    if (home != null) {
      home.collapseNowPlaying(velocityY: velocityY);
      return;
    }
    final screenHeight = MediaQuery.of(context).size.height;
    _animController.stop();
    _dragAnimation = Tween<double>(
      begin: _dragOffsetY,
      end: screenHeight,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward(from: 0.0).then((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  void _dismiss() {
    _animateAndDismiss();
  }

  PopupMenuItem<String> _buildMenuItem({
    required String value,
    required String label,
    required String icon,
    required ThemeData theme,
  }) {
    return PopupMenuItem<String>(
      value: value,
      height: 38,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RetroIcon(
            icon,
            size: 15,
            color: theme.colorScheme.onSurface,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.onSurface,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu({
    required Song song,
    required ThemeData theme,
    required RetroThemeTokens retro,
    double iconSize = 20,
    EdgeInsetsGeometry padding = const EdgeInsets.all(8),
  }) {
    return Theme(
      data: theme.copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        key: const ValueKey('now_playing_more_menu'),
        padding: EdgeInsets.zero,
        tooltip: 'Song Options',
        elevation: 0,
        color: retro.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(
            color: retro.borderColor,
            width: 2.0,
          ),
        ),
        onSelected: (action) => _handleMenuAction(action, song),
        itemBuilder: (ctx) => [
          _buildMenuItem(
            value: 'add_queue',
            label: 'ADD TO QUEUE',
            icon: 'queue',
            theme: theme,
          ),
          _buildMenuItem(
            value: 'add_playlist',
            label: 'ADD TO PLAYLIST',
            icon: 'folder',
            theme: theme,
          ),
          _buildMenuItem(
            value: 'go_album',
            label: 'GO TO ALBUM',
            icon: 'disc',
            theme: theme,
          ),
          _buildMenuItem(
            value: 'go_artist',
            label: 'GO TO ARTIST',
            icon: 'user',
            theme: theme,
          ),
        ],
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: retro.cardColor.withValues(alpha: 0.5),
            border: Border.all(
              color: retro.borderColor.withValues(alpha: 0.5),
              width: retro.borderWidth,
            ),
            borderRadius: BorderRadius.zero,
          ),
          child: RetroIcon(
            'more_vertical',
            size: iconSize,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(String action, Song song) {
    final playerNotifier = ref.read(playerProvider.notifier);

    switch (action) {
      case 'add_queue':
        playerNotifier.addToQueue(song);
        RetroToast.show(
          context,
          'ADDED TO QUEUE: ${song.title.toUpperCase()}',
          icon: 'queue',
        );
        break;

      case 'add_playlist':
        RetroSongTile.showAddToPlaylistDialog(context, ref, song);
        break;

      case 'go_album':
        final home = HomeScaffold.of(context);
        if (home != null) {
          home.collapseNowPlaying();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ref.read(homeTabProvider.notifier).openAlbum(song.album);
        break;

      case 'go_artist':
        final home = HomeScaffold.of(context);
        if (home != null) {
          home.collapseNowPlaying();
        } else if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ref.read(homeTabProvider.notifier).openArtist(song.artist);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerProvider);
    final activeFont = ref.watch(fontProvider);
    final isSatoshi = RetroTypography.isSatoshi(activeFont);
    final playerNotifier = ref.read(playerProvider.notifier);
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final spatialAudioState = ref.watch(spatialAudioProvider);
    final theme = Theme.of(context);
    final retro = context.retro;
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

    final song = playerState.currentSong;

    // Precache cover arts of current and adjacent songs in queue for instant transitions
    if (playerState.queue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final q = playerState.queue;
        final currIdx = playerState.currentIndex;
        if (currIdx >= 0 && currIdx < q.length) {
          final nextIdx = (currIdx + 1) % q.length;
          final prevIdx = (currIdx - 1 + q.length) % q.length;
          final nextNextIdx = (currIdx + 2) % q.length;
          RetroAlbumArt.precacheArt(q[currIdx].artPath, context);
          RetroAlbumArt.precacheArt(q[nextIdx].artPath, context);
          RetroAlbumArt.precacheArt(q[prevIdx].artPath, context);
          RetroAlbumArt.precacheArt(q[nextNextIdx].artPath, context);
        }
      });
    }

    final isFavorite = song != null &&
        (libraryState.allSongs
            .firstWhere((s) => s.id == song.id, orElse: () => song)
            .isFavorite);

    double hardwareTop = 0.0;
    try {
      final view = View.maybeOf(context);
      if (view != null && view.devicePixelRatio > 0) {
        hardwareTop = view.viewPadding.top / view.devicePixelRatio;
      }
    } catch (_) {}
    final viewPaddingTop = MediaQuery.viewPaddingOf(context).top;
    final paddingTop = MediaQuery.paddingOf(context).top;
    final candidates = [
      hardwareTop,
      viewPaddingTop,
      paddingTop,
      widget.topPadding ?? 0.0,
    ];
    final effectiveTop = candidates.reduce((a, b) => a > b ? a : b);

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Responsive Album Art Sizing: scales proportionally to fill upper canvas gracefully
    final artSize = (screenWidth - 48).clamp(260.0, (screenHeight * 0.42).clamp(290.0, 390.0));

    // Calculate vertical rhythm dynamically so space breathes harmoniously across the screen
    final availableBodyHeight = screenHeight - effectiveTop - 16 - bottomInset;
    final estimatedContent = artSize + 360.0;
    final remainingSpace = (availableBodyHeight - estimatedContent).clamp(0.0, 120.0);

    // Distribute remaining space smoothly across sections
    final gapAboveArt = (remainingSpace * 0.12).clamp(4.0, 14.0);
    final gapBelowArt = (remainingSpace * 0.12).clamp(6.0, 14.0);
    final gapBelowBadges = (remainingSpace * 0.10).clamp(6.0, 12.0);
    final gapBelowDetails = (remainingSpace * 0.26).clamp(16.0, 34.0);
    final gapBelowLyrics = (remainingSpace * 0.14).clamp(10.0, 16.0);
    final gapBelowSlider = (remainingSpace * 0.14).clamp(14.0, 22.0);
    final gapBelowControls = (remainingSpace * 0.12).clamp(12.0, 18.0);

    if (song == null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismiss,
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! > 4) {
            _dismiss();
          }
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 50) {
            _dismiss();
          }
        },
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.zero,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                if (effectiveTop > 0) SizedBox(height: effectiveTop + 4),
                Expanded(
                  child: Center(
                    child: Text(
                      'NO TRACK PLAYING',
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (_isDismissing) return;
        final wasAnimating = _animController.isAnimating;
        _animController.stop();
        _dragStartY = event.position.dy;
        _dragStartX = event.position.dx;
        _dragStartTime = DateTime.now();
        final isTouchingHeader = event.position.dy <= (effectiveTop + 48 + 32);
        _isAtTopWhenDragStarted = isTouchingHeader ||
            !_scrollController.hasClients ||
            _scrollController.offset <= 4.0;
        _hasStartedCollapseDrag = _dragOffsetY > 0.5 || wasAnimating;
      },
      onPointerMove: (event) {
        if (_dragStartY == null || _dragStartX == null || _isDismissing) {
          return;
        }
        final dy = event.position.dy - _dragStartY!;
        final dx = (event.position.dx - _dragStartX!).abs();
        if (dy > _maxDownDrag) {
          _maxDownDrag = dy;
        }

        final home = HomeScaffold.of(context);
        if (_isAtTopWhenDragStarted) {
          if ((dy > 6 || _maxDownDrag > 8) && dy > dx * 0.4) {
            _hasStartedCollapseDrag = true;
            if (home != null) {
              final screenHeight = MediaQuery.of(context).size.height;
              final progress = (1.0 - (dy > 0 ? dy : 0.0) / screenHeight).clamp(0.0, 1.0);
              home.setExpansionProgress(progress);
            } else {
              setState(() {
                _dragOffsetY = dy;
              });
            }
          } else if (_hasStartedCollapseDrag) {
            if (home != null) {
              final screenHeight = MediaQuery.of(context).size.height;
              final progress = (1.0 - (dy > 0 ? dy : 0.0) / screenHeight).clamp(0.0, 1.0);
              home.setExpansionProgress(progress);
            } else {
              setState(() {
                _dragOffsetY = dy > 0 ? dy : 0.0;
              });
            }
          }
        }
      },
      onPointerUp: (event) {
        if (_dragStartY != null && _dragStartX != null && !_isDismissing) {
          final dy = event.position.dy - _dragStartY!;
          final elapsedMs = _dragStartTime != null
              ? DateTime.now().difference(_dragStartTime!).inMilliseconds
              : 100;
          final velocityY = elapsedMs > 0 ? (dy / elapsedMs) * 1000 : 0.0;
          final home = HomeScaffold.of(context);

          if (_hasStartedCollapseDrag ||
              (_isAtTopWhenDragStarted && (_dragOffsetY > 0 || (home != null && home.expansionProgress < 0.999)))) {
            final screenHeight = MediaQuery.of(context).size.height;
            final threshold = (screenHeight * 0.12).clamp(70.0, 130.0);
            if (dy >= threshold || velocityY > 180) {
              _animateAndDismiss(velocityY: velocityY > 180 ? velocityY : null);
            } else {
              if (home != null) {
                home.expandNowPlaying();
              } else {
                _animateBack();
              }
            }
          }
        }
        _dragStartY = null;
        _dragStartX = null;
        _dragStartTime = null;
        _hasStartedCollapseDrag = false;
        _maxDownDrag = 0.0;
      },
      onPointerCancel: (_) {
        final home = HomeScaffold.of(context);
        if (home != null) {
          home.expandNowPlaying();
        } else if (_dragOffsetY > 0 && !_isDismissing) {
          _animateBack();
        }
        _dragStartY = null;
        _dragStartX = null;
        _dragStartTime = null;
        _hasStartedCollapseDrag = false;
        _maxDownDrag = 0.0;
      },
      child: Transform.translate(
        offset: Offset(0, HomeScaffold.of(context) != null ? 0.0 : _dragOffsetY),
        child: Container(
          height: screenHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.zero,
          ),
          child: RetroScanlineOverlay(
            enabled: true,
            opacity: 0.03,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                top: false,
                bottom: true,
                child: Column(
                  children: [
                    if (effectiveTop > 0 && !isLandscape)
                      SizedBox(height: effectiveTop + 8)
                    else if (!isLandscape)
                      const SizedBox(height: 12)
                    else
                      const SizedBox(height: 8),

                    // Player Body (Landscape Split-Panel or Portrait Vertical Stack)
                    Expanded(
                      child: isLandscape
                          ? _buildLandscapeBody(
                              context: context,
                              song: song,
                              playerState: playerState,
                              playerNotifier: playerNotifier,
                              libraryNotifier: libraryNotifier,
                              spatialAudioState: spatialAudioState,
                              isFavorite: isFavorite,
                              theme: theme,
                              retro: retro,
                              isSatoshi: isSatoshi,
                            )
                          : _buildPortraitBody(
                              context: context,
                              song: song,
                              playerState: playerState,
                              playerNotifier: playerNotifier,
                              libraryNotifier: libraryNotifier,
                              spatialAudioState: spatialAudioState,
                              isFavorite: isFavorite,
                              theme: theme,
                              retro: retro,
                              isSatoshi: isSatoshi,
                              artSize: artSize,
                              gapAboveArt: gapAboveArt,
                              gapBelowArt: gapBelowArt,
                              gapBelowBadges: gapBelowBadges,
                              gapBelowDetails: gapBelowDetails,
                              gapBelowLyrics: gapBelowLyrics,
                              gapBelowSlider: gapBelowSlider,
                              gapBelowControls: gapBelowControls,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitBody({
    required BuildContext context,
    required Song song,
    required PlayerStateModel playerState,
    required PlayerNotifier playerNotifier,
    required LibraryNotifier libraryNotifier,
    required SpatialAudioState spatialAudioState,
    required bool isFavorite,
    required ThemeData theme,
    required RetroThemeTokens retro,
    required bool isSatoshi,
    required double artSize,
    required double gapAboveArt,
    required double gapBelowArt,
    required double gapBelowBadges,
    required double gapBelowDetails,
    required double gapBelowLyrics,
    required double gapBelowSlider,
    required double gapBelowControls,
  }) {
    return SingleChildScrollView(
      key: const ValueKey('now_playing_body_scroll'),
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: gapAboveArt),

          // Album art frame with swipe-down to collapse gesture detector
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) {
              if (_hasStartedCollapseDrag ||
                  _maxDownDrag > 8 ||
                  _dragOffsetY > 0.5) {
                return;
              }
              final delta = details.primaryDelta ?? 0;
              if (delta > 0) {
                final home = HomeScaffold.of(context);
                if (home != null) {
                  home.handleDragUpdate(delta);
                }
              }
            },
            onVerticalDragEnd: (details) {
              if (_hasStartedCollapseDrag ||
                  _maxDownDrag > 8 ||
                  _dragOffsetY > 0.5) {
                return;
              }
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 120) {
                final home = HomeScaffold.of(context);
                if (home != null) {
                  home.collapseNowPlaying(velocityY: velocity);
                } else {
                  _animateAndDismiss(velocityY: velocity);
                }
              } else {
                final home = HomeScaffold.of(context);
                if (home != null) {
                  if (home.expansionProgress < 0.85) {
                    home.collapseNowPlaying();
                  } else {
                    home.expandNowPlaying();
                  }
                }
              }
            },
            child: Center(
              child: Opacity(
                opacity: widget.hideCoverArt ? 0.0 : 1.0,
                child: RetroNowPlayingArt(
                  song: song,
                  size: artSize,
                ),
              ),
            ),
          ),

          SizedBox(height: gapBelowArt),

          // Audio Quality Badges
          _buildQualityBadges(song, retro, theme),

          SizedBox(height: gapBelowBadges),

          // Track Title & Favorite Button
          SizedBox(
            width: double.infinity,
            height: 74,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        song.title,
                        style: context.isNothingTheme
                            ? NothingTypography.headline(
                                color: theme.colorScheme.onSurface,
                                fontSize: 21.0,
                                fontWeight: FontWeight.w700,
                              )
                            : isSatoshi
                                ? TextStyle(
                                    fontFamily: 'Satoshi',
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 21.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.15,
                                    height: 1.2,
                                  )
                                : RetroTypography.pixelHeader(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${song.artist} • ${song.album}',
                        style: context.isNothingTheme
                            ? NothingTypography.label(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                                fontSize: 12.5,
                              )
                            : isSatoshi
                                ? TextStyle(
                                    fontFamily: 'Satoshi',
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.1,
                                  )
                                : RetroTypography.retroMono(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.75),
                                    fontSize: 15,
                                  ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Favorite Button on Left of song details
                Positioned(
                  left: 0,
                  child: RetroButton(
                    isCompact: true,
                    padding: const EdgeInsets.all(8),
                    backgroundColor: isFavorite
                        ? RetroColors.picoRed.withValues(alpha: 0.15)
                        : retro.cardColor.withValues(alpha: 0.5),
                    borderColor: isFavorite
                        ? RetroColors.picoRed
                        : retro.borderColor.withValues(alpha: 0.5),
                    textColor: isFavorite
                        ? RetroColors.picoRed
                        : theme.colorScheme.onSurface,
                    icon: RetroIcon(
                      isFavorite ? 'heart_filled' : 'heart',
                      size: 20,
                      color: isFavorite
                          ? RetroColors.picoRed
                          : theme.colorScheme.onSurface,
                    ),
                    onPressed: () {
                      libraryNotifier.toggleFavorite(song.id);
                    },
                  ),
                ),
                // Three-dot options menu on Right of song details
                Positioned(
                  right: 0,
                  child: _buildMoreMenu(
                    song: song,
                    theme: theme,
                    retro: retro,
                    iconSize: 20,
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: gapBelowDetails),

          // Live Synchronized Lyric Ticker
          SmoothLyricsTicker(
            song: song,
            retro: retro,
            theme: theme,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const LyricsScreen(),
                ),
              );
            },
          ),

          SizedBox(height: gapBelowLyrics),

          // Seek Bar
          RetroSlider(
            position: playerState.position,
            duration: playerState.duration,
            onSeek: (newPos) => playerNotifier.seek(newPos),
          ),

          SizedBox(height: gapBelowSlider),

          // Primary Playback Controls
          _buildControls(
            context: context,
            playerState: playerState,
            playerNotifier: playerNotifier,
            theme: theme,
            retro: retro,
          ),

          SizedBox(height: gapBelowControls),

          // Volume Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: RetroVolumeSlider(
              volume: playerState.volume,
              onVolumeChanged: (newVol) =>
                  playerNotifier.setVolume(newVol),
            ),
          ),

          const SizedBox(height: 14),

          // Secondary Utility Controls: Sleep Timer, Equalizer, Spatial Audio, Queue
          _buildUtilityControls(
            context: context,
            playerState: playerState,
            spatialAudioState: spatialAudioState,
            theme: theme,
            retro: retro,
          ),

          const SizedBox(height: 12),

          // Sleep Timer status if active
          if (playerState.sleepTimerRemaining != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: retro.accentYellow.withValues(alpha: 0.2),
                border: Border.all(
                  color: retro.accentYellow,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.zero,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RetroIcon(
                    'clock',
                    size: 14,
                    color: Colors.black,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'SLEEP IN: ${playerState.sleepTimerRemaining!.inMinutes}m ${playerState.sleepTimerRemaining!.inSeconds % 60}s',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// iOS 27 Landscape Split-Panel Layout
  /// Left Panel: Enlarged Album Artwork & Quality Badges
  /// Right Panel: Real-time Lyrics, Track Metadata, Sliders, Retro Playback Controls
  Widget _buildLandscapeBody({
    required BuildContext context,
    required Song song,
    required PlayerStateModel playerState,
    required PlayerNotifier playerNotifier,
    required LibraryNotifier libraryNotifier,
    required SpatialAudioState spatialAudioState,
    required bool isFavorite,
    required ThemeData theme,
    required RetroThemeTokens retro,
    required bool isSatoshi,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Panel: Enlarged squircle artwork & quality badges
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: RetroNowPlayingArt(
                        song: song,
                        size: double.infinity,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _buildQualityBadges(song, retro, theme),
              ],
            ),
          ),
        ),

        // Right Panel: Synced lyrics, Track info, seek bar, controls, volume
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            key: const ValueKey('now_playing_body_scroll'),
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Track Title, Artist, Favorite & Menu Buttons
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Favorite button on left of song details
                    RetroButton(
                      isCompact: true,
                      padding: const EdgeInsets.all(8),
                      backgroundColor: isFavorite
                          ? RetroColors.picoRed.withValues(alpha: 0.15)
                          : retro.cardColor.withValues(alpha: 0.5),
                      borderColor: isFavorite
                          ? RetroColors.picoRed
                          : retro.borderColor.withValues(alpha: 0.5),
                      textColor: isFavorite
                          ? RetroColors.picoRed
                          : theme.colorScheme.onSurface,
                      icon: RetroIcon(
                        isFavorite ? 'heart_filled' : 'heart',
                        size: 18,
                        color: isFavorite
                            ? RetroColors.picoRed
                            : theme.colorScheme.onSurface,
                      ),
                      onPressed: () => libraryNotifier.toggleFavorite(song.id),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            style: isSatoshi
                                ? TextStyle(
                                    fontFamily: 'Satoshi',
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.15,
                                  )
                                : RetroTypography.pixelHeader(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: 14,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${song.artist} • ${song.album}',
                            style: isSatoshi
                                ? TextStyle(
                                    fontFamily: 'Satoshi',
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                  )
                                : RetroTypography.retroMono(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                                    fontSize: 13,
                                  ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Three-dot menu on right of song title
                    _buildMoreMenu(
                      song: song,
                      theme: theme,
                      retro: retro,
                        iconSize: 18,
                      padding: const EdgeInsets.all(8),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Real-time synced lyrics ticker
                SmoothLyricsTicker(
                  song: song,
                  retro: retro,
                  theme: theme,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LyricsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Seek bar
                RetroSlider(
                  position: playerState.position,
                  duration: playerState.duration,
                  onSeek: (newPos) => playerNotifier.seek(newPos),
                ),
                const SizedBox(height: 8),

                // Primary Playback Controls
                _buildControls(
                  context: context,
                  playerState: playerState,
                  playerNotifier: playerNotifier,
                  theme: theme,
                  retro: retro,
                      ),
                const SizedBox(height: 8),

                // Volume slider
                RetroVolumeSlider(
                  volume: playerState.volume,
                  onVolumeChanged: (newVol) => playerNotifier.setVolume(newVol),
                ),
                const SizedBox(height: 10),

                // Utility controls
                _buildUtilityControls(
                  context: context,
                  playerState: playerState,
                  spatialAudioState: spatialAudioState,
                  theme: theme,
                  retro: retro,
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQualityBadges(Song song, RetroThemeTokens retro, ThemeData theme) {
    return SizedBox(
      height: 24,
      width: double.infinity,
      child: ClipRect(
        child: Align(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            if (song.quality.isDolbyAtmos) ...[
              RetroBadge(
                text: 'DOLBY ATMOS',
                icon: const RetroIcon('dolby_atmos', size: 12, color: Colors.black),
                backgroundColor: retro.accentGreen,
                textColor: Colors.black,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              const SizedBox(width: 8),
            ] else if (song.quality.isSpatialAudio) ...[
              RetroBadge(
                text: 'SPATIAL 3D',
                icon: const RetroIcon('headphone', size: 12, color: Colors.white),
                backgroundColor: retro.accentPurple,
                textColor: Colors.white,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              const SizedBox(width: 8),
            ],
            if (song.quality.isHiRes) ...[
              RetroBadge(
                text: 'HI-RES LOSSLESS',
                backgroundColor: retro.accentGreen,
                textColor: Colors.black,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              const SizedBox(width: 8),
              RetroBadge(
                text: '${song.quality.bitDepth}-BIT / ${song.quality.sampleRateKhz} • ${song.quality.bitrateKbps} kbps',
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ] else if (song.quality.isLossless) ...[
              RetroBadge(
                text: 'LOSSLESS',
                backgroundColor: theme.colorScheme.primary,
                textColor: theme.colorScheme.onPrimary,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              const SizedBox(width: 8),
              RetroBadge(
                text: '${song.quality.bitDepth}-BIT / ${song.quality.sampleRateKhz} • ${song.quality.bitrateKbps} kbps',
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ] else if (song.quality.isHighQuality) ...[
              RetroBadge(
                text: 'HIGH QUALITY',
                backgroundColor: retro.accentYellow,
                textColor: Colors.black,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              const SizedBox(width: 8),
              RetroBadge(
                text: '${song.quality.bitrateKbps} kbps • ${song.quality.sampleRateKhz}',
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ] else ...[
              RetroBadge(
                text: '${song.quality.bitrateKbps} kbps',
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface,
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              const SizedBox(width: 8),
              RetroBadge(
                text: song.quality.sampleRateKhz,
                backgroundColor: retro.cardColor,
                textColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontSize: 7.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ],             // end last else spread
              ],           // end Row children
            ),             // end Row
          ),               // end SingleChildScrollView
        ),                 // end Align
      ),                   // end ClipRect
    );
  }

  Widget _buildControls({
    required BuildContext context,
    required PlayerStateModel playerState,
    required PlayerNotifier playerNotifier,
    required ThemeData theme,
    required RetroThemeTokens retro,
  }) {
    Widget controlsRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Shuffle
        RetroButton(
          isCompact: true,
          padding: const EdgeInsets.all(10),
          backgroundColor: playerState.isShuffle
              ? theme.colorScheme.primary
              : retro.cardColor,
          borderColor: playerState.isShuffle
              ? theme.colorScheme.primary
              : retro.borderColor,
          textColor: playerState.isShuffle
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          icon: RetroIcon(
            'shuffle',
            size: 20,
            color: playerState.isShuffle
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          onPressed: () {
            playerNotifier.toggleShuffle();
            final isNowOn = !playerState.isShuffle;
            RetroToast.show(
              context,
              isNowOn ? 'SHUFFLE: ON' : 'SHUFFLE: OFF',
              icon: 'shuffle',
              iconColor: isNowOn ? theme.colorScheme.primary : Colors.white,
            );
          },
        ),

        // Skip Previous
        RetroButton(
          isCompact: true,
          padding: const EdgeInsets.all(10),
          backgroundColor: retro.cardColor,
          borderColor: retro.borderColor,
          textColor: theme.colorScheme.onSurface,
          icon: RetroIcon(
            'skip_prev',
            size: 22,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            final q = playerState.queue;
            final idx = playerState.currentIndex;
            if (q.isNotEmpty && idx >= 0) {
              final prevIdx = (idx - 1 + q.length) % q.length;
              RetroAlbumArt.precacheArt(q[prevIdx].artPath, context);
            }
            playerNotifier.skipToPrevious();
          },
        ),

        // Chunky Play / Pause Button
        RetroButton(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 14,
          ),
          backgroundColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onPrimary,
          icon: RetroIcon(
            playerState.isPlaying ? 'pause' : 'play',
            size: 28,
            color: theme.colorScheme.onPrimary,
          ),
          onPressed: () => playerNotifier.togglePlayPause(),
        ),

        // Skip Next
        RetroButton(
          isCompact: true,
          padding: const EdgeInsets.all(10),
          backgroundColor: retro.cardColor,
          borderColor: retro.borderColor,
          textColor: theme.colorScheme.onSurface,
          icon: RetroIcon(
            'skip_next',
            size: 22,
            color: theme.colorScheme.onSurface,
          ),
          onPressed: () {
            final q = playerState.queue;
            final idx = playerState.currentIndex;
            if (q.isNotEmpty && idx >= 0) {
              final nextIdx = (idx + 1) % q.length;
              RetroAlbumArt.precacheArt(q[nextIdx].artPath, context);
            }
            playerNotifier.skipToNext();
          },
        ),

        // Repeat Mode (Off, All, One)
        RetroButton(
          isCompact: true,
          padding: const EdgeInsets.all(10),
          backgroundColor: playerState.loopMode != RetroLoopMode.off
              ? theme.colorScheme.primary
              : retro.cardColor,
          borderColor: playerState.loopMode != RetroLoopMode.off
              ? theme.colorScheme.primary
              : retro.borderColor,
          textColor: playerState.loopMode != RetroLoopMode.off
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
          icon: RetroIcon(
            playerState.loopMode == RetroLoopMode.one
                ? 'repeat_one'
                : (playerState.loopMode == RetroLoopMode.all
                    ? 'repeat_dot'
                    : 'repeat'),
            size: 22,
            color: playerState.loopMode != RetroLoopMode.off
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          onPressed: () {
            playerNotifier.toggleLoop();
            final nextMode = playerState.loopMode == RetroLoopMode.off
                ? RetroLoopMode.all
                : (playerState.loopMode == RetroLoopMode.all
                    ? RetroLoopMode.one
                    : RetroLoopMode.off);
            RetroToast.show(
              context,
              nextMode == RetroLoopMode.one
                  ? 'REPEAT: ONE'
                  : (nextMode == RetroLoopMode.all
                      ? 'REPEAT: ALL'
                      : 'REPEAT: OFF'),
              icon: nextMode == RetroLoopMode.one
                  ? 'repeat_one'
                  : (nextMode == RetroLoopMode.all
                      ? 'repeat_dot'
                      : 'repeat'),
              iconColor: nextMode != RetroLoopMode.off
                  ? theme.colorScheme.primary
                  : Colors.white,
            );
          },
        ),
      ],
    );



    return controlsRow;
  }

  Widget _buildUtilityControls({
    required BuildContext context,
    required PlayerStateModel playerState,
    required SpatialAudioState spatialAudioState,
    required ThemeData theme,
    required RetroThemeTokens retro,
  }) {
    const utilityButtonHeight = 36.0;

    final row = _OverlappingRow(
      overlap: retro.borderWidth,
      children: [
        // Sleep timer button
        Tooltip(
          message: 'Sleep Timer',
          child: RetroButton(
            isCompact: true,
            width: 96.0,
            height: utilityButtonHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            backgroundColor: playerState.sleepTimerRemaining != null
                ? retro.accentYellow
                : retro.cardColor,
            border: Border.all(
              color: retro.borderColor,
              width: retro.borderWidth,
            ),
            textColor: playerState.sleepTimerRemaining != null
                ? Colors.black
                : theme.colorScheme.onSurface,
            icon: RetroIcon(
              'clock',
              size: 15,
              color: playerState.sleepTimerRemaining != null
                  ? Colors.black
                  : theme.colorScheme.onSurface,
            ),
            label: playerState.sleepTimerRemaining != null
                ? '${playerState.sleepTimerRemaining!.inMinutes}M'
                : 'TIMER',
            onPressed: () => _showSleepTimerDialog(context),
          ),
        ),

        // Equalizer button
        Tooltip(
          message: 'Equalizer',
          child: RetroButton(
            isCompact: true,
            height: utilityButtonHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            backgroundColor: retro.cardColor,
            border: Border.all(
              color: retro.borderColor,
              width: retro.borderWidth,
            ),
            textColor: theme.colorScheme.onSurface,
            icon: RetroIcon(
              'sliders',
              size: 15,
              color: theme.colorScheme.onSurface,
            ),
            label: 'EQ',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EqualizerScreen(),
                ),
              );
            },
          ),
        ),

        // Spatial Audio button
        Tooltip(
          message: 'Dolby Atmos & Spatial Audio',
          child: RetroButton(
            isCompact: true,
            height: utilityButtonHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            backgroundColor: spatialAudioState.isEnabled
                ? (retro.isDark
                    ? retro.cardColor
                    : theme.colorScheme.primary)
                : retro.cardColor,
            border: Border.all(
              color: retro.borderColor,
              width: retro.borderWidth,
            ),
            textColor: spatialAudioState.isEnabled
                ? (retro.isDark
                    ? retro.accentGreen
                    : theme.colorScheme.onPrimary)
                : theme.colorScheme.onSurface,
            icon: RetroIcon(
              'dolby_atmos',
              size: 15,
              color: spatialAudioState.isEnabled
                  ? (retro.isDark
                      ? retro.accentGreen
                      : theme.colorScheme.onPrimary)
                  : theme.colorScheme.onSurface,
            ),
            label: 'ATMOS',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SpatialAudioScreen(),
                ),
              );
            },
          ),
        ),

        // Queue button
        Tooltip(
          message: 'Queue',
          child: RetroButton(
            isCompact: true,
            height: utilityButtonHeight,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),
            backgroundColor: retro.cardColor,
            border: Border.all(
              color: retro.borderColor,
              width: retro.borderWidth,
            ),
            textColor: theme.colorScheme.onSurface,
            icon: RetroIcon(
              'queue',
              size: 15,
              color: theme.colorScheme.onSurface,
            ),
            label: 'QUEUE',
            onPressed: () => _showQueueSheet(context),
          ),
        ),
      ],
    );
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: row,
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    if (_isQueueOpening || _isDismissing || !mounted) return;
    if (_hasStartedCollapseDrag || _dragOffsetY > 0.5 || _maxDownDrag > 8.0) return;
    if (_animController.isAnimating) return;
    if (_lastCollapseCancelTime != null &&
        DateTime.now().difference(_lastCollapseCancelTime!).inMilliseconds < 400) {
      return;
    }
    _isQueueOpening = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const QueueSheet(),
    ).then((_) {
      if (mounted) {
        _isQueueOpening = false;
      }
    });
  }

  void _showSleepTimerDialog(BuildContext context) {
    final playerNotifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(
          'SLEEP TIMER',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimerOption(dialogCtx, playerNotifier, 'OFF', null),
            _buildTimerOption(
              dialogCtx,
              playerNotifier,
              '10 MINUTES',
              const Duration(minutes: 10),
            ),
            _buildTimerOption(
              dialogCtx,
              playerNotifier,
              '20 MINUTES',
              const Duration(minutes: 20),
            ),
            _buildTimerOption(
              dialogCtx,
              playerNotifier,
              '30 MINUTES',
              const Duration(minutes: 30),
            ),
            _buildTimerOption(
              dialogCtx,
              playerNotifier,
              '60 MINUTES',
              const Duration(minutes: 60),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: RetroButton(
                  isCompact: true,
                  height: 36,
                  label: 'CUSTOM CLOCK',
                  backgroundColor: retro.accentYellow,
                  textColor: Colors.black,
                  icon: const RetroIcon('clock', size: 14, color: Colors.black),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    RetroClockTimerDialog.show(
                      context,
                      initialDuration:
                          ref.read(playerProvider).sleepTimerRemaining,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RetroButton(
                  isCompact: true,
                  height: 36,
                  label: 'CLOSE',
                  backgroundColor: retro.cardColor,
                  textColor: theme.colorScheme.onSurface,
                  onPressed: () => Navigator.pop(dialogCtx),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimerOption(
    BuildContext context,
    PlayerNotifier notifier,
    String label,
    Duration? duration,
  ) {
    return ListTile(
      dense: true,
      leading: const RetroIcon('clock', size: 16),
      title: Text(
        label,
        style: RetroTypography.pixelBadge(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 10,
        ),
      ),
      onTap: () {
        notifier.setSleepTimer(duration);
        Navigator.pop(context);
      },
    );
  }
}

/// A layout widget that places children horizontally with an overlapping offset
/// equal to the border width, ensuring that each child retains its full 4-sided
/// border while touching borders visually merge into a single even border line.
class _OverlappingRowParentData extends ContainerBoxParentData<RenderBox> {}

class _OverlappingRow extends MultiChildRenderObjectWidget {
  final double overlap;

  const _OverlappingRow({
    required this.overlap,
    required super.children,
  });

  @override
  _RenderOverlappingRow createRenderObject(BuildContext context) =>
      _RenderOverlappingRow(overlap: overlap);

  @override
  void updateRenderObject(
      BuildContext context, _RenderOverlappingRow renderObject) {
    if (renderObject.overlap != overlap) {
      renderObject.overlap = overlap;
      renderObject.markNeedsLayout();
    }
  }
}

class _RenderOverlappingRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _OverlappingRowParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _OverlappingRowParentData> {
  double overlap;

  _RenderOverlappingRow({required this.overlap});

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _OverlappingRowParentData) {
      child.parentData = _OverlappingRowParentData();
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    double width = 0;
    RenderBox? child = firstChild;
    int index = 0;
    while (child != null) {
      final childParentData =
          child.parentData! as _OverlappingRowParentData;
      final childWidth = child.getMinIntrinsicWidth(height);
      width += (index == 0 ? childWidth : childWidth - overlap);
      child = childParentData.nextSibling;
      index++;
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    double width = 0;
    RenderBox? child = firstChild;
    int index = 0;
    while (child != null) {
      final childParentData =
          child.parentData! as _OverlappingRowParentData;
      final childWidth = child.getMaxIntrinsicWidth(height);
      width += (index == 0 ? childWidth : childWidth - overlap);
      child = childParentData.nextSibling;
      index++;
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    double maxHeight = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData =
          child.parentData! as _OverlappingRowParentData;
      final childHeight = child.getMinIntrinsicHeight(width);
      if (childHeight > maxHeight) maxHeight = childHeight;
      child = childParentData.nextSibling;
    }
    return maxHeight;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    double maxHeight = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final childParentData =
          child.parentData! as _OverlappingRowParentData;
      final childHeight = child.getMaxIntrinsicHeight(width);
      if (childHeight > maxHeight) maxHeight = childHeight;
      child = childParentData.nextSibling;
    }
    return maxHeight;
  }

  @override
  void performLayout() {
    double currentX = 0;
    double maxHeight = 0;
    RenderBox? child = firstChild;
    int index = 0;
    while (child != null) {
      final childParentData =
          child.parentData! as _OverlappingRowParentData;
      child.layout(
        BoxConstraints(
          minHeight: constraints.minHeight,
          maxHeight: constraints.maxHeight,
        ),
        parentUsesSize: true,
      );
      final xOffset = index == 0 ? currentX : currentX - overlap;
      childParentData.offset = Offset(xOffset, 0);
      currentX = xOffset + child.size.width;
      if (child.size.height > maxHeight) {
        maxHeight = child.size.height;
      }
      child = childParentData.nextSibling;
      index++;
    }
    size = Size(currentX, maxHeight);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

