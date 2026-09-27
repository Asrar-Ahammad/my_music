import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../core/utils/duration_formatter.dart';
import '../../../domain/models/song.dart';
import '../../providers/player_provider.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_song_tile.dart';

enum CategorySortMode {
  defaultOrder,
  title,
  artist,
  duration,
}

class SongCategory {
  final String id;
  final String name;
  final String type; // 'Mood', 'Genre', 'Energy'
  final String iconName;
  final Color color;
  final List<Song> songs;

  const SongCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.iconName,
    required this.color,
    required this.songs,
  });
}

class CategoryDetailScreen extends ConsumerStatefulWidget {
  final SongCategory category;
  final VoidCallback? onBack;

  const CategoryDetailScreen({
    super.key,
    required this.category,
    this.onBack,
  });

  @override
  ConsumerState<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  CategorySortMode _sortMode = CategorySortMode.defaultOrder;
  bool _sortAscending = true;
  bool _filterFavOnly = false;
  bool _isSearchVisible = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Song> _getFilteredAndSortedSongs() {
    final query = _searchController.text.toLowerCase().trim();

    // 1. Filter
    List<Song> result = widget.category.songs.where((s) {
      final matchesQuery = query.isEmpty ||
          s.title.toLowerCase().contains(query) ||
          s.artist.toLowerCase().contains(query) ||
          s.album.toLowerCase().contains(query);
      final matchesFav = !_filterFavOnly || s.isFavorite;
      return matchesQuery && matchesFav;
    }).toList();

    // 2. Sort
    switch (_sortMode) {
      case CategorySortMode.title:
        result.sort((a, b) => _sortAscending
            ? a.title.toLowerCase().compareTo(b.title.toLowerCase())
            : b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case CategorySortMode.artist:
        result.sort((a, b) => _sortAscending
            ? a.artist.toLowerCase().compareTo(b.artist.toLowerCase())
            : b.artist.toLowerCase().compareTo(a.artist.toLowerCase()));
        break;
      case CategorySortMode.duration:
        result.sort((a, b) => _sortAscending
            ? a.duration.compareTo(b.duration)
            : b.duration.compareTo(a.duration));
        break;
      case CategorySortMode.defaultOrder:
        if (!_sortAscending) {
          result = result.reversed.toList();
        }
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final playerNotifier = ref.read(playerProvider.notifier);

    final displaySongs = _getFilteredAndSortedSongs();
    final totalDuration = widget.category.songs.fold<Duration>(
      Duration.zero,
      (sum, s) => sum + s.duration,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const RetroIcon('arrow_left', size: 20),
          onPressed: () {
            if (widget.onBack != null) {
              widget.onBack!();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          widget.category.name.toUpperCase(),
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: RetroIcon(
              _isSearchVisible ? 'close' : 'search',
              size: 18,
              color: _isSearchVisible ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
            tooltip: _isSearchVisible ? 'Close Search' : 'Search Songs',
            onPressed: () {
              setState(() {
                _isSearchVisible = !_isSearchVisible;
                if (!_isSearchVisible) {
                  _searchController.clear();
                  _searchFocusNode.unfocus();
                } else {
                  _searchFocusNode.requestFocus();
                }
              });
            },
          ),
          _buildSortMenu(theme, retro),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Banner with Category Info, Play All, and Shuffle Play
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border(
                bottom: BorderSide(
                  color: retro.borderColor,
                  width: retro.borderWidth,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category Icon / Visual Badge
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: widget.category.color.withValues(alpha: 0.18),
                        border: Border.all(
                          color: widget.category.color,
                          width: 2.0,
                        ),
                      ),
                      child: Center(
                        child: RetroIcon(
                          widget.category.iconName,
                          size: 26,
                          color: widget.category.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.category.name.toUpperCase(),
                                style: RetroTypography.pixelHeader(
                                  color: theme.colorScheme.onSurface,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 8),
                              RetroBadge(
                                text: widget.category.type.toUpperCase(),
                                backgroundColor: widget.category.color.withValues(alpha: 0.2),
                                textColor: widget.category.color,
                                fontSize: 7.5,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.category.songs.length} Tracks • ${DurationFormatter.format(totalDuration)} Total',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.category.songs.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: RetroButton(
                          label: 'PLAY ALL',
                          icon: const RetroIcon('play', size: 14),
                          backgroundColor: theme.colorScheme.primary,
                          textColor: theme.colorScheme.onPrimary,
                          onPressed: () {
                            playerNotifier.playSong(
                              displaySongs.isNotEmpty ? displaySongs.first : widget.category.songs.first,
                              queue: displaySongs.isNotEmpty ? displaySongs : widget.category.songs,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RetroButton(
                          label: 'SHUFFLE PLAY',
                          icon: const RetroIcon('shuffle', size: 14),
                          backgroundColor: retro.cardColor,
                          textColor: theme.colorScheme.onSurface,
                          borderColor: retro.borderColor,
                          onPressed: () {
                            final songsToShuffle = List<Song>.from(
                              displaySongs.isNotEmpty ? displaySongs : widget.category.songs,
                            )..shuffle();
                            if (songsToShuffle.isNotEmpty) {
                              playerNotifier.playSong(
                                songsToShuffle.first,
                                queue: songsToShuffle,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Collapsible Inline Search Bar
          if (_isSearchVisible)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  bottom: BorderSide(color: retro.borderColor, width: 1.5),
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface,
                  fontSize: 11,
                ),
                decoration: InputDecoration(
                  hintText: 'FILTER TRACKS IN ${widget.category.name.toUpperCase()}...',
                  hintStyle: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 8.5,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(10),
                    child: RetroIcon('search', size: 16),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const RetroIcon('close', size: 14),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: retro.cardColor,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: retro.borderColor, width: 1.5),
                    borderRadius: BorderRadius.zero,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: retro.borderColor, width: 1.5),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: theme.colorScheme.primary, width: 2.0),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ),

          // Secondary Filter Bar: Favorites toggle & active count badge
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _filterFavOnly = !_filterFavOnly),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _filterFavOnly ? theme.colorScheme.primary : retro.cardColor,
                      border: Border.all(
                        color: _filterFavOnly ? theme.colorScheme.primary : retro.borderColor,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RetroIcon(
                          _filterFavOnly ? 'heart_filled' : 'heart',
                          size: 12,
                          color: _filterFavOnly ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'FAVORITES',
                          style: RetroTypography.pixelBadge(
                            color: _filterFavOnly ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                            fontSize: 8.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                RetroBadge(
                  text: '${displaySongs.length} TRACK${displaySongs.length == 1 ? '' : 'S'}',
                  backgroundColor: retro.cardColor,
                  textColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  fontSize: 8.0,
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Track List
          Expanded(
            child: displaySongs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RetroIcon(widget.category.iconName, size: 36, color: widget.category.color),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isNotEmpty
                                ? 'NO TRACKS MATCHING "${_searchController.text.toUpperCase()}"'
                                : 'NO TRACKS IN THIS CATEGORY',
                            textAlign: TextAlign.center,
                            style: RetroTypography.pixelHeader(
                              color: theme.colorScheme.onSurface,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 120),
                    itemCount: displaySongs.length,
                    itemBuilder: (context, index) {
                      final song = displaySongs[index];
                      return RetroSongTile(
                        song: song,
                        index: index,
                        queue: displaySongs,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortMenu(ThemeData theme, RetroThemeTokens retro) {
    return PopupMenuButton<CategorySortMode>(
      tooltip: 'Sort Category Tracks',
      icon: const RetroIcon('sort', size: 18),
      color: retro.cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: retro.borderColor, width: 2.0),
        borderRadius: BorderRadius.zero,
      ),
      onSelected: (mode) {
        setState(() {
          if (_sortMode == mode) {
            _sortAscending = !_sortAscending;
          } else {
            _sortMode = mode;
            _sortAscending = true;
          }
        });
      },
      itemBuilder: (context) => [
        _buildSortMenuItem(
          mode: CategorySortMode.defaultOrder,
          label: 'DEFAULT ORDER',
          theme: theme,
        ),
        _buildSortMenuItem(
          mode: CategorySortMode.title,
          label: 'TITLE (A-Z)',
          theme: theme,
        ),
        _buildSortMenuItem(
          mode: CategorySortMode.artist,
          label: 'ARTIST (A-Z)',
          theme: theme,
        ),
        _buildSortMenuItem(
          mode: CategorySortMode.duration,
          label: 'DURATION',
          theme: theme,
        ),
      ],
    );
  }

  PopupMenuItem<CategorySortMode> _buildSortMenuItem({
    required CategorySortMode mode,
    required String label,
    required ThemeData theme,
  }) {
    final isSelected = _sortMode == mode;
    return PopupMenuItem<CategorySortMode>(
      value: mode,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: RetroTypography.pixelBadge(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                fontSize: 9.0,
              ),
            ),
          ),
          if (isSelected)
            RetroIcon(
              _sortAscending ? 'arrow_up' : 'arrow_down',
              size: 14,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
