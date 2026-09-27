import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/retro_theme.dart';
import '../../../../core/theme/retro_typography.dart';
import '../../../../domain/models/artist.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../widgets/retro_album_art.dart';
import '../../../widgets/retro_badge.dart';
import '../../../widgets/retro_button.dart';
import '../../../widgets/retro_card.dart';
import '../../../widgets/retro_icon.dart';
import '../../../widgets/retro_loading_state.dart';
import '../../../widgets/retro_refresh_indicator.dart';
import '../../../widgets/retro_toast.dart';
import '../artist_detail_screen.dart';

enum ArtistSortMode { name, tracks, albums }

class ArtistsTab extends ConsumerStatefulWidget {
  final bool showToolbar;

  const ArtistsTab({
    super.key,
    this.showToolbar = true,
  });

  @override
  ConsumerState<ArtistsTab> createState() => _ArtistsTabState();
}

class _ArtistsTabState extends ConsumerState<ArtistsTab> {
  ArtistSortMode _sortMode = ArtistSortMode.name;
  bool _sortAscending = true;
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSortSelected(ArtistSortMode mode) {
    setState(() {
      if (_sortMode == mode) {
        _sortAscending = !_sortAscending;
      } else {
        _sortMode = mode;
        _sortAscending = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final playerNotifier = ref.read(playerProvider.notifier);
    final isGridView = ref.watch(artistViewModeProvider);
    final allArtists = libraryState.artists;
    final theme = Theme.of(context);
    final retro = context.retro;

    final globalSearch = ref.watch(artistSearchProvider);
    final globalSortMode = ref.watch(artistSortModeProvider);
    final globalSortAscending = ref.watch(artistSortAscendingProvider);

    // Filter artists
    final query = (!widget.showToolbar ? globalSearch : _searchController.text).trim().toLowerCase();
    var artists = allArtists.where((artist) {
      if (query.isEmpty) return true;
      return artist.name.toLowerCase().contains(query);
    }).toList();

    final sortMode = !widget.showToolbar
        ? (globalSortMode == 'tracks'
            ? ArtistSortMode.tracks
            : (globalSortMode == 'albums' ? ArtistSortMode.albums : ArtistSortMode.name))
        : _sortMode;
    final sortAscending = !widget.showToolbar ? globalSortAscending : _sortAscending;

    // Sort artists
    artists.sort((a, b) {
      int cmp = 0;
      switch (sortMode) {
        case ArtistSortMode.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case ArtistSortMode.tracks:
          cmp = a.trackCount.compareTo(b.trackCount);
          break;
        case ArtistSortMode.albums:
          cmp = a.albumCount.compareTo(b.albumCount);
          break;
      }
      return sortAscending ? cmp : -cmp;
    });

    final isFiltering = query.isNotEmpty;
    final totalCount = allArtists.length;
    final filteredCount = artists.length;

    final artistContent = RetroRefreshIndicator(
      onRefresh: () async {
        final result = await ref.read(libraryProvider.notifier).rescanLibrary();
        if (context.mounted) {
          if (result.newCount > 0) {
            RetroToast.show(
              context,
              'FOUND ${result.newCount} NEW TRACK${result.newCount == 1 ? '' : 'S'} \u2022 ${result.totalCount} TOTAL',
              icon: 'user',
              iconColor: theme.colorScheme.primary,
            );
          } else {
            RetroToast.show(
              context,
              'ARTISTS UP TO DATE \u2022 ${ref.read(libraryProvider).artists.length} ARTISTS',
              icon: 'check',
              iconColor: context.retro.accentGreen,
            );
          }
        }
      },
      child: libraryState.isLoading && artists.isEmpty
          ? const RetroLoadingState(
              title: 'FETCHING ARTISTS...',
              subtitle: 'ORGANIZING ARTISTS & DISCOGRAPHIES',
              badgeText: 'LOADING ARTISTS',
            )
          : artists.isEmpty
              ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RetroIcon(isFiltering ? 'search' : 'user',
                            size: 36, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          isFiltering ? 'NO MATCHING ARTISTS' : 'NO ARTISTS FOUND',
                          style: RetroTypography.pixelHeader(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (isFiltering) ...[
                          Text(
                            'TRY A DIFFERENT SEARCH TERM',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          RetroButton(
                            isCompact: true,
                            label: 'CLEAR SEARCH',
                            icon: const RetroIcon('close', size: 12, color: Colors.white),
                            backgroundColor: theme.colorScheme.primary,
                            onPressed: () {
                              if (!widget.showToolbar) {
                                ref.read(artistSearchProvider.notifier).state = '';
                              } else {
                                _searchController.clear();
                                setState(() {});
                              }
                            },
                          ),
                        ] else
                          Text(
                            'DRAG DOWN TO RESCAN',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : isGridView
              ? _buildGridView(context, theme, retro, artists, playerNotifier)
              : _buildListView(context, theme, retro, artists, playerNotifier),
    );

    if (!widget.showToolbar) {
      return artistContent;
    }

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              ? _buildSearchBar(context, theme, retro, filteredCount, totalCount, isGridView)
              : _buildNormalBar(context, theme, retro, filteredCount, totalCount, isFiltering, isGridView),
        ),

        // ── Artist Content ──────────────────────────────────────────────────
        Expanded(
          child: artistContent,
        ),
      ],
    );
  }

  Widget _buildSearchBar(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    int filteredCount,
    int totalCount,
    bool isGridView,
  ) {
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
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _searchController.clear();
                      setState(() {});
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
        _buildSortMenu(theme, retro),
        const SizedBox(width: 6),
        _buildViewToggle(theme, retro, isGridView),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () {
            setState(() {
              _isSearchOpen = false;
              _searchController.clear();
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

  Widget _buildNormalBar(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    int filteredCount,
    int totalCount,
    bool isFiltering,
    bool isGridView,
  ) {
    return Row(
      children: [
        RetroBadge(
          text: isFiltering ? '$filteredCount/$totalCount ARTISTS' : '$totalCount ARTISTS',
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
                        _isSearchOpen = true;
                      });
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _searchFocusNode.requestFocus();
                      });
                    },
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
                  _buildSortMenu(theme, retro),
                  const SizedBox(width: 6),
                  _buildViewToggle(theme, retro, isGridView),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSortMenu(ThemeData theme, RetroThemeTokens retro) {
    String label;
    switch (_sortMode) {
      case ArtistSortMode.name:
        label = 'NAME';
        break;
      case ArtistSortMode.tracks:
        label = 'TRACKS';
        break;
      case ArtistSortMode.albums:
        label = 'ALBUMS';
        break;
    }

    return PopupMenuButton<ArtistSortMode>(
      tooltip: "Sort artists",
      color: retro.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: retro.borderColor, width: 2.0),
        borderRadius: BorderRadius.zero,
      ),
      onSelected: _onSortSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ArtistSortMode.name,
          child: Text('SORT BY NAME',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: ArtistSortMode.tracks,
          child: Text('SORT BY TRACKS',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: ArtistSortMode.albums,
          child: Text('SORT BY ALBUMS',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
      ],
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
    );
  }

  Widget _buildViewToggle(ThemeData theme, RetroThemeTokens retro, bool isGridView) {
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
          onPressed: () {
            ref.read(artistViewModeProvider.notifier).setGridView(false);
          },
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
          onPressed: () {
            ref.read(artistViewModeProvider.notifier).setGridView(true);
          },
        ),
      ],
    );
  }

  Widget _buildListView(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    List<Artist> artists,
    PlayerNotifier playerNotifier,
  ) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RetroCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ArtistDetailScreen(artist: artist),
                ),
              );
            },
            child: Row(
              children: [
                RetroAlbumArt(
                  artPath: artist.artPath,
                  title: artist.name,
                  width: 42,
                  height: 42,
                  borderWidth: 2.0,
                  borderColor: retro.borderColor,
                  backgroundColor: retro.accentPurple,
                  placeholderIconSize: 20,
                  placeholderColor: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        style: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          RetroBadge(
                            text: '${artist.trackCount} TRACKS',
                            backgroundColor: retro.cardColor,
                            textColor: theme.colorScheme.onSurface,
                            fontSize: 7.5,
                          ),
                          const SizedBox(width: 6),
                          RetroBadge(
                            text: '${artist.albumCount} ALBUMS',
                            backgroundColor: retro.cardColor,
                            textColor: theme.colorScheme.onSurface,
                            fontSize: 7.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                RetroButton(
                  isCompact: true,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  icon: RetroIcon('play', size: 14, color: theme.colorScheme.onPrimary),
                  label: 'PLAY',
                  backgroundColor: theme.colorScheme.primary,
                  onPressed: () {
                    if (artist.songs.isNotEmpty) {
                      playerNotifier.playSong(artist.songs.first, queue: artist.songs);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridView(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    List<Artist> artists,
    PlayerNotifier playerNotifier,
  ) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];

        return RetroCard(
          padding: const EdgeInsets.all(8),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ArtistDetailScreen(artist: artist),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RetroAlbumArt(
                  artPath: artist.artPath,
                  title: artist.name,
                  width: double.infinity,
                  height: double.infinity,
                  borderWidth: 2.0,
                  borderColor: retro.borderColor,
                  backgroundColor: retro.accentPurple,
                  placeholderIconSize: 32,
                  placeholderColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                artist.name,
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface,
                  fontSize: 10.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RetroBadge(
                    text: '${artist.trackCount} TRACKS',
                    backgroundColor: retro.cardColor,
                    textColor: theme.colorScheme.onSurface,
                    fontSize: 7.5,
                  ),
                  RetroButton(
                    isCompact: true,
                    padding: const EdgeInsets.all(4),
                    icon: RetroIcon('play', size: 12, color: theme.colorScheme.onPrimary),
                    backgroundColor: theme.colorScheme.primary,
                    onPressed: () {
                      if (artist.songs.isNotEmpty) {
                        playerNotifier.playSong(artist.songs.first, queue: artist.songs);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
