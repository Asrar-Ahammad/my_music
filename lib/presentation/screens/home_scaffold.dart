import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_theme.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/playlist.dart';
import '../providers/navigation_provider.dart';
import '../providers/player_provider.dart';
import '../widgets/mini_player.dart';
import '../widgets/morphing_album_art.dart';
import '../widgets/retro_icon.dart';
import '../widgets/retro_scanline_overlay.dart';
import 'library/library_screen.dart';
import 'now_playing/now_playing_screen.dart';
import 'playlists/playlists_screen.dart';
import 'search/search_screen.dart';

class HomeScaffold extends ConsumerStatefulWidget {
  const HomeScaffold({super.key});

  static HomeScaffoldState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeScaffoldState>();

  @override
  ConsumerState<HomeScaffold> createState() => HomeScaffoldState();
}

class HomeScaffoldState extends ConsumerState<HomeScaffold>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  bool _hasCheckedRestoreNowPlaying = false;
  late final AnimationController _playerExpansionController;
  late final AnimationController _tabBarCollapseController;
  final GlobalKey<LibraryScreenState> _libraryKey = GlobalKey<LibraryScreenState>();
  final GlobalKey<PlaylistsScreenState> _playlistsKey = GlobalKey<PlaylistsScreenState>();
  final GlobalKey<SearchScreenState> _searchKey = GlobalKey<SearchScreenState>();
  final GlobalKey _miniPlayerKey = GlobalKey();

  int get currentIndex => ref.read(homeTabProvider);

  bool get isNowPlayingExpanded => _playerExpansionController.value > 0.001;
  bool get isNowPlayingFullyExpanded => _playerExpansionController.value >= 0.999;
  double get expansionProgress => _playerExpansionController.value;

  void collapseTabBar() {
    if (_tabBarCollapseController.value >= 0.99) return;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _tabBarCollapseController.value = 1.0;
      return;
    }
    _tabBarCollapseController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void expandTabBar() {
    if (_tabBarCollapseController.value <= 0.01) return;
    final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disableAnimations) {
      _tabBarCollapseController.value = 0.0;
      return;
    }
    _tabBarCollapseController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
    );
  }

  void navigateToTab(int index) {
    ref.read(homeTabProvider.notifier).setTab(index);
  }

  void openPlaylist(Playlist playlist, {bool isFavorites = false}) {
    ref.read(homeTabProvider.notifier).openPlaylist(playlist, isFavorites: isFavorites);
    _playlistsKey.currentState?.openPlaylist(playlist, isFavorites: isFavorites);
  }

  void openAlbum(String albumName) {
    ref.read(homeTabProvider.notifier).openAlbum(albumName);
    _libraryKey.currentState?.popToRoot();
  }

  void openArtist(String artistName) {
    ref.read(homeTabProvider.notifier).openArtist(artistName);
    _libraryKey.currentState?.popToRoot();
  }

  // Fluid ease-in-ease-out curve: organic acceleration, continuous glide, feather-soft landing
  static const _fluidCurve = Cubic(0.32, 0.0, 0.20, 1.0);
  // Inertial fling curve: smoothly carries swipe momentum and decelerates like silk
  static const _flingCurve = Cubic(0.22, 0.0, 0.20, 1.0);

  Future<void> expandNowPlaying({double? velocityY}) async {
    StorageService().setNowPlayingDrawerOpen(true);
    final remaining = 1.0 - _playerExpansionController.value;
    final int durationMs;
    final Curve curve;
    if (velocityY != null && velocityY < -180) {
      durationMs = (remaining * 440 * (1000 / (-velocityY).clamp(1000, 2400))).clamp(320, 440).round();
      curve = _flingCurve;
    } else {
      durationMs = (remaining * 440).clamp(320, 440).round();
      curve = _fluidCurve;
    }
    await _playerExpansionController.animateTo(
      1.0,
      duration: Duration(milliseconds: durationMs),
      curve: curve,
    );
  }

  Future<void> collapseNowPlaying({double? velocityY}) async {
    StorageService().setNowPlayingDrawerOpen(false);
    final remaining = _playerExpansionController.value;
    final int durationMs;
    final Curve curve;
    if (velocityY != null && velocityY > 180) {
      durationMs = (remaining * 400 * (1000 / velocityY.clamp(1000, 2400))).clamp(300, 400).round();
      curve = _flingCurve;
    } else {
      durationMs = (remaining * 400).clamp(300, 400).round();
      curve = _fluidCurve;
    }
    await _playerExpansionController.animateTo(
      0.0,
      duration: Duration(milliseconds: durationMs),
      curve: curve,
    );
  }

  void setExpansionProgress(double progress) {
    _playerExpansionController.value = progress.clamp(0.0, 1.0);
  }

  void handleDragUpdate(double delta) {
    final screenHeight = MediaQuery.of(context).size.height;
    if (screenHeight <= 0) return;
    final newProgress = (_playerExpansionController.value - delta / screenHeight).clamp(0.0, 1.0);
    _playerExpansionController.value = newProgress;
  }

  void handleDragEnd(double velocityY) {
    if (velocityY < -180) {
      expandNowPlaying(velocityY: velocityY);
    } else if (velocityY > 180) {
      collapseNowPlaying(velocityY: velocityY);
    } else {
      if (_playerExpansionController.value >= 0.35) {
        expandNowPlaying();
      } else {
        collapseNowPlaying();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemNavigator.setFrameworkHandlesBack(true);
    _playerExpansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _tabBarCollapseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkRestoreNowPlaying();
    });
  }

  void _checkRestoreNowPlaying() {
    if (_hasCheckedRestoreNowPlaying || !mounted) return;
    _hasCheckedRestoreNowPlaying = true;
    final storage = StorageService();
    if (storage.isNowPlayingDrawerOpen()) {
      final playerState = ref.read(playerProvider);
      if (playerState.currentSong != null) {
        expandNowPlaying();
      } else {
        storage.setNowPlayingDrawerOpen(false);
      }
    }
  }

  @override
  void dispose() {
    _playerExpansionController.dispose();
    _tabBarCollapseController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemNavigator.setFrameworkHandlesBack(true);
    }
  }

  bool get _canCurrentTabPop {
    final idx = currentIndex;
    if (idx == 0) {
      return _libraryKey.currentState?.canPop ?? false;
    } else if (idx == 1) {
      return _playlistsKey.currentState?.canPop ?? false;
    } else if (idx == 2) {
      return _searchKey.currentState?.canPop ?? false;
    }
    return false;
  }

  static Future<void> exitApp() async {
    try {
      const channel = MethodChannel('com.retro.mymusic/app_control');
      await channel.invokeMethod('exitToHome');
    } catch (_) {
      await SystemNavigator.pop();
    }
  }

  void _handleBackPress(bool didPop) {
    if (didPop) return;
    if (isNowPlayingExpanded) {
      collapseNowPlaying();
      return;
    }
    if (_canCurrentTabPop) {
      // Child tab handles its own nested navigation
      return;
    }

    final navNotifier = ref.read(homeTabProvider.notifier);
    if (navNotifier.canPopTab()) {
      navNotifier.popTab();
      return;
    }

    // User is on root Library screen - save state and exit app directly.
    // Audio continues playing in background via the foreground service.
    ref.read(audioHandlerProvider).saveCurrentPlaybackState();
    HomeScaffoldState.exitApp();
  }

  @override
  Widget build(BuildContext context) {
    final retro = context.retro;
    final theme = Theme.of(context);
    final isNothing = context.isNothingTheme;
    final currentTab = ref.watch(homeTabProvider);
    final playerState = ref.watch(playerProvider);
    final currentSong = playerState.currentSong;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final topPadding = MediaQuery.paddingOf(context).top;

    double hardwareTop = 0.0;
    try {
      final view = View.maybeOf(context);
      if (view != null && view.devicePixelRatio > 0) {
        hardwareTop = view.viewPadding.top / view.devicePixelRatio;
      }
    } catch (_) {}
    final viewPaddingTop = MediaQuery.viewPaddingOf(context).top;
    final candidates = [
      hardwareTop,
      viewPaddingTop,
      topPadding,
      0.0,
    ];
    final effectiveTop = candidates.reduce((a, b) => a > b ? a : b);

    // Full NowPlaying art geometry (must match now_playing_screen.dart artSize formula exactly)
    final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
    final double artSize;
    final double fullArtLeft;
    final double fullArtTop;

    if (!isLandscape) {
      artSize = (screenWidth - 48).clamp(260.0, (screenHeight * 0.42).clamp(290.0, 390.0));
      final availableBodyHeight = screenHeight - effectiveTop - 16 - bottomPadding;
      final estimatedContent = artSize + 360.0;
      final remainingSpace = (availableBodyHeight - estimatedContent).clamp(0.0, 120.0);
      final gapAboveArt = (remainingSpace * 0.12).clamp(4.0, 14.0);

      fullArtLeft = (screenWidth - artSize) / 2;
      fullArtTop = (effectiveTop > 0 ? effectiveTop + 8.0 : 12.0) + 4.0 + gapAboveArt;
    } else {
      final leftPadding = MediaQuery.paddingOf(context).left;
      final rightPadding = MediaQuery.paddingOf(context).right;
      final safeWidth = screenWidth - leftPadding - rightPadding;
      final leftPanelWidth = safeWidth * (5.0 / 11.0);
      final leftContentWidth = (leftPanelWidth - 32.0).clamp(0.0, screenWidth);
      // Badges + spacing in landscape column consume ~34px
      final expandedHeight = (screenHeight - 8.0 - bottomPadding - 16.0 - 34.0).clamp(0.0, screenHeight);
      artSize = leftContentWidth < expandedHeight ? leftContentWidth : expandedHeight;
      fullArtLeft = leftPadding + 20.0 + (leftContentWidth - artSize) / 2;
      fullArtTop = 8.0 + 4.0 + (expandedHeight - artSize) / 2;
    }

    // MiniPlayer art geometry (global coordinates)
    const miniArtLeft = 10.0;
    final miniPlayerGlobalTop = screenHeight - (64.0 + 58.5 + bottomPadding);
    final miniArtTop = miniPlayerGlobalTop + 11.5;
    const miniArtSize = 44.0;

    double effectiveMiniArtLeft = miniArtLeft;
    double effectiveMiniArtTop = miniArtTop;
    final miniBox = _miniPlayerKey.currentContext?.findRenderObject() as RenderBox?;
    if (miniBox != null && miniBox.hasSize && miniBox.attached) {
      final pos = miniBox.localToGlobal(Offset.zero);
      effectiveMiniArtTop = pos.dy + 11.5;
      effectiveMiniArtLeft = pos.dx + 10.0;
    }

    final screens = [
      LibraryScreen(key: _libraryKey, isActive: currentTab == 0),
      PlaylistsScreen(key: _playlistsKey, isActive: currentTab == 1),
      SearchScreen(key: _searchKey, isActive: currentTab == 2),
    ];

    final persistentMiniPlayer = AnimatedBuilder(
      animation: _playerExpansionController,
      builder: (context, _) {
        final t = _playerExpansionController.value;
        final miniPlayerOpacity = (1.0 - (t - 0.15) / 0.23).clamp(0.0, 1.0);
        return Opacity(
          opacity: miniPlayerOpacity,
          child: MiniPlayer(
            key: _miniPlayerKey,
            hideCoverArt: t > 0.001,
          ),
        );
      },
    );

    final scaffoldBody = IndexedStack(
      index: currentTab,
      children: screens,
    );

    return NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        // Intercept navigation notifications from nested child navigators so they
        // do not bubble to WidgetsApp._defaultOnNavigationNotification, which would
        // call SystemNavigator.setFrameworkHandlesBack(false) and unregister Android's
        // OnBackInvokedCallback (bypassing PopScope and prematurely exiting the app).
        SystemNavigator.setFrameworkHandlesBack(true);
        return true;
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) => _handleBackPress(didPop),
        child: ColoredBox(
          color: theme.scaffoldBackgroundColor,
          child: RetroScanlineOverlay(
            opacity: 0.03,
            child: Stack(
            children: [
              Scaffold(
                body: scaffoldBody,
                bottomNavigationBar: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    persistentMiniPlayer,

                          // Bottom Navigation
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: isNothing ? context.nothing.dividerColor : retro.borderColor,
                                  width: isNothing ? 0.5 : retro.borderWidth,
                                ),
                              ),
                            ),
                            child: BottomNavigationBar(
                              currentIndex: currentTab,
                              onTap: (index) {
                                if (currentTab == 0 && index == 0) {
                                  _libraryKey.currentState?.popToRoot();
                                } else if (currentTab == 1 && index == 1) {
                                  _playlistsKey.currentState?.popToRoot();
                                } else if (currentTab == 2 && index == 2) {
                                  _searchKey.currentState?.popToRoot();
                                  _searchKey.currentState?.focusSearchInput();
                                }
                                // Tapping the search icon from any other tab also
                                // focuses the input once the tab transition settles.
                                if (index == 2 && currentTab != 2) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    _searchKey.currentState?.focusSearchInput();
                                  });
                                }
                                ref.read(homeTabProvider.notifier).setTab(index);
                              },
                              items: [
                                BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: RetroIcon(
                                      'music',
                                      size: 20,
                                      color: currentTab == 0
                                          ? theme.colorScheme.primary
                                          : (theme.bottomNavigationBarTheme.unselectedItemColor ?? (isNothing ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : retro.borderColor)),
                                    ),
                                  ),
                                  label: isNothing ? 'Library' : 'LIBRARY',
                                ),
                                BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: RetroIcon(
                                      'folder',
                                      size: 20,
                                      color: currentTab == 1
                                          ? theme.colorScheme.primary
                                          : (theme.bottomNavigationBarTheme.unselectedItemColor ?? (isNothing ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : retro.borderColor)),
                                    ),
                                  ),
                                  label: isNothing ? 'Playlists' : 'PLAYLISTS',
                                ),
                                BottomNavigationBarItem(
                                  icon: Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: RetroIcon(
                                      'search',
                                      size: 20,
                                      color: currentTab == 2
                                          ? theme.colorScheme.primary
                                          : (theme.bottomNavigationBarTheme.unselectedItemColor ?? (isNothing ? theme.colorScheme.onSurface.withValues(alpha: 0.4) : retro.borderColor)),
                                    ),
                                  ),
                                  label: isNothing ? 'Search' : 'SEARCH',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              // Expanding NowPlayingScreen and Morphing Album Art layer
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _playerExpansionController,
                  builder: (context, _) {
                    final t = _playerExpansionController.value;
                    if (t <= 0.0 || currentSong == null) {
                      return const SizedBox.shrink();
                    }

                    final panelTop = (1.0 - t) * screenHeight;
                    final nowPlayingOpacity = (0.85 + 0.15 * (t / 0.25)).clamp(0.0, 1.0);

                    // Target art position inside NowPlayingScreen slot
                    final slotTop = panelTop + fullArtTop;

                    // Cover art coordinates with smooth trajectory:
                    // Starts at MiniPlayer art position and seamlessly locks into NowPlaying slot
                    final linearArtTop = effectiveMiniArtTop + (fullArtTop - effectiveMiniArtTop) * t;
                    final double currentArtTop;
                    if (t >= 0.70) {
                      final blendFactor = ((t - 0.70) / 0.30).clamp(0.0, 1.0);
                      final smoothBlend = blendFactor * blendFactor * (3.0 - 2.0 * blendFactor);
                      currentArtTop = (1.0 - smoothBlend) * linearArtTop + smoothBlend * slotTop;
                    } else {
                      currentArtTop = linearArtTop;
                    }
                    final currentArtLeft = effectiveMiniArtLeft + (fullArtLeft - effectiveMiniArtLeft) * t;
                    final currentArtSize = miniArtSize + (artSize - miniArtSize) * t;

                    final isFullyExpanded = t >= 0.999;
                    final isFullyCollapsed = t <= 0.001;

                    return IgnorePointer(
                      ignoring: t <= 0.0,
                      child: Stack(
                        children: [
                          // Sliding NowPlayingScreen panel with GPU-composited translation & repaint boundary
                          Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            height: screenHeight,
                            child: Transform.translate(
                              offset: Offset(0, panelTop),
                              child: RepaintBoundary(
                                child: Opacity(
                                  opacity: nowPlayingOpacity,
                                  child: PopScope(
                                    canPop: !isNowPlayingExpanded,
                                    onPopInvokedWithResult: (didPop, result) {
                                      if (didPop) return;
                                      if (isNowPlayingExpanded) {
                                        collapseNowPlaying();
                                      }
                                    },
                                    child: NowPlayingScreen(
                                      isDrawer: false,
                                      topPadding: effectiveTop,
                                      hideCoverArt: !isFullyExpanded,
                                      isExpanded: t >= 0.5,
                                      onCollapse: collapseNowPlaying,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Morphing album art layer (animates scaling between mini and full)
                          if (!isFullyCollapsed && !isFullyExpanded)
                            Positioned(
                              left: currentArtLeft,
                              top: currentArtTop,
                              width: currentArtSize,
                              height: currentArtSize,
                              child: RepaintBoundary(
                                child: IgnorePointer(
                                  child: MorphingAlbumArt(
                                    song: currentSong,
                                    progress: t,
                                    miniSize: miniArtSize,
                                    fullSize: artSize,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
