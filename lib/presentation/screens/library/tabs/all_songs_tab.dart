import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/retro_theme.dart';
import '../../../../core/theme/retro_typography.dart';
import '../../../../domain/models/song.dart';
import '../../../providers/library_provider.dart';
import '../../../providers/playlist_provider.dart';
import '../../../widgets/retro_badge.dart';
import '../../../widgets/retro_button.dart';
import '../../../widgets/retro_icon.dart';
import '../../../widgets/retro_loading_state.dart';
import '../../../widgets/retro_refresh_indicator.dart';
import '../../../widgets/retro_song_tile.dart';
import '../../../widgets/retro_toast.dart';
import '../../../widgets/scan_options_dialog.dart';

class AllSongsTab extends ConsumerStatefulWidget {
  final bool showToolbar;

  const AllSongsTab({
    super.key,
    this.showToolbar = true,
  });

  @override
  ConsumerState<AllSongsTab> createState() => _AllSongsTabState();
}

class _AllSongsTabState extends ConsumerState<AllSongsTab> {
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _enterSelectionMode(String firstId) {
    setState(() {
      _isSelecting = true;
      _selectedIds.add(firstId);
    });
    ref.read(songSelectionProvider.notifier).enterSelectionMode(firstId);
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
    ref.read(songSelectionProvider.notifier).exitSelectionMode();
  }

  void _toggleSong(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
    ref.read(songSelectionProvider.notifier).toggleSong(id);
  }

  void _selectAll(List<String> ids) {
    setState(() => _selectedIds
      ..clear()
      ..addAll(ids));
  }

  void _showAddToPlaylistSheet(BuildContext context, List<String> songIds) {
    showAddToPlaylistBottomSheet(context, ref, songIds, onDone: _exitSelectionMode);
  }

  @override
  Widget build(BuildContext context) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    final songs = libraryState.filteredSongs;

    final globalSelection = ref.watch(songSelectionProvider);
    final activeSelecting = widget.showToolbar ? _isSelecting : globalSelection.isSelecting;
    final activeSelectedIds = widget.showToolbar ? _selectedIds : globalSelection.selectedIds;

    final songContent = RetroRefreshIndicator(
      onRefresh: () async {
        final result = await libraryNotifier.rescanLibrary();
        if (context.mounted) {
          if (result.newCount > 0) {
            RetroToast.show(
              context,
              'FOUND ${result.newCount} NEW TRACK${result.newCount == 1 ? '' : 'S'} \u2022 ${result.totalCount} TOTAL',
              icon: 'music',
              iconColor: theme.colorScheme.primary,
            );
          } else {
            RetroToast.show(
              context,
              'LIBRARY UP TO DATE \u2022 ${result.totalCount} TRACKS',
              icon: 'check',
              iconColor: context.retro.accentGreen,
            );
          }
        }
      },
      child: libraryState.isLoading && songs.isEmpty
          ? const RetroLoadingState(
              title: 'FETCHING FROM STORAGE...',
              subtitle: 'SCANNING AUDIO FILES & EXTRACTING METADATA',
              badgeText: 'LOADING SONGS',
            )
          : songs.isEmpty
              ? LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RetroIcon(
                            libraryState.searchQuery.isNotEmpty ? 'search' : 'music',
                            size: 40,
                            color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          libraryState.searchQuery.isNotEmpty
                              ? 'NO MATCHING TRACKS FOUND'
                              : 'NO 8-BIT TRACKS FOUND',
                          style: RetroTypography.pixelHeader(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (libraryState.searchQuery.isNotEmpty) ...[
                          Text(
                            'TRY A DIFFERENT SEARCH TERM',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
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
                              _searchController.clear();
                              libraryNotifier.setSearchQuery('');
                              setState(() {});
                            },
                          ),
                        ] else
                          Text(
                            'DRAG DOWN TO RESCAN OR IMPORT MUSIC',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              fontSize: 14,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: songs.length,
              // ignore: deprecated_member_use
              cacheExtent: 500,
              addRepaintBoundaries: true,
              separatorBuilder: (context, index) => Container(
                height: 1.5,
                color: retro.borderColor.withValues(alpha: 0.4),
              ),
              itemBuilder: (context, index) {
                final song = songs[index];
                final isSelected = activeSelectedIds.contains(song.id);

                return RetroSongTile(
                  key: ValueKey(song.id),
                  song: song,
                  index: index,
                  queue: songs,
                  selectionMode: activeSelecting,
                  isSelected: isSelected,
                  onToggleSelect: () => _toggleSong(song.id),
                  onLongPress: () => _enterSelectionMode(song.id),
                );
              },
            ),
    );

    if (!widget.showToolbar) {
      return songContent;
    }

    return Column(
      children: [
        // ── Toolbar ──────────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: activeSelecting
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : retro.cardColor,
            border: Border(
              bottom: BorderSide(
                color: activeSelecting
                    ? theme.colorScheme.primary
                    : retro.borderColor,
                width: retro.borderWidth,
              ),
            ),
          ),
          child: activeSelecting
              ? _buildSelectionBar(context, theme, retro, songs)
              : _buildNormalBar(context, theme, retro, songs),
        ),

        // ── Songs List ───────────────────────────────────────────────────
        Expanded(child: songContent),
      ],
    );
  }

  Widget _buildNormalBar(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    List<Song> songs,
  ) {
    final libraryState = ref.watch(libraryProvider);
    final libraryNotifier = ref.read(libraryProvider.notifier);
    final isFiltering = libraryState.searchQuery.trim().isNotEmpty;
    final totalCount = libraryState.allSongs.length;
    final filteredCount = songs.length;

    if (_isSearchOpen) {
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
                      onChanged: (val) {
                        libraryNotifier.setSearchQuery(val);
                        setState(() {});
                      },
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
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _searchController.clear();
                        libraryNotifier.setSearchQuery('');
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
          _buildSortMenu(theme, retro, libraryState, libraryNotifier),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearchOpen = false;
                _searchController.clear();
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
                  _buildSortMenu(theme, retro, libraryState, libraryNotifier),
                  const SizedBox(width: 6),
                  // Scan folder button
                  RetroButton(
                    isCompact: true,
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    backgroundColor: retro.accentGreen,
                    textColor: Colors.black,
                    onPressed: () => ScanOptionsDialog.show(context),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RetroIcon('folder', size: 13, color: Colors.black),
                        const SizedBox(width: 4),
                        Text(
                          'IMPORT',
                          style: RetroTypography.pixelBadge(
                            color: Colors.black,
                            fontSize: 8.5,
                          ),
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

  Widget _buildSortMenu(
    ThemeData theme,
    RetroThemeTokens retro,
    LibraryState libraryState,
    LibraryNotifier libraryNotifier,
  ) {
    return PopupMenuButton<SongSortMode>(
      tooltip: "Sort songs",
      color: retro.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: retro.borderColor, width: 2.0),
        borderRadius: BorderRadius.zero,
      ),
      onSelected: (mode) => libraryNotifier.setSortMode(mode),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: SongSortMode.title,
          child: Text('SORT BY TITLE',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: SongSortMode.artist,
          child: Text('SORT BY ARTIST',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: SongSortMode.duration,
          child: Text('SORT BY DURATION',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: SongSortMode.format,
          child: Text('SORT BY FORMAT',
              style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface, fontSize: 9)),
        ),
        PopupMenuItem(
          value: SongSortMode.date,
          child: Text('SORT BY DATE',
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
              libraryState.sortMode.name.toUpperCase(),
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

  Widget _buildSelectionBar(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
    List<Song> songs,
  ) {
    final count = _selectedIds.length;
    final allIds = songs.map((s) => s.id).toList();
    final allSelected = allIds.isNotEmpty && _selectedIds.containsAll(allIds);

    return Row(
      children: [
        // Selected count badge
        RetroBadge(
          text: count == 0 ? 'SELECT SONGS' : '$count SELECTED',
          backgroundColor:
              count > 0 ? theme.colorScheme.primary : retro.borderColor,
          textColor: count > 0
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onSurface,
        ),
        const Spacer(),
        // Select all / deselect all
        GestureDetector(
          onTap: () {
            if (allSelected) {
              setState(() => _selectedIds.clear());
            } else {
              _selectAll(allIds);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: retro.borderColor, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: Text(
              allSelected ? 'DESELECT ALL' : 'SELECT ALL',
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface,
                fontSize: 8,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        // Add to playlist
        RetroButton(
          isCompact: true,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          backgroundColor: count > 0
              ? theme.colorScheme.primary
              : retro.disabledColor,
          textColor: count > 0 ? theme.colorScheme.onPrimary : retro.cardColor,
          onPressed: count > 0
              ? () => _showAddToPlaylistSheet(
                  context, _selectedIds.toList())
              : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RetroIcon('playlist', size: 13, color: count > 0 ? theme.colorScheme.onPrimary : retro.cardColor),
              const SizedBox(width: 4),
              Text(
                'ADD TO PLAYLIST',
                style: RetroTypography.pixelBadge(
                    color: count > 0 ? theme.colorScheme.onPrimary : retro.cardColor, fontSize: 8),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Cancel
        GestureDetector(
          onTap: _exitSelectionMode,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border.all(color: retro.borderColor, width: 1.5),
              borderRadius: BorderRadius.zero,
            ),
            child: RetroIcon('close',
                size: 14, color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

Future<void> showAddToPlaylistBottomSheet(
  BuildContext context,
  WidgetRef ref,
  List<String> songIds, {
  VoidCallback? onDone,
}) async {
  final theme = Theme.of(context);
  final retro = context.retro;
  final playlists =
      ref.read(playlistProvider).playlists.where((p) => !p.isSystem).toList();
  final allSongs = ref.read(libraryProvider).allSongs;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: retro.cardColor,
    isScrollControlled: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.zero,
      side: BorderSide(color: retro.borderColor, width: 2),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                border: Border(
                    bottom:
                        BorderSide(color: retro.borderColor, width: 2)),
              ),
              child: Row(
                children: [
                  const RetroIcon('playlist', size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ADD ${songIds.length} TRACK${songIds.length == 1 ? '' : 'S'} TO PLAYLIST',
                      style: RetroTypography.pixelHeader(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: const RetroIcon('close', size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
            if (playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'NO PLAYLISTS YET.\nCREATE ONE FIRST.',
                    textAlign: TextAlign.center,
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 16,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  separatorBuilder: (context, index) => Container(
                    height: 1,
                    color: retro.borderColor.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (context, i) {
                    final pl = playlists[i];
                    return InkWell(
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        await ref
                            .read(playlistProvider.notifier)
                            .addSongsToPlaylist(pl.id, songIds);
                        onDone?.call();
                        if (context.mounted) {
                          RetroToast.show(
                            context,
                            '${songIds.length} TRACK${songIds.length == 1 ? '' : 'S'} ADDED TO ${pl.name.toUpperCase()}',
                            icon: 'playlist',
                            iconColor: theme.colorScheme.primary,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const RetroIcon('playlist', size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pl.name.toUpperCase(),
                                style: RetroTypography.pixelBadge(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            Text(
                              '${pl.getValidSongCount(allSongs)} TRACKS',
                              style: RetroTypography.retroMono(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const RetroIcon('arrow_down', size: 14),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );
    },
  );
}

