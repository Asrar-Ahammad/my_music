import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_colors.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../domain/models/playlist.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/playlist_provider.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_song_tile.dart';
import '../../widgets/retro_toast.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_scroll_thumb.dart';
import 'retro_image_editor_screen.dart';

enum PlaylistSortMode {
  defaultOrder('DEFAULT'),
  title('TITLE'),
  artist('ARTIST'),
  duration('DURATION'),
  date('DATE');

  final String label;
  const PlaylistSortMode(this.label);
}

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  final bool isFavorites;
  final VoidCallback? onBack;

  const PlaylistDetailScreen({
    super.key,
    required this.playlist,
    this.isFavorites = false,
    this.onBack,
  });

  @override
  ConsumerState<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSearchOpen = false;
  PlaylistSortMode _sortMode = PlaylistSortMode.defaultOrder;
  bool _sortAscending = true;
  bool _isDetailsVisible = true;
  bool _showScrollToTop = false;
  final GlobalKey _bannerKey = GlobalKey();
  double _bannerHeight = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scrollController.hasClients && _scrollController.offset > 200;
    if (show != _showScrollToTop) {
      setState(() {
        _showScrollToTop = show;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double _lastBottomInset = 0.0;

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final currentBottomInset = views.first.viewInsets.bottom;
    if (_lastBottomInset > 0 && currentBottomInset == 0) {
      if (_searchFocusNode.hasFocus) {
        _searchFocusNode.unfocus();
      }
    }
    _lastBottomInset = currentBottomInset;
  }

  Widget _buildSortMenu(ThemeData theme, RetroThemeTokens retro) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: retro.borderColor, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sort mode dropdown selector
          PopupMenuButton<String>(
            tooltip: 'Sort playlist tracks',
            color: retro.cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: retro.borderColor, width: 2.0),
              borderRadius: BorderRadius.zero,
            ),
            onSelected: (value) {
              setState(() {
                switch (value) {
                  case 'default':
                    if (_sortMode == PlaylistSortMode.defaultOrder) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = PlaylistSortMode.defaultOrder;
                      _sortAscending = true;
                    }
                    break;
                  case 'title':
                    if (_sortMode == PlaylistSortMode.title) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = PlaylistSortMode.title;
                      _sortAscending = true;
                    }
                    break;
                  case 'artist':
                    if (_sortMode == PlaylistSortMode.artist) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = PlaylistSortMode.artist;
                      _sortAscending = true;
                    }
                    break;
                  case 'duration':
                    if (_sortMode == PlaylistSortMode.duration) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = PlaylistSortMode.duration;
                      _sortAscending = true;
                    }
                    break;
                  case 'date':
                    if (_sortMode == PlaylistSortMode.date) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = PlaylistSortMode.date;
                      _sortAscending = false;
                    }
                    break;
                  case 'asc':
                    _sortAscending = true;
                    break;
                  case 'desc':
                    _sortAscending = false;
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'default',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'DEFAULT ORDER',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == PlaylistSortMode.defaultOrder
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == PlaylistSortMode.defaultOrder)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'title',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY TITLE',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == PlaylistSortMode.title
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == PlaylistSortMode.title)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'artist',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY ARTIST',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == PlaylistSortMode.artist
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == PlaylistSortMode.artist)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'duration',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY DURATION',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == PlaylistSortMode.duration
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == PlaylistSortMode.duration)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'date',
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY DATE',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == PlaylistSortMode.date
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == PlaylistSortMode.date)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'asc',
                child: Row(
                  children: [
                    Text(
                      '▲ ASCENDING',
                      style: RetroTypography.pixelBadge(
                        color: _sortAscending
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontSize: 9,
                      ),
                    ),
                    const Spacer(),
                    if (_sortAscending)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'desc',
                child: Row(
                  children: [
                    Text(
                      '▼ DESCENDING',
                      style: RetroTypography.pixelBadge(
                        color: !_sortAscending
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontSize: 9,
                      ),
                    ),
                    const Spacer(),
                    if (!_sortAscending)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RetroIcon('sort', size: 13, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Text(
                    _sortMode.label,
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Divider between sort mode and arrows
          Container(
            width: 1.5,
            height: 20,
            color: retro.borderColor,
          ),
          // Up Arrow (Ascending)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_sortAscending) {
                setState(() => _sortAscending = true);
              }
            },
            child: Tooltip(
              message: 'Sort ascending',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                color: _sortAscending
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                child: Text(
                  '▲',
                  style: TextStyle(
                    color: _sortAscending
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Divider between up and down arrow
          Container(
            width: 1.0,
            height: 14,
            color: retro.borderColor.withValues(alpha: 0.5),
          ),
          // Down Arrow (Descending)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_sortAscending) {
                setState(() => _sortAscending = false);
              }
            },
            child: Tooltip(
              message: 'Sort descending',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                color: !_sortAscending
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                child: Text(
                  '▼',
                  style: TextStyle(
                    color: !_sortAscending
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityBar(
    ThemeData theme,
    RetroThemeTokens retro,
    int totalCount,
    int filteredCount,
    bool isFiltering,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border(
          bottom: BorderSide(
            color: retro.borderColor,
            width: retro.borderWidth,
          ),
        ),
      ),
      child: _isSearchOpen
          ? Row(
              children: [
                RetroBadge(
                  text: isFiltering
                      ? '$filteredCount/$totalCount TRACKS'
                      : '$totalCount TRACKS',
                  backgroundColor: theme.colorScheme.primary,
                  textColor: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 34,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: retro.borderColor, width: 1.5),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8, right: 6),
                          child: RetroIcon('search', size: 14),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            textAlignVertical: TextAlignVertical.center,
                            textInputAction: TextInputAction.search,
                            onTapOutside: (_) => _searchFocusNode.unfocus(),
                            onSubmitted: (_) => _searchFocusNode.unfocus(),
                            onChanged: (_) => setState(() {}),
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 9.5,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              isCollapsed: true,
                              hintText: 'SEARCH IN PLAYLIST...',
                              hintStyle: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 8.5,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_searchController.text.isNotEmpty)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              child: RetroIcon('close', size: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildSortMenu(theme, retro),
              ],
            )
          : Row(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_scrollController.hasClients && _scrollController.offset > 60) {
                      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                    } else {
                      setState(() => _isDetailsVisible = !_isDetailsVisible);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RetroBadge(
                        text: isFiltering
                            ? '$filteredCount/$totalCount TRACKS'
                            : '$totalCount TRACKS',
                        backgroundColor: theme.colorScheme.primary,
                        textColor: theme.colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isDetailsVisible ? '▲' : '▼',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isSearchOpen = true;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _searchFocusNode.requestFocus();
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: retro.borderColor, width: 1.5),
                      borderRadius: BorderRadius.zero,
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
                const SizedBox(width: 8),
                _buildSortMenu(theme, retro),
              ],
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playlistRepo = ref.watch(playlistRepositoryProvider);
    final playlistNotifier = ref.read(playlistProvider.notifier);
    final playerNotifier = ref.read(playerProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;
    final isNothing = context.isNothingTheme;

    final isFavorites = widget.isFavorites;
    final onBack = widget.onBack;
    final playlist = widget.playlist;

    final playlistState = ref.watch(playlistProvider);
    final currentPlaylist = isFavorites
        ? playlist
        : playlistState.playlists.firstWhere(
            (p) => p.id == playlist.id,
            orElse: () => playlist,
          );

    final currentPlaylistId = isFavorites ? 'favorites_system' : currentPlaylist.id;

    final List<Song> baseSongs = isFavorites
        ? libraryState.favoriteSongs
        : playlistRepo.getSongsForPlaylist(currentPlaylist, libraryState.allSongs);

    // Sort order: playlist songs sorted according to active sort mode and direction
    final List<Song> playlistSongs = List<Song>.from(baseSongs);
    if (_sortMode != PlaylistSortMode.defaultOrder || !_sortAscending) {
      playlistSongs.sort((a, b) {
        int cmp;
        switch (_sortMode) {
          case PlaylistSortMode.title:
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
            break;
          case PlaylistSortMode.artist:
            cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
            break;
          case PlaylistSortMode.duration:
            cmp = a.duration.compareTo(b.duration);
            break;
          case PlaylistSortMode.date:
            final aDate = a.dateAdded?.millisecondsSinceEpoch ?? 0;
            final bDate = b.dateAdded?.millisecondsSinceEpoch ?? 0;
            cmp = aDate.compareTo(bDate);
            if (cmp == 0) {
              cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
            }
            break;
          case PlaylistSortMode.defaultOrder:
            final aIndex = baseSongs.indexOf(a);
            final bIndex = baseSongs.indexOf(b);
            cmp = aIndex.compareTo(bIndex);
            break;
        }
        return _sortAscending ? cmp : -cmp;
      });
    }

    // Search query filtering applied to sorted playlist
    final query = _searchController.text.trim().toLowerCase();
    final List<Song> displaySongs = query.isEmpty
        ? playlistSongs
        : playlistSongs.where((s) {
            return s.title.toLowerCase().contains(query) ||
                s.artist.toLowerCase().contains(query) ||
                s.album.toLowerCase().contains(query);
          }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _bannerKey.currentContext;
      if (ctx != null && ctx.size != null) {
        final h = ctx.size!.height;
        if ((h - _bannerHeight).abs() > 1.0) {
          setState(() {
            _bannerHeight = h;
          });
        }
      }
    });

    final resolvedCover = isFavorites
        ? (libraryState.favoriteSongs.isNotEmpty ? libraryState.favoriteSongs.first.artPath : null)
        : currentPlaylist.resolveArtPath(libraryState.allSongs);
    final double coverSize = 200.0;
    final double coverIconSize = 80.0;
    final double defaultBannerHeight = isFavorites ? 396.0 : 430.0;
    final double firstSongTop = _isDetailsVisible
        ? ((_bannerHeight > 0 ? _bannerHeight : defaultBannerHeight) + 50.0)
        : 50.0;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: const RetroIcon('arrow_left', size: 20),
          onPressed: () {
            if (onBack != null) {
              onBack();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (_scrollController.hasClients && _scrollController.offset > 60) {
              _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
            } else {
              setState(() => _isDetailsVisible = !_isDetailsVisible);
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                currentPlaylist.name.toUpperCase(),
                style: RetroTypography.pixelHeader(
                  color: theme.colorScheme.onSurface,
                  fontSize: 12.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (!_isDetailsVisible) ...[
                const SizedBox(height: 2),
                Text(
                  '${baseSongs.length} TRACKS • TAP FOR DETAILS',
                  style: RetroTypography.retroMono(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (baseSongs.isNotEmpty)
            IconButton(
              tooltip: _isSearchOpen ? 'Close Search' : 'Search in playlist',
              icon: RetroIcon(_isSearchOpen ? 'close' : 'search', size: 18),
              onPressed: () {
                setState(() {
                  _isSearchOpen = !_isSearchOpen;
                  if (!_isSearchOpen) {
                    _searchController.clear();
                  } else {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _searchFocusNode.requestFocus();
                    });
                  }
                });
              },
            ),
          if (!isFavorites)
            PopupMenuButton<String>(
              icon: const RetroIcon('more_vertical', size: 20),
              tooltip: 'Playlist Options',
              color: retro.cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: BorderSide(color: retro.borderColor, width: 2.0),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditPlaylistDialog(context, playlistNotifier, currentPlaylist);
                } else if (value == 'change_cover') {
                  _pickAndSetCoverImage(context, playlistNotifier, currentPlaylist);
                } else if (value == 'remove_cover') {
                  _removeCustomCoverImage(context, playlistNotifier, currentPlaylist);
                } else if (value == 'delete') {
                  _showDeletePlaylistDialog(context, playlistNotifier, currentPlaylist, onBack);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<String>(
                  value: 'edit',
                  height: 40,
                  child: Row(
                    children: [
                      const RetroIcon('edit', size: 16),
                      const SizedBox(width: 10),
                      Text(
                        'EDIT PLAYLIST',
                        style: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'change_cover',
                  height: 40,
                  child: Row(
                    children: [
                      const RetroIcon('disc', size: 16),
                      const SizedBox(width: 10),
                      Text(
                        'CHANGE COVER IMAGE',
                        style: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (currentPlaylist.customArtPath != null) ...[
                  PopupMenuItem<String>(
                    value: 'remove_cover',
                    height: 40,
                    child: Row(
                      children: [
                        const RetroIcon('refresh', size: 16),
                        const SizedBox(width: 10),
                        Text(
                          'RESET TO DEFAULT COVER',
                          style: RetroTypography.pixelBadge(
                            color: theme.colorScheme.onSurface,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const PopupMenuDivider(height: 2),
                PopupMenuItem<String>(
                  value: 'delete',
                  height: 40,
                  child: Row(
                    children: [
                      RetroIcon('trash', size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 10),
                      Text(
                        'DELETE PLAYLIST',
                        style: RetroTypography.pixelBadge(
                          color: theme.colorScheme.primary,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
            slivers: [
            // 1. Collapsible Playlist Banner
            if (_isDetailsVisible)
              SliverToBoxAdapter(
                child: Container(
                  key: _bannerKey,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                  decoration: BoxDecoration(
                    color: retro.cardColor,
                    border: Border(bottom: BorderSide(color: retro.borderColor, width: retro.borderWidth)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 1. Centered Large Playlist Cover Art
                      Center(
                        child: GestureDetector(
                          onTap: isFavorites
                              ? null
                              : () => _pickAndSetCoverImage(context, playlistNotifier, currentPlaylist),
                          child: Stack(
                            children: [
                              Builder(
                                builder: (context) {
                                  return Container(
                                    width: coverSize,
                                    height: coverSize,
                                    decoration: BoxDecoration(
                                      color: isFavorites
                                          ? theme.colorScheme.primary
                                          : (isNothing ? context.nothing.surfaceContainer : retro.cardColor),
                                      border: isNothing ? null : Border.all(color: retro.borderColor, width: 2.5),
                                      borderRadius: isNothing
                                          ? BorderRadius.circular(context.nothing.borderRadiusLarge)
                                          : BorderRadius.zero,
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: isFavorites
                                        ? (resolvedCover != null && resolvedCover.trim().isNotEmpty
                                            ? Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  RetroAlbumArt(
                                                    artPath: resolvedCover,
                                                    title: 'Favorites',
                                                    width: coverSize,
                                                    height: coverSize,
                                                    borderWidth: 0,
                                                  ),
                                                  Container(
                                                    color: Colors.black.withValues(alpha: 0.35),
                                                  ),
                                                  Center(
                                                    child: RetroIcon('heart_filled', size: coverIconSize * 0.7, color: Colors.white),
                                                  ),
                                                ],
                                              )
                                            : Center(
                                                child: RetroIcon('heart_filled', size: coverIconSize, color: Colors.white),
                                              ))
                                        : (resolvedCover != null && resolvedCover.trim().isNotEmpty
                                            ? RetroAlbumArt(
                                                artPath: resolvedCover,
                                                title: currentPlaylist.name,
                                                width: coverSize,
                                                height: coverSize,
                                                borderWidth: 0,
                                              )
                                            : Center(
                                                child: RetroIcon(
                                                  'playlist',
                                                  size: coverIconSize,
                                                  color: isNothing ? theme.colorScheme.onSurface : null,
                                                ),
                                              )),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 2. Playlist Name
                      Text(
                        currentPlaylist.name,
                        style: RetroTypography.pixelHeader(
                          color: theme.colorScheme.onSurface,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 4),

                      // 3. Track Count & Creation Date
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${baseSongs.length} Tracks',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              fontSize: 17,
                            ),
                          ),
                          if (!isFavorites) ...[
                            Text(
                              ' • ',
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 17,
                              ),
                            ),
                            Text(
                              'Created ${currentPlaylist.createdAt.month}/${currentPlaylist.createdAt.day}/${currentPlaylist.createdAt.year}',
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // 4. Play All & Shuffle Play Buttons
                      if (displaySongs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RetroButton(
                                label: 'PLAY ALL',
                                icon: const RetroIcon('play', size: 14),
                                backgroundColor: theme.colorScheme.primary,
                                textColor: theme.colorScheme.onPrimary,
                                onPressed: () {
                                  playerNotifier.playPlaylist(
                                    playlistId: currentPlaylistId,
                                    songs: (query.isNotEmpty && displaySongs.length == 1)
                                        ? playlistSongs
                                        : displaySongs,
                                    initialSong: (query.isNotEmpty && displaySongs.length == 1)
                                        ? displaySongs.first
                                        : null,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RetroButton(
                                label: 'SHUFFLE PLAY',
                                icon: const RetroIcon('shuffle', size: 14),
                                backgroundColor: retro.accentYellow,
                                textColor: Colors.black,
                                onPressed: () {
                                  playerNotifier.playPlaylist(
                                    playlistId: currentPlaylistId,
                                    songs: (query.isNotEmpty && displaySongs.length == 1)
                                        ? playlistSongs
                                        : displaySongs,
                                    initialSong: (query.isNotEmpty && displaySongs.length == 1)
                                        ? displaySongs.first
                                        : null,
                                    forceShuffle: true,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else if (baseSongs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RetroButton(
                                label: 'PLAY ALL',
                                icon: const RetroIcon('play', size: 14),
                                backgroundColor: theme.colorScheme.primary,
                                textColor: theme.colorScheme.onPrimary,
                                onPressed: () {
                                  playerNotifier.playPlaylist(
                                    playlistId: currentPlaylistId,
                                    songs: playlistSongs,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RetroButton(
                                label: 'SHUFFLE PLAY',
                                icon: const RetroIcon('shuffle', size: 14),
                                backgroundColor: retro.accentYellow,
                                textColor: Colors.black,
                                onPressed: () {
                                  playerNotifier.playPlaylist(
                                    playlistId: currentPlaylistId,
                                    songs: playlistSongs,
                                    forceShuffle: true,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else if (!isFavorites) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: RetroButton(
                          label: 'ADD SONGS',
                          icon: RetroIcon('plus', size: 14, color: theme.colorScheme.onPrimary),
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          onPressed: () {
                            _showAddSongsDrawer(
                              context,
                              playlistNotifier,
                              currentPlaylist,
                              currentPlaylist.songIds.toSet(),
                              libraryState.allSongs,
                            );
                          },
                        ),
                      ),
                    ],

                    // 5. Add More Songs Button (Secondary)
                    if (displaySongs.isNotEmpty && !isFavorites) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: RetroButton(
                          isCompact: true,
                          label: 'ADD MORE SONGS',
                          icon: const RetroIcon('plus', size: 13, color: Colors.black),
                          backgroundColor: retro.accentGreen.withValues(alpha: 0.9),
                          textColor: Colors.black,
                          onPressed: () => _showAddSongsDrawer(
                            context,
                            playlistNotifier,
                            currentPlaylist,
                            currentPlaylist.songIds.toSet(),
                            libraryState.allSongs,
                          ),
                        ),
                      ),
                    ],

                  ],
                ),
              ),
            ),

          // 2. Pinned Utility bar (Search & Sort)
          if (baseSongs.isNotEmpty)
            SliverPersistentHeader(
              pinned: true,
              delegate: _RetroUtilityBarDelegate(
                child: _buildUtilityBar(
                  theme,
                  retro,
                  baseSongs.length,
                  displaySongs.length,
                  query.isNotEmpty,
                ),
                height: 50.0,
              ),
            ),

          // 3. Songs List or Empty State
          if (baseSongs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'NO TRACKS IN THIS PLAYLIST',
                  style: RetroTypography.pixelHeader(color: theme.colorScheme.onSurface, fontSize: 11),
                ),
              ),
            )
          else if (displaySongs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RetroIcon('search', size: 32, color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                    const SizedBox(height: 8),
                    Text(
                      'NO TRACKS MATCHING "${_searchController.text.toUpperCase()}"',
                      style: RetroTypography.pixelHeader(color: theme.colorScheme.onSurface, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    RetroButton(
                      isCompact: true,
                      label: 'CLEAR SEARCH',
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 72),
              sliver: SliverList.separated(
                itemCount: displaySongs.length,
                separatorBuilder: (context, idx) => Container(
                  height: 1,
                  color: retro.borderColor.withValues(alpha: 0.3),
                ),
                itemBuilder: (context, index) {
                  final song = displaySongs[index];
                  final songPlaylistIndex = playlistSongs.indexOf(song);
                  return RetroSongTile(
                    song: song,
                    index: songPlaylistIndex != -1 ? songPlaylistIndex : index,
                    queue: playlistSongs,
                    onRemoveFromPlaylist: () {
                      if (isFavorites) {
                        ref.read(libraryProvider.notifier).toggleFavorite(song.id);
                        RetroToast.show(
                          context,
                          'REMOVED FROM FAVORITES: ${song.title.toUpperCase()}',
                          icon: 'heart',
                        );
                      } else {
                        ref
                            .read(playlistProvider.notifier)
                            .removeSongFromPlaylist(currentPlaylist.id, song.id);
                        RetroToast.show(
                          context,
                          'REMOVED FROM PLAYLIST: ${song.title.toUpperCase()}',
                          icon: 'trash',
                        );
                      }
                    },
                    onTap: () {
                      playerNotifier.playPlaylist(
                        playlistId: currentPlaylistId,
                        songs: playlistSongs,
                        initialSong: song,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
      RetroScrollThumb(
        controller: _scrollController,
        thickness: 4.0,
        thumbHeight: 44.0,
        thumbColor: theme.colorScheme.primary,
        initialTop: firstSongTop,
      ),
    ],
  ),
    floatingActionButtonAnimator: const _NoAnimationFabAnimator(),
    floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    floatingActionButton: _showScrollToTop
        ? Padding(
            padding: const EdgeInsets.only(
              right: 12.0,
              bottom: 8.0,
            ),
            child: RetroButton(
              isCompact: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              onPressed: () {
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          )
        : null,
  );
  }

  void _showAddSongsDrawer(
    BuildContext context,
    PlaylistNotifier notifier,
    Playlist playlist,
    Set<String> existingIds,
    List<Song> allSongs,
  ) {
    final theme = Theme.of(context);
    final retro = context.retro;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _AddSongsSheet(
          theme: theme,
          retro: retro,
          playlist: playlist,
          existingIds: existingIds,
          allSongs: allSongs,
          onConfirm: (List<String> newIds) async {
            if (newIds.isEmpty) return;
            await notifier.addSongsToPlaylist(playlist.id, newIds);
            if (context.mounted) {
              RetroToast.show(
                context,
                '${newIds.length} TRACK${newIds.length == 1 ? '' : 'S'} ADDED TO ${playlist.name.toUpperCase()}',
                icon: 'playlist',
                iconColor: theme.colorScheme.primary,
              );
            }
          },
        );
      },
    );
  }

  Future<void> _pickAndSetCoverImage(

    BuildContext context,
    PlaylistNotifier notifier,
    Playlist playlist,
  ) async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.image,
      );
      if (result.isNotEmpty) {
        final path = result.first.path;
        if (path != null && path.isNotEmpty) {
          if (!context.mounted) return;
          final editedPath = await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => RetroImageEditorScreen(imagePath: path),
            ),
          );
          if (editedPath != null && editedPath.isNotEmpty) {
            await notifier.updatePlaylistCover(playlist.id, editedPath);
            if (context.mounted) {
              RetroToast.show(
                context,
                'PLAYLIST COVER UPDATED!',
                icon: 'disc',
              );
            }
          }
        }
      }
    } catch (_) {
      if (context.mounted) {
        RetroToast.show(context, 'COULD NOT SELECT IMAGE', icon: 'close');
      }
    }
  }

  Future<void> _removeCustomCoverImage(
    BuildContext context,
    PlaylistNotifier notifier,
    Playlist playlist,
  ) async {
    await notifier.updatePlaylistCover(playlist.id, null);
    if (context.mounted) {
      RetroToast.show(
        context,
        'RESET TO DEFAULT COVER',
        icon: 'refresh',
      );
    }
  }

  void _showEditPlaylistDialog(
    BuildContext context,
    PlaylistNotifier notifier,
    Playlist playlist,
  ) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final controller = TextEditingController(text: playlist.name);
    String? currentCover = playlist.customArtPath;
    bool coverChanged = false;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            final trimmed = controller.text.trim();
            final canSave = trimmed.isNotEmpty && (trimmed != playlist.name || coverChanged);

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              contentPadding: const EdgeInsets.all(16),
              titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      border: Border.all(color: retro.borderColor, width: 2.0),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: const Center(
                      child: RetroIcon('edit', size: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'EDIT PLAYLIST',
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLAYLIST NAME',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 11,
                      ),
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Enter playlist name',
                        hintStyle: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 10,
                        ),
                        filled: true,
                        fillColor: retro.cardColor,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: retro.borderColor, width: 2.0),
                          borderRadius: BorderRadius.zero,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: retro.borderColor, width: 2.0),
                          borderRadius: BorderRadius.zero,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
                          borderRadius: BorderRadius.zero,
                        ),
                        suffixIcon: controller.text.isNotEmpty
                            ? IconButton(
                                icon: const RetroIcon('close', size: 14),
                                onPressed: () {
                                  controller.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'COVER IMAGE',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: retro.cardColor,
                        border: Border.all(color: retro.borderColor, width: 1.5),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              border: Border.all(color: retro.borderColor, width: 1.5),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: currentCover != null
                                ? RetroAlbumArt(
                                    artPath: currentCover,
                                    width: 36,
                                    height: 36,
                                    borderWidth: 0,
                                  )
                                : const Center(child: RetroIcon('disc', size: 18)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              currentCover != null ? 'CUSTOM COVER' : 'DEFAULT COVER',
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface,
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                          if (currentCover != null) ...[
                            IconButton(
                              iconSize: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              icon: const RetroIcon('close', size: 14),
                              onPressed: () {
                                setState(() {
                                  currentCover = null;
                                  coverChanged = true;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                          ],
                          RetroButton(
                            isCompact: true,
                            label: 'CHOOSE',
                            backgroundColor: theme.colorScheme.primary,
                            textColor: theme.colorScheme.onPrimary,
                            onPressed: () async {
                              try {
                                final result = await FilePickerPlatform.instance.pickFiles(
                                  type: FileType.image,
                                );
                                if (result.isNotEmpty) {
                                  final path = result.first.path;
                                  if (path != null && path.isNotEmpty) {
                                    if (!context.mounted) return;
                                    final editedPath = await Navigator.of(context).push<String>(
                                      MaterialPageRoute(
                                        builder: (_) => RetroImageEditorScreen(imagePath: path),
                                      ),
                                    );
                                    if (editedPath != null && editedPath.isNotEmpty) {
                                      setState(() {
                                        currentCover = editedPath;
                                        coverChanged = true;
                                      });
                                    }
                                  }
                                }
                              } catch (_) {}
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                RetroButton(
                  isCompact: true,
                  label: 'CANCEL',
                  backgroundColor: retro.cardColor,
                  textColor: theme.colorScheme.onSurface,
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                RetroButton(
                  isCompact: true,
                  label: 'SAVE',
                  backgroundColor: canSave ? theme.colorScheme.primary : retro.cardColor,
                  textColor: canSave ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  onPressed: canSave
                      ? () async {
                          Navigator.of(dialogContext).pop();
                          if (trimmed != playlist.name) {
                            await notifier.renamePlaylist(playlist.id, trimmed);
                          }
                          if (coverChanged) {
                            await notifier.updatePlaylistCover(playlist.id, currentCover);
                          }
                          if (context.mounted) {
                            RetroToast.show(
                              context,
                              'PLAYLIST UPDATED!',
                              icon: 'check',
                              iconColor: theme.colorScheme.primary,
                            );
                          }
                        }
                      : null,
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeletePlaylistDialog(
    BuildContext context,
    PlaylistNotifier notifier,
    Playlist playlist,
    VoidCallback? onBack,
  ) {
    final theme = Theme.of(context);
    final retro = context.retro;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          contentPadding: const EdgeInsets.all(16),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  border: Border.all(color: retro.borderColor, width: 2.0),
                  borderRadius: BorderRadius.zero,
                ),
                child: const Center(
                  child: RetroIcon('trash', size: 16, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'DELETE PLAYLIST?',
                  style: RetroTypography.pixelHeader(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete "${playlist.name}"?',
                style: RetroTypography.retroMono(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border.all(color: retro.borderColor, width: 1.5),
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    const RetroIcon('info', size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tracks will remain in your library.',
                        style: RetroTypography.retroMono(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            RetroButton(
              isCompact: true,
              label: 'CANCEL',
              backgroundColor: retro.cardColor,
              textColor: theme.colorScheme.onSurface,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            RetroButton(
              isCompact: true,
              label: 'DELETE',
              icon: RetroIcon('trash', size: 14, color: theme.colorScheme.onPrimary),
              backgroundColor: theme.colorScheme.primary,
              textColor: theme.colorScheme.onPrimary,
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await notifier.deletePlaylist(playlist.id);
                if (onBack != null) {
                  onBack();
                } else if (context.mounted) {
                  Navigator.of(context).pop();
                }
                if (context.mounted) {
                  RetroToast.show(
                    context,
                    'DELETED PLAYLIST "${playlist.name.toUpperCase()}"',
                    icon: 'trash',
                    iconColor: RetroColors.picoRed,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Add Songs Sheet
// ═══════════════════════════════════════════════════════════════════════════

enum _AddSongsFilter {
  all('ALL'),
  unadded('UNADDED'),
  inPlaylist('IN LIST');

  final String label;
  const _AddSongsFilter(this.label);
}

enum _AddSongsSortMode {
  title('TITLE'),
  artist('ARTIST'),
  album('ALBUM'),
  duration('DURATION'),
  date('DATE');

  final String label;
  const _AddSongsSortMode(this.label);
}

enum _AddSongsSortAction {
  title,
  artist,
  album,
  duration,
  date,
  asc,
  desc,
}

class _AddSongsSheet extends StatefulWidget {
  final ThemeData theme;
  final RetroThemeTokens retro;
  final Playlist playlist;
  final Set<String> existingIds;
  final List<Song> allSongs;
  final Future<void> Function(List<String> newIds) onConfirm;

  const _AddSongsSheet({
    required this.theme,
    required this.retro,
    required this.playlist,
    required this.existingIds,
    required this.allSongs,
    required this.onConfirm,
  });

  @override
  State<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<_AddSongsSheet> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<String> _selectedIds;
  bool _isAdding = false;
  _AddSongsFilter _filter = _AddSongsFilter.all;
  _AddSongsSortMode _sortMode = _AddSongsSortMode.title;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    // Pre-select songs already in the playlist
    _selectedIds = Set<String>.from(widget.existingIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Song> get _filteredSongs {
    final q = _searchController.text.trim().toLowerCase();
    var list = widget.allSongs.where((s) {
      if (q.isEmpty) return true;
      return s.title.toLowerCase().contains(q) ||
          s.artist.toLowerCase().contains(q) ||
          s.album.toLowerCase().contains(q);
    }).toList();

    switch (_filter) {
      case _AddSongsFilter.all:
        break;
      case _AddSongsFilter.unadded:
        list = list.where((s) => !widget.existingIds.contains(s.id)).toList();
        break;
      case _AddSongsFilter.inPlaylist:
        list = list.where((s) => widget.existingIds.contains(s.id)).toList();
        break;
    }

    list.sort((a, b) {
      int cmp = 0;
      switch (_sortMode) {
        case _AddSongsSortMode.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case _AddSongsSortMode.artist:
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          break;
        case _AddSongsSortMode.album:
          cmp = a.album.toLowerCase().compareTo(b.album.toLowerCase());
          break;
        case _AddSongsSortMode.duration:
          cmp = a.duration.compareTo(b.duration);
          break;
        case _AddSongsSortMode.date:
          final aDate = a.dateAdded?.millisecondsSinceEpoch ?? 0;
          final bDate = b.dateAdded?.millisecondsSinceEpoch ?? 0;
          cmp = aDate.compareTo(bDate);
          if (cmp == 0) {
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  int get _newCount =>
      _selectedIds.where((id) => !widget.existingIds.contains(id)).length;

  Widget _buildFilterChip(
    String label,
    _AddSongsFilter filter,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final isSelected = _filter == filter;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _filter = filter),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : retro.borderColor,
            width: 1.5,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Text(
          label,
          style: RetroTypography.pixelBadge(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 8.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSortMenu(ThemeData theme, RetroThemeTokens retro) {
    final sortLabel = _sortMode.label;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: retro.borderColor, width: 1.5),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<_AddSongsSortAction>(
            tooltip: 'Sort tracks',
            color: retro.cardColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: retro.borderColor, width: 2.0),
              borderRadius: BorderRadius.zero,
            ),
            onSelected: (action) {
              setState(() {
                switch (action) {
                  case _AddSongsSortAction.title:
                    if (_sortMode == _AddSongsSortMode.title) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = _AddSongsSortMode.title;
                      _sortAscending = true;
                    }
                    break;
                  case _AddSongsSortAction.artist:
                    if (_sortMode == _AddSongsSortMode.artist) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = _AddSongsSortMode.artist;
                      _sortAscending = true;
                    }
                    break;
                  case _AddSongsSortAction.album:
                    if (_sortMode == _AddSongsSortMode.album) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = _AddSongsSortMode.album;
                      _sortAscending = true;
                    }
                    break;
                  case _AddSongsSortAction.duration:
                    if (_sortMode == _AddSongsSortMode.duration) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = _AddSongsSortMode.duration;
                      _sortAscending = true;
                    }
                    break;
                  case _AddSongsSortAction.date:
                    if (_sortMode == _AddSongsSortMode.date) {
                      _sortAscending = !_sortAscending;
                    } else {
                      _sortMode = _AddSongsSortMode.date;
                      _sortAscending = false;
                    }
                    break;
                  case _AddSongsSortAction.asc:
                    _sortAscending = true;
                    break;
                  case _AddSongsSortAction.desc:
                    _sortAscending = false;
                    break;
                }
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AddSongsSortAction.title,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY TITLE',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == _AddSongsSortMode.title
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == _AddSongsSortMode.title)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AddSongsSortAction.artist,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY ARTIST',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == _AddSongsSortMode.artist
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == _AddSongsSortMode.artist)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AddSongsSortAction.album,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY ALBUM',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == _AddSongsSortMode.album
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == _AddSongsSortMode.album)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AddSongsSortAction.duration,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY DURATION',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == _AddSongsSortMode.duration
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == _AddSongsSortMode.duration)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AddSongsSortAction.date,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SORT BY DATE',
                        style: RetroTypography.pixelBadge(
                          color: _sortMode == _AddSongsSortMode.date
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    if (_sortMode == _AddSongsSortMode.date)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _AddSongsSortAction.asc,
                child: Row(
                  children: [
                    Text(
                      '▲ ASCENDING',
                      style: RetroTypography.pixelBadge(
                        color: _sortAscending
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontSize: 9,
                      ),
                    ),
                    const Spacer(),
                    if (_sortAscending)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AddSongsSortAction.desc,
                child: Row(
                  children: [
                    Text(
                      '▼ DESCENDING',
                      style: RetroTypography.pixelBadge(
                        color: !_sortAscending
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontSize: 9,
                      ),
                    ),
                    const Spacer(),
                    if (!_sortAscending)
                      RetroIcon('check', size: 12, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RetroIcon('sort', size: 13, color: theme.colorScheme.onSurface),
                  const SizedBox(width: 4),
                  Text(
                    sortLabel,
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1.5,
            height: 20,
            color: retro.borderColor,
          ),
          // Up Arrow (Ascending)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!_sortAscending) {
                setState(() => _sortAscending = true);
              }
            },
            child: Tooltip(
              message: 'Sort ascending',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                color: _sortAscending
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                child: Text(
                  '▲',
                  style: TextStyle(
                    color: _sortAscending
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 1.0,
            height: 14,
            color: retro.borderColor.withValues(alpha: 0.5),
          ),
          // Down Arrow (Descending)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_sortAscending) {
                setState(() => _sortAscending = false);
              }
            },
            child: Tooltip(
              message: 'Sort descending',
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                color: !_sortAscending
                    ? theme.colorScheme.primary.withValues(alpha: 0.2)
                    : Colors.transparent,
                child: Text(
                  '▼',
                  style: TextStyle(
                    color: !_sortAscending
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.35),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final retro = widget.retro;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        final filtered = _filteredSongs;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: retro.borderColor, width: retro.borderWidth),
              left: BorderSide(color: retro.borderColor, width: retro.borderWidth),
              right: BorderSide(color: retro.borderColor, width: retro.borderWidth),
            ),
          ),
          child: Column(
            children: [
              // ── Retro Handle ──────────────────────────────────────────
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: retro.borderColor,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),

              // ── Header ────────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border(
                    bottom: BorderSide(
                        color: retro.borderColor, width: retro.borderWidth),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        border:
                            Border.all(color: retro.borderColor, width: 2),
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Center(
                        child: RetroIcon('plus', size: 18, color: theme.colorScheme.onPrimary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADD SONGS',
                            style: RetroTypography.pixelHeader(
                              color: theme.colorScheme.onSurface,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'TO: ${widget.playlist.name.toUpperCase()}',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(ctx).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(
                              color: retro.borderColor, width: 1.5),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: RetroIcon('close',
                            size: 16,
                            color: theme.colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Search Bar ────────────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border(
                    bottom: BorderSide(
                        color: retro.borderColor.withValues(alpha: 0.5),
                        width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    // Search input
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border:
                              Border.all(color: retro.borderColor, width: 1.5),
                          borderRadius: BorderRadius.zero,
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: RetroIcon('search', size: 14),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: RetroTypography.pixelBadge(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 9.5,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  isCollapsed: true,
                                  hintText: 'SEARCH TRACKS...',
                                  hintStyle: RetroTypography.pixelBadge(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.4),
                                    fontSize: 8.5,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                            if (_searchController.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: RetroIcon('close', size: 12),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Count badge
                    RetroBadge(
                      text: '${filtered.length} TRACKS',
                      backgroundColor: theme.colorScheme.primary,
                      textColor: theme.colorScheme.onPrimary,
                    ),
                  ],
                ),
              ),

              // ── Filter & Sort Bar ─────────────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border(
                    bottom: BorderSide(
                        color: retro.borderColor.withValues(alpha: 0.5),
                        width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('ALL', _AddSongsFilter.all, theme, retro),
                            const SizedBox(width: 4),
                            _buildFilterChip('UNADDED', _AddSongsFilter.unadded, theme, retro),
                            const SizedBox(width: 4),
                            _buildFilterChip('IN LIST', _AddSongsFilter.inPlaylist, theme, retro),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSortMenu(theme, retro),
                  ],
                ),
              ),

              // ── Song List ─────────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RetroIcon('search',
                                  size: 28,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 8),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'NO TRACKS MATCHING "${_searchController.text.toUpperCase()}"'
                                    : _filter == _AddSongsFilter.unadded
                                        ? 'ALL TRACKS ARE ALREADY IN THIS PLAYLIST'
                                        : _filter == _AddSongsFilter.inPlaylist
                                            ? 'NO TRACKS IN THIS PLAYLIST YET'
                                            : 'NO TRACKS FOUND',
                                style: RetroTypography.pixelBadge(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 9.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (_searchController.text.isNotEmpty ||
                                  _filter != _AddSongsFilter.all) ...[
                                const SizedBox(height: 10),
                                RetroButton(
                                  isCompact: true,
                                  label: 'RESET FILTERS',
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _filter = _AddSongsFilter.all;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          ListView.separated(
                            controller: scrollController,
                            itemCount: filtered.length,
                            separatorBuilder: (_, idx) => Container(
                              height: 1,
                              color: retro.borderColor.withValues(alpha: 0.25),
                            ),
                            itemBuilder: (context, i) {
                              final song = filtered[i];
                              final alreadyIn =
                                  widget.existingIds.contains(song.id);
                              final isChecked = _selectedIds.contains(song.id);

                              return InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isChecked) {
                                      // Don't uncheck pre-existing songs
                                      if (!alreadyIn) {
                                        _selectedIds.remove(song.id);
                                      }
                                    } else {
                                      _selectedIds.add(song.id);
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  color: isChecked && !alreadyIn
                                      ? theme.colorScheme.primary
                                          .withValues(alpha: 0.12)
                                      : alreadyIn
                                          ? theme.colorScheme.primary
                                              .withValues(alpha: 0.06)
                                          : Colors.transparent,
                                  child: Row(
                                    children: [
                                      // Checkbox
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 150),
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: isChecked
                                              ? (alreadyIn
                                                  ? theme.colorScheme.primary.withValues(alpha: 0.35)
                                                  : theme.colorScheme.primary)
                                              : retro.cardColor,
                                          border: Border.all(
                                            color: isChecked
                                                ? (alreadyIn
                                                    ? theme.colorScheme.primary.withValues(alpha: 0.35)
                                                    : theme.colorScheme.primary)
                                                : retro.borderColor,
                                            width: 2.0,
                                          ),
                                          borderRadius: BorderRadius.zero,
                                        ),
                                        child: isChecked
                                            ? Icon(Icons.check,
                                                size: 14, color: theme.colorScheme.onPrimary)
                                            : null,
                                      ),
                                      const SizedBox(width: 12),

                                      // Album art
                                      RetroAlbumArt(
                                        artPath: song.artPath,
                                        title: song.title,
                                        artist: song.artist,
                                        width: 38,
                                        height: 38,
                                        borderWidth: 1.5,
                                        borderColor: isChecked
                                            ? theme.colorScheme.primary
                                            : retro.borderColor,
                                        backgroundColor: retro.cardColor,
                                        placeholderIconSize: 16,
                                      ),
                                      const SizedBox(width: 10),

                                      // Title & subtitle
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style:
                                                  RetroTypography.pixelHeader(
                                                color: isChecked
                                                    ? theme.colorScheme.primary
                                                    : theme
                                                        .colorScheme.onSurface,
                                                fontSize: 10,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${song.artist} • ${song.album}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: RetroTypography.retroMono(
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // "IN PLAYLIST" badge for pre-existing songs
                                      if (alreadyIn)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.15),
                                            border: Border.all(
                                              color: theme.colorScheme.primary
                                                  .withValues(alpha: 0.5),
                                              width: 1,
                                            ),
                                            borderRadius: BorderRadius.zero,
                                          ),
                                          child: Text(
                                            'IN PLAYLIST',
                                            style: RetroTypography.pixelBadge(
                                              color: theme.colorScheme.primary,
                                              fontSize: 7,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          RetroScrollThumb(
                            controller: scrollController,
                            thickness: 4.0,
                            thumbHeight: 44.0,
                            thumbColor: theme.colorScheme.primary,
                          ),
                        ],
                      ),
              ),

              // ── Confirm Button ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border(
                    top: BorderSide(
                        color: retro.borderColor, width: retro.borderWidth),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: RetroButton(
                      label: _isAdding
                          ? 'ADDING...'
                          : _newCount == 0
                              ? 'NO NEW SONGS SELECTED'
                              : 'ADD $_newCount TRACK${_newCount == 1 ? '' : 'S'}',
                      icon: _isAdding
                          ? null
                          : _newCount > 0
                              ? RetroIcon('plus', size: 14,
                                  color: theme.colorScheme.onPrimary)
                              : null,
                      backgroundColor: _newCount > 0 && !_isAdding
                          ? theme.colorScheme.primary
                          : retro.disabledColor,
                      textColor: _newCount > 0 && !_isAdding
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                      onPressed: (_newCount > 0 && !_isAdding)
                          ? () async {
                              setState(() => _isAdding = true);
                              final newIds = _selectedIds
                                  .where((id) =>
                                      !widget.existingIds.contains(id))
                                  .toList();
                              final nav = Navigator.of(ctx);
                              await widget.onConfirm(newIds);
                              if (mounted) nav.pop();
                            }
                          : null,

                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RetroUtilityBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _RetroUtilityBarDelegate({required this.child, this.height = 50.0});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _RetroUtilityBarDelegate oldDelegate) {
    return true;
  }
}

class _NoAnimationFabAnimator extends FloatingActionButtonAnimator {
  const _NoAnimationFabAnimator();

  @override
  Offset getOffset({required Offset begin, required Offset end, required double progress}) => end;

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation<double>(1.0);

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation<double>(1.0);
}


