import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../domain/models/recently_played_item.dart';
import '../../providers/library_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/playlist_provider.dart';
import '../../providers/recently_played_provider.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_loading_state.dart';
import '../../widgets/scan_options_dialog.dart';
import '../home_scaffold.dart';
import '../../../data/services/storage_service.dart';
import '../settings/settings_screen.dart';
import '../sound_capsule/sound_capsule_screen.dart';
import 'tabs/all_songs_tab.dart';
import 'tabs/albums_tab.dart';
import 'tabs/artists_tab.dart';
import 'tabs/folders_tab.dart';
import 'widgets/recently_played_grid.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  final bool isActive;

  const LibraryScreen({
    super.key,
    this.isActive = true,
  });

  @override
  ConsumerState<LibraryScreen> createState() => LibraryScreenState();
}

class _LibraryNavigatorObserver extends NavigatorObserver {
  final VoidCallback onNavigationChanged;

  _LibraryNavigatorObserver(this.onNavigationChanged);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onNavigationChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onNavigationChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onNavigationChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    onNavigationChanged();
  }
}

class LibraryScreenState extends ConsumerState<LibraryScreen> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final _LibraryNavigatorObserver _observer;
  bool _canPop = false;

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
  bool get canPop => _navigatorKey.currentState?.canPop() ?? false;

  void popToRoot() {
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  void initState() {
    super.initState();
    _observer = _LibraryNavigatorObserver(() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final canPop = _navigatorKey.currentState?.canPop() ?? false;
        if (_canPop != canPop) {
          setState(() {
            _canPop = canPop;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LibraryTabTarget?>(libraryTabRequestProvider, (prev, next) {
      if (next != null && canPop) {
        popToRoot();
      }
    });

    final home = HomeScaffold.of(context);
    final isNowPlayingOpen = (home != null && home.isNowPlayingExpanded) ||
        StorageService().isNowPlayingDrawerOpen();

    return PopScope(
      canPop: isNowPlayingOpen ? false : (!widget.isActive || !_canPop),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !widget.isActive) return;
        final home = HomeScaffold.of(context);
        if ((home != null && home.isNowPlayingExpanded) ||
            StorageService().isNowPlayingDrawerOpen()) {
          return;
        }
        if (_navigatorKey.currentState?.canPop() ?? false) {
          _navigatorKey.currentState?.pop();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        observers: [_observer],
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            settings: settings,
            builder: (context) => const _LibraryTabsScreen(),
          );
        },
      ),
    );
  }
}

class _LibraryTabsScreen extends ConsumerStatefulWidget {
  const _LibraryTabsScreen();

  @override
  ConsumerState<_LibraryTabsScreen> createState() => _LibraryTabsScreenState();
}

class _LibraryTabsScreenState extends ConsumerState<_LibraryTabsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _showScrollToTop = ValueNotifier<bool>(false);
  BuildContext? _innerContext;

  bool _songsSearchOpen = false;
  final TextEditingController _songsSearchController = TextEditingController();
  final FocusNode _songsSearchFocusNode = FocusNode();

  bool _albumsSearchOpen = false;
  final TextEditingController _albumsSearchController = TextEditingController();
  final FocusNode _albumsSearchFocusNode = FocusNode();

  bool _artistsSearchOpen = false;
  final TextEditingController _artistsSearchController = TextEditingController();
  final FocusNode _artistsSearchFocusNode = FocusNode();

  bool _foldersSearchOpen = false;
  final TextEditingController _foldersSearchController = TextEditingController();
  final FocusNode _foldersSearchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingTabRequest();
    });
  }

  void _checkPendingTabRequest() {
    if (!mounted) return;
    final pending = ref.read(libraryTabRequestProvider);
    if (pending != null) {
      _handleTabRequest(pending);
    }
  }

  void _handleTabRequest(LibraryTabTarget target) {
    if (target.tabIndex >= 0 && target.tabIndex < _tabController.length) {
      _tabController.animateTo(target.tabIndex);
    }
    if (target.tabIndex == 1 && target.filterQuery != null) {
      setState(() {
        _albumsSearchOpen = true;
        _albumsSearchController.text = target.filterQuery!;
      });
      ref.read(albumSearchProvider.notifier).state = target.filterQuery!;
    } else if (target.tabIndex == 2 && target.filterQuery != null) {
      setState(() {
        _artistsSearchOpen = true;
        _artistsSearchController.text = target.filterQuery!;
      });
      ref.read(artistSearchProvider.notifier).state = target.filterQuery!;
    }
    ref.read(libraryTabRequestProvider.notifier).clear();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _showScrollToTop.dispose();
    _songsSearchController.dispose();
    _songsSearchFocusNode.dispose();
    _albumsSearchController.dispose();
    _albumsSearchFocusNode.dispose();
    _artistsSearchController.dispose();
    _artistsSearchFocusNode.dispose();
    _foldersSearchController.dispose();
    _foldersSearchFocusNode.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_innerContext != null) {
      final innerController = PrimaryScrollController.maybeOf(_innerContext!);
      if (innerController != null) {
        for (final position in innerController.positions) {
          try {
            position.jumpTo(0);
          } catch (_) {}
        }
      }
    }
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Widget _buildSongsToolbar(BuildContext context, ThemeData theme, RetroThemeTokens retro) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final songs = libraryState.filteredSongs;
    final totalCount = libraryState.allSongs.length;
    final filteredCount = songs.length;
    final isFiltering = libraryState.searchQuery.trim().isNotEmpty;
    final songSelection = ref.watch(songSelectionProvider);

    if (songSelection.isSelecting) {
      final selectedCount = songSelection.selectedIds.length;
      final allIds = songs.map((s) => s.id).toList();
      final allSelected = allIds.isNotEmpty && songSelection.selectedIds.containsAll(allIds);

      return Row(
        children: [
          RetroBadge(
            text: '$selectedCount SELECTED',
            backgroundColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
          RetroButton(
            isCompact: true,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            label: allSelected ? 'DESELECT' : 'SELECT ALL',
            backgroundColor: retro.cardColor,
            borderColor: retro.borderColor,
            onPressed: () {
              if (allSelected) {
                ref.read(songSelectionProvider.notifier).clearSelection();
              } else {
                ref.read(songSelectionProvider.notifier).selectAll(allIds);
              }
            },
          ),
          const Spacer(),
          if (selectedCount > 0)
            RetroButton(
              isCompact: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              label: 'ADD TO PLAYLIST',
              icon: RetroIcon('playlist', size: 11, color: theme.colorScheme.onPrimary),
              backgroundColor: theme.colorScheme.primary,
              onPressed: () {
                showAddToPlaylistBottomSheet(
                  context,
                  ref,
                  songSelection.selectedIds.toList(),
                  onDone: () => ref.read(songSelectionProvider.notifier).exitSelectionMode(),
                );
              },
            ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => ref.read(songSelectionProvider.notifier).exitSelectionMode(),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: RetroIcon('close', size: 14, color: theme.colorScheme.onSurface),
            ),
          ),
        ],
      );
    }

    if (_songsSearchOpen) {
      return Row(
        children: [
          RetroBadge(
            text: isFiltering ? '$filteredCount/$totalCount' : '$totalCount TRACKS',
            backgroundColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, right: 6),
                    child: RetroIcon('search', size: 14),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _songsSearchController,
                      focusNode: _songsSearchFocusNode,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.search,
                      onTapOutside: (_) => _songsSearchFocusNode.unfocus(),
                      onSubmitted: (_) => _songsSearchFocusNode.unfocus(),
                      onChanged: (val) => libraryNotifier.setSearchQuery(val),
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 9.5,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        hintText: 'SEARCH SONGS...',
                        hintStyle: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 8.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_songsSearchController.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _songsSearchController.clear();
                        libraryNotifier.setSearchQuery('');
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: RetroIcon('close', size: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildSongsSortMenu(theme, retro, libraryState, libraryNotifier),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _songsSearchOpen = false;
                _songsSearchController.clear();
                libraryNotifier.setSearchQuery('');
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              decoration: BoxDecoration(
                color: retro.cardColor,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: const RetroIcon('close', size: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        RetroBadge(
          text: isFiltering ? '$filteredCount/$totalCount TRACKS' : '$totalCount TRACKS',
          backgroundColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onPrimary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _songsSearchOpen = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _songsSearchFocusNode.requestFocus();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RetroIcon('search', size: 13, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 4),
                          Text(
                            'SEARCH TRACKS',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildSongsSortMenu(theme, retro, libraryState, libraryNotifier),
                  const SizedBox(width: 6),
                  RetroButton(
                    isCompact: true,
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    backgroundColor: retro.accentGreen,
                    textColor: Colors.black,
                    onPressed: () => ScanOptionsDialog.show(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RetroIcon('plus', size: 11, color: Colors.black),
                        const SizedBox(width: 3),
                        Text(
                          'IMPORT',
                          style: RetroTypography.pixelBadge(color: Colors.black, fontSize: 8.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSongsSortMenu(
    ThemeData theme,
    RetroThemeTokens retro,
    LibraryState libraryState,
    LibraryNotifier libraryNotifier,
  ) {
    final isAsc = libraryState.sortAscending;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<SongSortMode>(
          tooltip: "Sort songs",
          color: retro.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: retro.borderColor, width: 2.0),
            borderRadius: BorderRadius.zero,
          ),
          onSelected: (mode) => libraryNotifier.setSortMode(mode),
          itemBuilder: (context) => [
            _buildSongSortMenuItem(theme, SongSortMode.title, 'SORT BY TITLE', libraryState),
            _buildSongSortMenuItem(theme, SongSortMode.artist, 'SORT BY ARTIST', libraryState),
            _buildSongSortMenuItem(theme, SongSortMode.duration, 'SORT BY DURATION', libraryState),
            _buildSongSortMenuItem(theme, SongSortMode.format, 'SORT BY FORMAT', libraryState),
            _buildSongSortMenuItem(theme, SongSortMode.date, 'SORT BY DATE', libraryState),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: retro.borderColor, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RetroIcon('sort', size: 13, color: theme.colorScheme.onSurface),
                const SizedBox(width: 4),
                Text(
                  libraryState.sortMode.name.toUpperCase(),
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 3),
        _buildSortDirectionButton(
          theme: theme,
          retro: retro,
          isAscending: isAsc,
          onToggle: () => libraryNotifier.toggleSortDirection(),
          tooltip: "Tracks",
        ),
      ],
    );
  }

  PopupMenuItem<SongSortMode> _buildSongSortMenuItem(
    ThemeData theme,
    SongSortMode mode,
    String label,
    LibraryState state,
  ) {
    final isSelected = state.sortMode == mode;
    return PopupMenuItem<SongSortMode>(
      value: mode,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: RetroTypography.pixelBadge(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              fontSize: 9,
            ),
          ),
          const SizedBox(width: 8),
          if (isSelected)
            RetroIcon(
              state.sortAscending ? 'arrow_up' : 'arrow_down',
              size: 11,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildSortDirectionButton({
    required ThemeData theme,
    required RetroThemeTokens retro,
    required bool isAscending,
    required VoidCallback onToggle,
    String tooltip = "Sort",
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: Tooltip(
        message: isAscending
            ? "$tooltip: Ascending (tap for descending)"
            : "$tooltip: Descending (tap for ascending)",
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: retro.borderColor, width: 1.5),
            borderRadius: BorderRadius.zero,
          ),
          child: RetroIcon(
            isAscending ? 'arrow_up' : 'arrow_down',
            size: 13,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumsToolbar(BuildContext context, ThemeData theme, RetroThemeTokens retro) {
    final libraryState = ref.watch(libraryProvider);
    final isGridView = ref.watch(albumViewModeProvider);
    final allAlbums = libraryState.albums;
    final totalCount = allAlbums.length;
    final query = ref.watch(albumSearchProvider);
    final sortMode = ref.watch(albumSortModeProvider);

    final filteredAlbums = allAlbums.where((album) {
      if (query.isEmpty) return true;
      return album.title.toLowerCase().contains(query.toLowerCase()) ||
          album.artist.toLowerCase().contains(query.toLowerCase());
    }).toList();
    final filteredCount = filteredAlbums.length;
    final isFiltering = query.isNotEmpty;

    if (_albumsSearchOpen) {
      return Row(
        children: [
          RetroBadge(
            text: '$filteredCount/$totalCount',
            backgroundColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, right: 6),
                    child: RetroIcon('search', size: 14),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _albumsSearchController,
                      focusNode: _albumsSearchFocusNode,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.search,
                      onTapOutside: (_) => _albumsSearchFocusNode.unfocus(),
                      onSubmitted: (_) => _albumsSearchFocusNode.unfocus(),
                      onChanged: (val) => ref.read(albumSearchProvider.notifier).state = val,
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 9.5,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        hintText: 'SEARCH ALBUMS...',
                        hintStyle: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 8.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_albumsSearchController.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _albumsSearchController.clear();
                        ref.read(albumSearchProvider.notifier).state = '';
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: RetroIcon('close', size: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildAlbumsSortMenu(theme, retro, sortMode),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _albumsSearchOpen = false;
                _albumsSearchController.clear();
                ref.read(albumSearchProvider.notifier).state = '';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              decoration: BoxDecoration(
                color: retro.cardColor,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: const RetroIcon('close', size: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        RetroBadge(
          text: isFiltering ? '$filteredCount/$totalCount' : '$totalCount ALBUMS',
          backgroundColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onPrimary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _albumsSearchOpen = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _albumsSearchFocusNode.requestFocus();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RetroIcon('search', size: 13, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 4),
                          Text(
                            'SEARCH ALBUMS',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildAlbumsSortMenu(theme, retro, sortMode),
                  const SizedBox(width: 6),
                  _buildViewToggle(
                    theme: theme,
                    retro: retro,
                    isGridView: isGridView,
                    onToggle: (grid) => ref.read(albumViewModeProvider.notifier).setGridView(grid),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlbumsSortMenu(ThemeData theme, RetroThemeTokens retro, String currentMode) {
    final isAsc = ref.watch(albumSortAscendingProvider);
    String label = currentMode.toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          tooltip: "Sort albums",
          color: retro.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: retro.borderColor, width: 2.0),
            borderRadius: BorderRadius.zero,
          ),
          onSelected: (mode) {
            if (currentMode == mode) {
              ref.read(albumSortAscendingProvider.notifier).toggle();
            } else {
              ref.read(albumSortModeProvider.notifier).set(mode);
              ref.read(albumSortAscendingProvider.notifier).set(true);
            }
          },
          itemBuilder: (context) => [
            _buildGenericSortMenuItem(theme, 'title', 'SORT BY TITLE', currentMode, isAsc),
            _buildGenericSortMenuItem(theme, 'artist', 'SORT BY ARTIST', currentMode, isAsc),
            _buildGenericSortMenuItem(theme, 'tracks', 'SORT BY TRACKS', currentMode, isAsc),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: retro.borderColor, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RetroIcon('sort', size: 13, color: theme.colorScheme.onSurface),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 3),
        _buildSortDirectionButton(
          theme: theme,
          retro: retro,
          isAscending: isAsc,
          onToggle: () => ref.read(albumSortAscendingProvider.notifier).toggle(),
          tooltip: "Albums",
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildGenericSortMenuItem(
    ThemeData theme,
    String value,
    String label,
    String currentMode,
    bool isAsc,
  ) {
    final isSelected = currentMode == value;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: RetroTypography.pixelBadge(
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              fontSize: 9,
            ),
          ),
          const SizedBox(width: 8),
          if (isSelected)
            RetroIcon(
              isAsc ? 'arrow_up' : 'arrow_down',
              size: 11,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }

  Widget _buildArtistsToolbar(BuildContext context, ThemeData theme, RetroThemeTokens retro) {
    final libraryState = ref.watch(libraryProvider);
    final isGridView = ref.watch(artistViewModeProvider);
    final allArtists = libraryState.artists;
    final totalCount = allArtists.length;
    final query = ref.watch(artistSearchProvider);
    final sortMode = ref.watch(artistSortModeProvider);

    final filteredArtists = allArtists.where((artist) {
      if (query.isEmpty) return true;
      return artist.name.toLowerCase().contains(query.toLowerCase());
    }).toList();
    final filteredCount = filteredArtists.length;
    final isFiltering = query.isNotEmpty;

    if (_artistsSearchOpen) {
      return Row(
        children: [
          RetroBadge(
            text: '$filteredCount/$totalCount',
            backgroundColor: theme.colorScheme.primary,
            textColor: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, right: 6),
                    child: RetroIcon('search', size: 14),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _artistsSearchController,
                      focusNode: _artistsSearchFocusNode,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.search,
                      onTapOutside: (_) => _artistsSearchFocusNode.unfocus(),
                      onSubmitted: (_) => _artistsSearchFocusNode.unfocus(),
                      onChanged: (val) => ref.read(artistSearchProvider.notifier).state = val,
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 9.5,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        hintText: 'SEARCH ARTISTS...',
                        hintStyle: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 8.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_artistsSearchController.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _artistsSearchController.clear();
                        ref.read(artistSearchProvider.notifier).state = '';
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: RetroIcon('close', size: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildArtistsSortMenu(theme, retro, sortMode),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _artistsSearchOpen = false;
                _artistsSearchController.clear();
                ref.read(artistSearchProvider.notifier).state = '';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              decoration: BoxDecoration(
                color: retro.cardColor,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: const RetroIcon('close', size: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        RetroBadge(
          text: isFiltering ? '$filteredCount/$totalCount' : '$totalCount ARTISTS',
          backgroundColor: theme.colorScheme.primary,
          textColor: theme.colorScheme.onPrimary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _artistsSearchOpen = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _artistsSearchFocusNode.requestFocus();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RetroIcon('search', size: 13, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 4),
                          Text(
                            'SEARCH ARTISTS',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildArtistsSortMenu(theme, retro, sortMode),
                  const SizedBox(width: 6),
                  _buildViewToggle(
                    theme: theme,
                    retro: retro,
                    isGridView: isGridView,
                    onToggle: (grid) => ref.read(artistViewModeProvider.notifier).setGridView(grid),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildArtistsSortMenu(ThemeData theme, RetroThemeTokens retro, String currentMode) {
    final isAsc = ref.watch(artistSortAscendingProvider);
    String label = currentMode.toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          tooltip: "Sort artists",
          color: retro.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: retro.borderColor, width: 2.0),
            borderRadius: BorderRadius.zero,
          ),
          onSelected: (mode) {
            if (currentMode == mode) {
              ref.read(artistSortAscendingProvider.notifier).toggle();
            } else {
              ref.read(artistSortModeProvider.notifier).set(mode);
              ref.read(artistSortAscendingProvider.notifier).set(true);
            }
          },
          itemBuilder: (context) => [
            _buildGenericSortMenuItem(theme, 'name', 'SORT BY NAME', currentMode, isAsc),
            _buildGenericSortMenuItem(theme, 'tracks', 'SORT BY TRACKS', currentMode, isAsc),
            _buildGenericSortMenuItem(theme, 'albums', 'SORT BY ALBUMS', currentMode, isAsc),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: retro.borderColor, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RetroIcon('sort', size: 13, color: theme.colorScheme.onSurface),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 3),
        _buildSortDirectionButton(
          theme: theme,
          retro: retro,
          isAscending: isAsc,
          onToggle: () => ref.read(artistSortAscendingProvider.notifier).toggle(),
          tooltip: "Artists",
        ),
      ],
    );
  }

  Widget _buildFoldersToolbar(BuildContext context, ThemeData theme, RetroThemeTokens retro) {
    final libraryState = ref.watch(libraryProvider);
    final rawFolders = libraryState.folders;
    final totalCount = rawFolders.length;
    final query = ref.watch(folderSearchProvider);
    final sortMode = ref.watch(folderSortModeProvider);

    final filteredFolders = rawFolders.keys.where((folderPath) {
      if (query.isEmpty) return true;
      final folderName = folderPath.contains('/')
          ? folderPath.split('/').where((s) => s.isNotEmpty).last
          : folderPath;
      return folderName.toLowerCase().contains(query.toLowerCase()) ||
          folderPath.toLowerCase().contains(query.toLowerCase());
    }).toList();
    final filteredCount = filteredFolders.length;
    final isFiltering = query.isNotEmpty;

    if (_foldersSearchOpen) {
      return Row(
        children: [
          RetroBadge(
            text: '$filteredCount/$totalCount',
            backgroundColor: theme.colorScheme.secondary,
            textColor: theme.colorScheme.onSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, right: 6),
                    child: RetroIcon('search', size: 14),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _foldersSearchController,
                      focusNode: _foldersSearchFocusNode,
                      textAlignVertical: TextAlignVertical.center,
                      textInputAction: TextInputAction.search,
                      onTapOutside: (_) => _foldersSearchFocusNode.unfocus(),
                      onSubmitted: (_) => _foldersSearchFocusNode.unfocus(),
                      onChanged: (val) => ref.read(folderSearchProvider.notifier).state = val,
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 9.5,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: true,
                        hintText: 'SEARCH FOLDERS...',
                        hintStyle: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontSize: 8.5,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (_foldersSearchController.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _foldersSearchController.clear();
                        ref.read(folderSearchProvider.notifier).state = '';
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        child: RetroIcon('close', size: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          _buildFoldersSortMenu(theme, retro, sortMode),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _foldersSearchOpen = false;
                _foldersSearchController.clear();
                ref.read(folderSearchProvider.notifier).state = '';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
              decoration: BoxDecoration(
                color: retro.cardColor,
                border: Border.all(color: retro.borderColor, width: 1.5),
              ),
              child: const RetroIcon('close', size: 12),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        RetroBadge(
          text: isFiltering ? '$filteredCount/$totalCount' : '$totalCount FOLDERS',
          backgroundColor: theme.colorScheme.secondary,
          textColor: theme.colorScheme.onSecondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _foldersSearchOpen = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _foldersSearchFocusNode.requestFocus();
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RetroIcon('search', size: 13, color: theme.colorScheme.onSurface),
                          const SizedBox(width: 4),
                          Text(
                            'SEARCH FOLDERS',
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 8.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildFoldersSortMenu(theme, retro, sortMode),
                  const SizedBox(width: 6),
                  RetroButton(
                    isCompact: true,
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    backgroundColor: retro.accentGreen,
                    textColor: Colors.black,
                    onPressed: () => ScanOptionsDialog.show(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RetroIcon('plus', size: 11, color: Colors.black),
                        const SizedBox(width: 3),
                        Text(
                          'SCAN',
                          style: RetroTypography.pixelBadge(color: Colors.black, fontSize: 8.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoldersSortMenu(ThemeData theme, RetroThemeTokens retro, String currentMode) {
    final isAsc = ref.watch(folderSortAscendingProvider);
    String label = currentMode.toUpperCase();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          tooltip: "Sort folders",
          color: retro.cardColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: retro.borderColor, width: 2.0),
            borderRadius: BorderRadius.zero,
          ),
          onSelected: (mode) {
            if (currentMode == mode) {
              ref.read(folderSortAscendingProvider.notifier).toggle();
            } else {
              ref.read(folderSortModeProvider.notifier).set(mode);
              ref.read(folderSortAscendingProvider.notifier).set(true);
            }
          },
          itemBuilder: (context) => [
            _buildGenericSortMenuItem(theme, 'name', 'SORT BY NAME', currentMode, isAsc),
            _buildGenericSortMenuItem(theme, 'tracks', 'SORT BY TRACKS', currentMode, isAsc),
            _buildGenericSortMenuItem(theme, 'path', 'SORT BY PATH', currentMode, isAsc),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: retro.borderColor, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RetroIcon('sort', size: 13, color: theme.colorScheme.onSurface),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 3),
        _buildSortDirectionButton(
          theme: theme,
          retro: retro,
          isAscending: isAsc,
          onToggle: () => ref.read(folderSortAscendingProvider.notifier).toggle(),
          tooltip: "Folders",
        ),
      ],
    );
  }

  Widget _buildViewToggle({
    required ThemeData theme,
    required RetroThemeTokens retro,
    required bool isGridView,
    required ValueChanged<bool> onToggle,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        RetroButton(
          isCompact: true,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          backgroundColor: !isGridView ? theme.colorScheme.primary : retro.cardColor,
          borderColor: !isGridView ? theme.colorScheme.primary : retro.borderColor,
          icon: RetroIcon(
            'list',
            size: 13,
            color: !isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
          textColor: !isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          onPressed: () => onToggle(false),
        ),
        const SizedBox(width: 4),
        RetroButton(
          isCompact: true,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          backgroundColor: isGridView ? theme.colorScheme.primary : retro.cardColor,
          borderColor: isGridView ? theme.colorScheme.primary : retro.borderColor,
          icon: RetroIcon(
            'grid',
            size: 13,
            color: isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          ),
          textColor: isGridView ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
          onPressed: () => onToggle(true),
        ),
      ],
    );
  }

  Widget _buildActiveToolbar(BuildContext context, ThemeData theme, RetroThemeTokens retro) {
    switch (_tabController.index) {
      case 0:
        return _buildSongsToolbar(context, theme, retro);
      case 1:
        return _buildAlbumsToolbar(context, theme, retro);
      case 2:
        return _buildArtistsToolbar(context, theme, retro);
      case 3:
        return _buildFoldersToolbar(context, theme, retro);
      default:
        return _buildSongsToolbar(context, theme, retro);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LibraryTabTarget?>(libraryTabRequestProvider, (prev, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleTabRequest(next);
        });
      }
    });

    final theme = Theme.of(context);
    final retro = context.retro;
    final libraryState = ref.watch(libraryProvider);
    final recentItems = ref.watch(recentlyPlayedProvider);
    final playlistState = ref.watch(playlistProvider);
    final existingPlaylistIds = playlistState.playlists.map((p) => p.id.toLowerCase()).toSet();
    final existingPlaylistNames = playlistState.playlists.map((p) => p.name.toLowerCase()).toSet();
    final hasRecentItems = recentItems.any((item) {
      if (item.type == RecentItemType.playlist) {
        return existingPlaylistIds.contains(item.id.toLowerCase()) ||
            existingPlaylistNames.contains(item.title.toLowerCase());
      }
      return true;
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'LIBRARY',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
        actions: [
          IconButton(
            icon: RetroIcon('sound_capsule', size: 20, color: theme.colorScheme.onSurface),
            tooltip: 'Sound Capsule',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SoundCapsuleScreen()),
              );
            },
          ),
          IconButton(
            icon: RetroIcon('settings', size: 20, color: theme.colorScheme.onSurface),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _showScrollToTop,
        builder: (context, show, _) {
          if (!show) return const SizedBox.shrink();
          return Container(
            margin: const EdgeInsets.only(bottom: 12, right: 4),
            child: RetroButton(
              isCompact: true,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              backgroundColor: retro.cardColor,
              borderColor: theme.colorScheme.primary,
              borderWidth: 2.0,
              icon: RotatedBox(
                quarterTurns: 2,
                child: RetroIcon(
                  'arrow_down',
                  size: 14,
                  color: theme.colorScheme.primary,
                ),
              ),
              label: 'TOP',
              textColor: theme.colorScheme.primary,
              onPressed: _scrollToTop,
            ),
          );
        },
      ),
      body: libraryState.isLoading && libraryState.allSongs.isEmpty
          ? const RetroLoadingState(
              title: 'FETCHING FROM STORAGE...',
              subtitle: 'SCANNING AUDIO FILES & EXTRACTING METADATA',
              badgeText: 'LOADING LIBRARY',
            )
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical) {
                  final offset = notification.metrics.pixels;
                  final show = offset > 150 ||
                      (_scrollController.hasClients && _scrollController.offset > 50);
                  if (show != _showScrollToTop.value) {
                    _showScrollToTop.value = show;
                  }
                }
                return false;
              },
              child: NestedScrollView(
                controller: _scrollController,
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return [
                    if (hasRecentItems)
                      const SliverToBoxAdapter(
                        child: RecentlyPlayedGrid(),
                      ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyTabBarDelegate(
                        tabBar: TabBar(
                          controller: _tabController,
                          indicatorColor: theme.colorScheme.primary,
                          indicatorWeight: 3.5,
                          tabs: const [
                            Tab(text: 'SONGS'),
                            Tab(text: 'ALBUMS'),
                            Tab(text: 'ARTISTS'),
                            Tab(text: 'FOLDERS'),
                          ],
                        ),
                        toolbar: _buildActiveToolbar(context, theme, retro),
                        backgroundColor: retro.cardColor,
                        borderColor: retro.borderColor,
                        borderWidth: retro.borderWidth,
                      ),
                    ),
                  ];
                },
                body: Builder(
                  builder: (innerContext) {
                    _innerContext = innerContext;
                    return TabBarView(
                      controller: _tabController,
                      children: const [
                        AllSongsTab(showToolbar: false),
                        AlbumsTab(showToolbar: false),
                        ArtistsTab(showToolbar: false),
                        FoldersTab(showToolbar: false),
                      ],
                    );
                  },
                ),
              ),
            ),
    );
  }
}

class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Widget toolbar;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  static const double toolbarHeight = 50.0;

  _StickyTabBarDelegate({
    required this.tabBar,
    required this.toolbar,
    required this.backgroundColor,
    required this.borderColor,
    this.borderWidth = 1.5,
  });

  @override
  double get minExtent => tabBar.preferredSize.height + toolbarHeight;

  @override
  double get maxExtent => tabBar.preferredSize.height + toolbarHeight;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          Container(
            height: toolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                bottom: BorderSide(
                  color: borderColor,
                  width: borderWidth,
                ),
              ),
            ),
            child: toolbar,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return true;
  }
}

class RetroSongSearchDelegate extends SearchDelegate {
  final WidgetRef ref;

  RetroSongSearchDelegate(this.ref);

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context);
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const RetroIcon('close', size: 18),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const RetroIcon('arrow_left', size: 18),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSearchResults(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildSearchResults(context);

  Widget _buildSearchResults(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final songs = libraryState.allSongs.where((s) {
      final q = query.toLowerCase();
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();

    return ListView.builder(
      itemCount: songs.length,
      itemBuilder: (context, idx) {
        final song = songs[idx];
        return ListTile(
          leading: const RetroIcon('music', size: 20),
          title: Text(song.title, style: RetroTypography.pixelBadge(color: Theme.of(context).colorScheme.onSurface, fontSize: 10)),
          subtitle: Text(song.artist, style: RetroTypography.retroMono(color: Theme.of(context).colorScheme.onSurface, fontSize: 13)),
          onTap: () {
            close(context, null);
            ref.read(playerProvider.notifier).playSong(song, queue: songs);
          },
        );
      },
    );
  }
}
