import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../domain/models/ai_song_tags.dart';
import '../../../domain/models/album.dart';
import '../../../domain/models/artist.dart';
import '../../../domain/models/audio_quality.dart';
import '../../../domain/models/playlist.dart';
import '../../../domain/models/song.dart';
import '../../providers/library_provider.dart';
import '../../providers/library_tagger_provider.dart';
import '../../providers/playlist_provider.dart';
import '../library/album_detail_screen.dart';
import '../library/artist_detail_screen.dart';
import '../playlists/playlist_detail_screen.dart';
import '../home_scaffold.dart';
import '../../../data/services/storage_service.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_badge.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_song_tile.dart';
import 'category_detail_screen.dart';

class _QualityFilterOption {
  final String id;
  final String label;
  final Color activeColor;
  final bool Function(Song) matches;

  const _QualityFilterOption({
    required this.id,
    required this.label,
    required this.activeColor,
    required this.matches,
  });
}

enum SearchCategory {
  all,
  songs,
  albums,
  artists,
  playlists;

  String get label {
    switch (this) {
      case SearchCategory.all:
        return 'ALL';
      case SearchCategory.songs:
        return 'SONGS';
      case SearchCategory.albums:
        return 'ALBUMS';
      case SearchCategory.artists:
        return 'ARTISTS';
      case SearchCategory.playlists:
        return 'PLAYLISTS';
    }
  }

  String get iconName {
    switch (this) {
      case SearchCategory.all:
        return 'grid';
      case SearchCategory.songs:
        return 'music';
      case SearchCategory.albums:
        return 'disc';
      case SearchCategory.artists:
        return 'user';
      case SearchCategory.playlists:
        return 'playlist';
    }
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  final bool isActive;
  const SearchScreen({super.key, this.isActive = true});

  @override
  ConsumerState<SearchScreen> createState() => SearchScreenState();
}

class SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  SearchCategory _selectedCategory = SearchCategory.all;
  final Set<String> _selectedQualities = {};
  bool _filterFavOnly = false;

  Album? _selectedAlbum;
  Artist? _selectedArtist;
  Playlist? _selectedPlaylist;
  SongCategory? _selectedCategoryDetail;
  String _selectedCategoryTypeFilter = 'ALL';

  bool get canPop =>
      _selectedCategoryDetail != null ||
      _selectedAlbum != null ||
      _selectedArtist != null ||
      _selectedPlaylist != null;

  void popToRoot() {
    if (canPop) {
      setState(() {
        _selectedCategoryDetail = null;
        _selectedAlbum = null;
        _selectedArtist = null;
        _selectedPlaylist = null;
      });
    }
  }

  void focusSearchInput() {
    if (!mounted) return;

    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.show');
        }
      });
    } else {
      _focusNode.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    }

    if (_searchController.text.isNotEmpty) {
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: _searchController.text.length),
      );
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Focus is now requested explicitly by the navbar tap via focusSearchInput().
    // No defensive unfocus needed here.
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedCategoryDetail != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final home = HomeScaffold.of(context);
          if ((home != null && home.isNowPlayingExpanded) ||
              StorageService().isNowPlayingDrawerOpen()) {
            return;
          }
          setState(() => _selectedCategoryDetail = null);
        },
        child: CategoryDetailScreen(
          category: _selectedCategoryDetail!,
          onBack: () => setState(() => _selectedCategoryDetail = null),
        ),
      );
    }

    if (_selectedAlbum != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final home = HomeScaffold.of(context);
          if ((home != null && home.isNowPlayingExpanded) ||
              StorageService().isNowPlayingDrawerOpen()) {
            return;
          }
          setState(() => _selectedAlbum = null);
        },
        child: AlbumDetailScreen(
          album: _selectedAlbum!,
          onBack: () => setState(() => _selectedAlbum = null),
        ),
      );
    }

    if (_selectedArtist != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final home = HomeScaffold.of(context);
          if ((home != null && home.isNowPlayingExpanded) ||
              StorageService().isNowPlayingDrawerOpen()) {
            return;
          }
          setState(() => _selectedArtist = null);
        },
        child: ArtistDetailScreen(
          artist: _selectedArtist!,
          onBack: () => setState(() => _selectedArtist = null),
        ),
      );
    }

    if (_selectedPlaylist != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final home = HomeScaffold.of(context);
          if ((home != null && home.isNowPlayingExpanded) ||
              StorageService().isNowPlayingDrawerOpen()) {
            return;
          }
          setState(() => _selectedPlaylist = null);
        },
        child: PlaylistDetailScreen(
          playlist: _selectedPlaylist!,
          onBack: () => setState(() => _selectedPlaylist = null),
        ),
      );
    }

    final libraryState = ref.watch(libraryProvider);
    final playlistState = ref.watch(playlistProvider);
    final theme = Theme.of(context);
    final retro = context.retro;

    final query = _searchController.text.toLowerCase().trim();

    // Dynamic quality filters discovered from songs in the library
    final allSongs = libraryState.allSongs;
    final availableQualityFilters = <_QualityFilterOption>[
      if (allSongs.any((s) => s.quality.isHiRes))
        _QualityFilterOption(
          id: 'hi_res',
          label: 'HI-RES',
          activeColor: retro.accentGreen,
          matches: (s) => s.quality.isHiRes,
        ),
      if (allSongs.any((s) => s.quality.isLossless && !s.quality.isHiRes))
        _QualityFilterOption(
          id: 'lossless',
          label: 'LOSSLESS',
          activeColor: theme.colorScheme.primary,
          matches: (s) => s.quality.isLossless && !s.quality.isHiRes,
        ),
      if (allSongs.any((s) => s.quality.isDolbyAtmos))
        _QualityFilterOption(
          id: 'dolby_atmos',
          label: 'DOLBY ATMOS',
          activeColor: theme.colorScheme.secondary,
          matches: (s) => s.quality.isDolbyAtmos,
        ),
      if (allSongs.any((s) => s.quality.isSpatialAudio && !s.quality.isDolbyAtmos))
        _QualityFilterOption(
          id: 'spatial',
          label: 'SPATIAL',
          activeColor: retro.accentPurple,
          matches: (s) => s.quality.isSpatialAudio && !s.quality.isDolbyAtmos,
        ),
      if (allSongs.any((s) => s.quality.isHighQuality))
        _QualityFilterOption(
          id: 'hq',
          label: 'HQ',
          activeColor: retro.accentYellow,
          matches: (s) => s.quality.isHighQuality,
        ),
      if (allSongs.any((s) => s.quality.qualityTier == AudioQualityTier.standard))
        _QualityFilterOption(
          id: 'standard',
          label: 'STANDARD',
          activeColor: theme.colorScheme.secondary,
          matches: (s) => s.quality.qualityTier == AudioQualityTier.standard,
        ),
      if (allSongs.any((s) => s.quality.qualityTier == AudioQualityTier.low))
        _QualityFilterOption(
          id: 'low',
          label: 'LOW',
          activeColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          matches: (s) => s.quality.qualityTier == AudioQualityTier.low,
        ),
    ];

    bool songMatchesQuality(Song s) {
      if (_selectedQualities.isEmpty) return true;
      return availableQualityFilters
          .where((f) => _selectedQualities.contains(f.id))
          .any((f) => f.matches(s));
    }

    // 1. Matching Songs
    final matchingSongs = libraryState.allSongs.where((s) {
      final matchesQuery = query.isEmpty ||
          s.title.toLowerCase().contains(query) ||
          s.artist.toLowerCase().contains(query) ||
          s.album.toLowerCase().contains(query);

      final matchesQuality = songMatchesQuality(s);
      final matchesFav = !_filterFavOnly || s.isFavorite;

      return matchesQuery && matchesQuality && matchesFav;
    }).toList();

    // 2. Matching Albums
    final matchingAlbums = libraryState.albums.where((a) {
      final matchesQuery = query.isEmpty ||
          a.title.toLowerCase().contains(query) ||
          a.artist.toLowerCase().contains(query);

      final matchesQuality = _selectedQualities.isEmpty ||
          a.songs.any(songMatchesQuality);
      final matchesFav = !_filterFavOnly || a.songs.any((s) => s.isFavorite);

      return matchesQuery && matchesQuality && matchesFav;
    }).toList();

    // 3. Matching Artists
    final matchingArtists = libraryState.artists.where((art) {
      final matchesQuery = query.isEmpty || art.name.toLowerCase().contains(query);

      final matchesQuality = _selectedQualities.isEmpty ||
          art.songs.any(songMatchesQuality);
      final matchesFav = !_filterFavOnly || art.songs.any((s) => s.isFavorite);

      return matchesQuery && matchesQuality && matchesFav;
    }).toList();

    // 4. Matching Playlists (excluding system playlists)
    final userPlaylists = playlistState.playlists.where((p) => !p.isSystem).toList();
    final matchingPlaylists = userPlaylists.where((p) {
      final matchesQuery = query.isEmpty || p.name.toLowerCase().contains(query);
      if (!matchesQuery) return false;

      if (_selectedQualities.isEmpty && !_filterFavOnly) return true;

      final playlistSongs = libraryState.allSongs.where((s) => p.songIds.contains(s.id));
      if (playlistSongs.isEmpty) return false;

      final matchesQuality = _selectedQualities.isEmpty ||
          playlistSongs.any(songMatchesQuality);
      final matchesFav = !_filterFavOnly || playlistSongs.any((s) => s.isFavorite);

      return matchesQuality && matchesFav;
    }).toList();

    final totalMatches = matchingSongs.length +
        matchingAlbums.length +
        matchingArtists.length +
        matchingPlaylists.length;

    int currentCategoryCount;
    switch (_selectedCategory) {
      case SearchCategory.all:
        currentCategoryCount = totalMatches;
        break;
      case SearchCategory.songs:
        currentCategoryCount = matchingSongs.length;
        break;
      case SearchCategory.albums:
        currentCategoryCount = matchingAlbums.length;
        break;
      case SearchCategory.artists:
        currentCategoryCount = matchingArtists.length;
        break;
      case SearchCategory.playlists:
        currentCategoryCount = matchingPlaylists.length;
        break;
    }

    final Widget searchInputField = TextField(
      controller: _searchController,
      focusNode: _focusNode,
      autofocus: false,
      onChanged: (_) => setState(() {}),
      style: RetroTypography.pixelBadge(
        color: theme.colorScheme.onSurface,
        fontSize: 11,
      ),
      decoration: InputDecoration(
        hintText: 'SEARCH SONGS, ALBUMS, ARTISTS, PLAYLISTS...',
        hintStyle: RetroTypography.pixelBadge(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 9.0,
        ),
        prefixIcon: const Padding(
          padding: EdgeInsets.all(10),
          child: RetroIcon('search', size: 18),
        ),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const RetroIcon('close', size: 16),
                onPressed: () {
                  _searchController.clear();
                  _focusNode.unfocus();
                  setState(() {});
                },
              )
            : null,
        filled: true,
        fillColor: retro.cardColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: retro.borderColor,
            width: 2.5,
          ),
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: retro.borderColor,
            width: 2.5,
          ),
          borderRadius: BorderRadius.zero,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2.5,
          ),
          borderRadius: BorderRadius.zero,
        ),
      ),
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar Input
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: searchInputField,
            ),

            // 2. Category & Filter Bar — only shown when user has typed a query
            if (query.isNotEmpty) ...[
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildCategoryChip(
                      category: SearchCategory.all,
                      count: totalMatches,
                    ),
                    _buildCategoryChip(
                      category: SearchCategory.songs,
                      count: matchingSongs.length,
                    ),
                    _buildCategoryChip(
                      category: SearchCategory.albums,
                      count: matchingAlbums.length,
                    ),
                    _buildCategoryChip(
                      category: SearchCategory.artists,
                      count: matchingArtists.length,
                    ),
                    _buildCategoryChip(
                      category: SearchCategory.playlists,
                      count: matchingPlaylists.length,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // 3. Secondary Filter Chips (Favorites & Dynamic Quality Filters) & Match Count Badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 28,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildFilterChip(
                              label: 'FAVORITES',
                              isActive: _filterFavOnly,
                              activeColor: theme.colorScheme.primary,
                              onTap: () => setState(() => _filterFavOnly = !_filterFavOnly),
                            ),
                            for (final qFilter in availableQualityFilters) ...[
                              const SizedBox(width: 6),
                              _buildFilterChip(
                                label: qFilter.label,
                                isActive: _selectedQualities.contains(qFilter.id),
                                activeColor: qFilter.activeColor,
                                onTap: () {
                                  setState(() {
                                    if (_selectedQualities.contains(qFilter.id)) {
                                      _selectedQualities.remove(qFilter.id);
                                    } else {
                                      _selectedQualities.add(qFilter.id);
                                    }
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RetroBadge(
                      text: '$currentCategoryCount MATCH${currentCategoryCount == 1 ? '' : 'ES'}',
                      backgroundColor: retro.cardColor,
                      textColor: theme.colorScheme.onSurface,
                      fontSize: 8.0,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Container(height: 2, color: retro.borderColor),
            ],

            // 4. Browse Grid (empty query) or Search Results (typed query)
            Expanded(
              child: _buildResultsBody(
                context: context,
                query: query,
                matchingSongs: matchingSongs,
                matchingAlbums: matchingAlbums,
                matchingArtists: matchingArtists,
                matchingPlaylists: matchingPlaylists,
                librarySongs: libraryState.allSongs,
                totalMatches: totalMatches,
                allPlaylists: playlistState.playlists.where((p) => !p.isSystem).toList(),
                allAlbums: libraryState.albums,
                allArtists: libraryState.artists,
                folders: libraryState.folders,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCategoryChip({
    required SearchCategory category,
    required int count,
  }) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = category;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : retro.cardColor,
            border: Border.all(
              color: isSelected ? theme.colorScheme.primary : retro.borderColor,
              width: 2.0,
            ),
            borderRadius: BorderRadius.zero,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RetroIcon(
                category.iconName,
                size: 12,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
              const SizedBox(width: 5),
              Text(
                category.label,
                style: RetroTypography.pixelBadge(
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  fontSize: 8.5,
                ),
              ),
              if (category != SearchCategory.all) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.onPrimary.withValues(alpha: 0.2)
                        : retro.borderColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Text(
                    '$count',
                    style: RetroTypography.pixelBadge(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                      fontSize: 7.5,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final retro = context.retro;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor : retro.cardColor,
          border: Border.all(
            color: isActive ? activeColor : retro.borderColor,
            width: 2.0,
          ),
          borderRadius: BorderRadius.zero,
        ),
        child: Text(
          label,
          style: RetroTypography.pixelBadge(
            color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 8.5,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsBody({
    required BuildContext context,
    required String query,
    required List<Song> matchingSongs,
    required List<Album> matchingAlbums,
    required List<Artist> matchingArtists,
    required List<Playlist> matchingPlaylists,
    required List<Song> librarySongs,
    required int totalMatches,
    List<Playlist> allPlaylists = const [],
    List<Album> allAlbums = const [],
    List<Artist> allArtists = const [],
    Map<String, List<Song>> folders = const {},
  }) {
    final theme = Theme.of(context);

    // Browse mode: no query typed yet — show categorized cards
    if (query.isEmpty) {
      return _buildBrowseGrid(
        context: context,
        allSongs: librarySongs,
        folders: folders,
        allAlbums: allAlbums,
        allArtists: allArtists,
        allPlaylists: allPlaylists,
      );
    }

    // Check empty search results
    if (totalMatches == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RetroIcon('search', size: 40),
              const SizedBox(height: 14),
              Text(
                'NO MATCHES FOUND FOR "${_searchController.text.toUpperCase()}"',
                textAlign: TextAlign.center,
                style: RetroTypography.pixelHeader(
                  color: theme.colorScheme.onSurface,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'TRY SEARCHING BY SONG TITLE, ARTIST, ALBUM, OR PLAYLIST NAME.',
                textAlign: TextAlign.center,
                style: RetroTypography.retroMono(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }

    switch (_selectedCategory) {
      case SearchCategory.all:
        return _buildAllCategoriesView(
          context: context,
          query: query,
          matchingSongs: matchingSongs,
          matchingAlbums: matchingAlbums,
          matchingArtists: matchingArtists,
          matchingPlaylists: matchingPlaylists,
          librarySongs: librarySongs,
        );

      case SearchCategory.songs:
        return _buildSongsListView(matchingSongs);

      case SearchCategory.albums:
        return _buildAlbumsListView(context, matchingAlbums);

      case SearchCategory.artists:
        return _buildArtistsListView(context, matchingArtists);

      case SearchCategory.playlists:
        return _buildPlaylistsListView(context, matchingPlaylists, librarySongs);
    }
  }

  List<SongCategory> _generateCategories(
    List<Song> allSongs,
    Map<String, AiSongTags> taggedSongs,
    RetroThemeTokens retro,
    ThemeData theme,
  ) {
    const moodMeta = [
      {'id': 'chill', 'name': 'Chill', 'icon': 'moon', 'color': Color(0xFF00E5FF)},
      {'id': 'focus', 'name': 'Focus', 'icon': 'equalizer', 'color': Color(0xFF9D4EDD)},
      {'id': 'high_energy', 'name': 'High Energy', 'icon': 'sparkles', 'color': Color(0xFFFF5722)},
      {'id': 'melancholy', 'name': 'Melancholy', 'icon': 'music', 'color': Color(0xFF4A90E2)},
      {'id': 'euphoric', 'name': 'Euphoric', 'icon': 'sun', 'color': Color(0xFFFF4081)},
    ];

    const genreMeta = [
      {'id': 'lofi', 'name': 'Lo-Fi', 'icon': 'sliders', 'color': Color(0xFFE07A5F)},
      {'id': 'synthwave', 'name': 'Synthwave', 'icon': 'playlist', 'color': Color(0xFFE056FD)},
      {'id': 'acoustic', 'name': 'Acoustic', 'icon': 'music', 'color': Color(0xFFFFBE0B)},
      {'id': 'electronic', 'name': 'Electronic', 'icon': 'sparkles', 'color': Color(0xFF00F5D4)},
      {'id': 'rock', 'name': 'Rock', 'icon': 'headphone', 'color': Color(0xFFFF0054)},
      {'id': 'hiphop', 'name': 'Hip-Hop', 'icon': 'speaker', 'color': Color(0xFF9B5DE5)},
      {'id': 'classical', 'name': 'Classical', 'icon': 'disc', 'color': Color(0xFF00BBF9)},
    ];

    const energyMeta = [
      {'id': 'energy_high', 'name': 'High Energy', 'key': 'High', 'icon': 'sparkles', 'color': Color(0xFFFF3366)},
      {'id': 'energy_medium', 'name': 'Medium Energy', 'key': 'Medium', 'icon': 'equalizer', 'color': Color(0xFFFFB703)},
      {'id': 'energy_low', 'name': 'Low Energy', 'key': 'Low', 'icon': 'moon', 'color': Color(0xFF48CAE4)},
    ];

    final categories = <SongCategory>[];

    // 1. Moods
    for (final meta in moodMeta) {
      final name = meta['name'] as String;
      final matchingSongs = allSongs.where((s) {
        final tag = taggedSongs[s.id];
        return tag?.mood != null && tag!.mood!.toLowerCase() == name.toLowerCase();
      }).toList();

      categories.add(SongCategory(
        id: meta['id'] as String,
        name: name,
        type: 'Mood',
        iconName: meta['icon'] as String,
        color: meta['color'] as Color,
        songs: matchingSongs,
      ));
    }

    // 2. Genres
    for (final meta in genreMeta) {
      final name = meta['name'] as String;
      final matchingSongs = allSongs.where((s) {
        final tag = taggedSongs[s.id];
        return tag?.genre != null && tag!.genre!.toLowerCase() == name.toLowerCase();
      }).toList();

      categories.add(SongCategory(
        id: meta['id'] as String,
        name: name,
        type: 'Genre',
        iconName: meta['icon'] as String,
        color: meta['color'] as Color,
        songs: matchingSongs,
      ));
    }

    // Extra genres from tags if any
    final knownGenres = genreMeta.map((m) => (m['name'] as String).toLowerCase()).toSet();
    final extraGenres = taggedSongs.values
        .map((t) => t.genre)
        .whereType<String>()
        .where((g) => !knownGenres.contains(g.toLowerCase()))
        .toSet();

    for (final extra in extraGenres) {
      final matchingSongs = allSongs.where((s) {
        final tag = taggedSongs[s.id];
        return tag?.genre != null && tag!.genre!.toLowerCase() == extra.toLowerCase();
      }).toList();

      categories.add(SongCategory(
        id: 'genre_${extra.toLowerCase()}',
        name: extra,
        type: 'Genre',
        iconName: 'music',
        color: retro.accentPurple,
        songs: matchingSongs,
      ));
    }

    // 3. Energy Levels
    for (final meta in energyMeta) {
      final key = meta['key'] as String;
      final name = meta['name'] as String;
      final matchingSongs = allSongs.where((s) {
        final tag = taggedSongs[s.id];
        return tag?.energyLevel != null && tag!.energyLevel!.toLowerCase() == key.toLowerCase();
      }).toList();

      categories.add(SongCategory(
        id: meta['id'] as String,
        name: name,
        type: 'Energy',
        iconName: meta['icon'] as String,
        color: meta['color'] as Color,
        songs: matchingSongs,
      ));
    }

    return categories;
  }

  /// Browse categories view shown when search query is empty.
  /// Shows cards displaying different categories after the user has categorized songs.
  Widget _buildBrowseGrid({
    required BuildContext context,
    required List<Song> allSongs,
    required Map<String, List<Song>> folders,
    required List<Album> allAlbums,
    required List<Artist> allArtists,
    required List<Playlist> allPlaylists,
  }) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final taggerState = ref.watch(libraryTaggerProvider);
    final taggerNotifier = ref.read(libraryTaggerProvider.notifier);

    final allCategories = _generateCategories(allSongs, taggerState.taggedSongs, retro, theme);

    // If user has tagged songs, prioritize categories that contain songs
    final hasTagged = taggerState.taggedSongs.isNotEmpty;
    List<SongCategory> displayedCategories = hasTagged
        ? allCategories.where((c) => c.songs.isNotEmpty).toList()
        : allCategories;

    // Apply type filter if user selected MOOD, GENRE, or ENERGY
    if (_selectedCategoryTypeFilter != 'ALL') {
      displayedCategories = displayedCategories
          .where((c) => c.type.toUpperCase() == _selectedCategoryTypeFilter)
          .toList();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
      children: [
        // 1. Scanning In Progress Banner
        if (taggerState.isScanning) ...[
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              border: Border.all(color: theme.colorScheme.primary, width: 2.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const RetroIcon('sparkles', size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CATEGORIZING LIBRARY...',
                        style: RetroTypography.pixelHeader(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => taggerNotifier.cancelScan(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: retro.cardColor,
                          border: Border.all(color: retro.borderColor, width: 1.5),
                        ),
                        child: Text(
                          'CANCEL',
                          style: RetroTypography.pixelBadge(
                            color: theme.colorScheme.onSurface,
                            fontSize: 7.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  child: LinearProgressIndicator(
                    value: taggerState.progress,
                    backgroundColor: retro.borderColor.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        taggerState.currentSongTitle ?? 'ANALYZING TRACKS...',
                        style: RetroTypography.retroMono(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${taggerState.scannedCount}/${taggerState.totalCount} (${(taggerState.progress * 100).toInt()}%)',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.primary,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ]
        // 2. Uncategorized Library Prompt (if not scanned yet)
        else if (!hasTagged && allSongs.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: retro.cardColor,
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.6), width: 2.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        border: Border.all(color: theme.colorScheme.primary, width: 1.5),
                      ),
                      child: RetroIcon('sparkles', size: 20, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CATEGORIZE YOUR SONGS',
                            style: RetroTypography.pixelHeader(
                              color: theme.colorScheme.onSurface,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Auto-tag songs into Moods, Genres & Energy levels offline.',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: RetroButton(
                    label: 'CATEGORIZE NOW',
                    icon: const RetroIcon('sparkles', size: 14),
                    backgroundColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                    onPressed: () {
                      final songsToScan = allSongs.isNotEmpty
                          ? allSongs
                          : ref.read(libraryProvider).allSongs;
                      taggerNotifier.scanUncategorized(songsToScan);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],

        // 3. Category Header Bar & Type Filter Chips
        Row(
          children: [
            Text(
              'CATEGORIES',
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 8.5,
              ),
            ),
            if (hasTagged) ...[
              const SizedBox(width: 8),
              RetroBadge(
                text: '${taggerState.taggedSongs.length} TAGGED',
                backgroundColor: retro.accentGreen.withValues(alpha: 0.15),
                textColor: retro.accentGreen,
                fontSize: 7.5,
              ),
            ],
            const Spacer(),
            if (hasTagged && !taggerState.isScanning)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Incremental: only tag songs that have no category yet
                  final songsToScan = allSongs.isNotEmpty
                      ? allSongs
                      : ref.read(libraryProvider).allSongs;
                  taggerNotifier.scanUncategorized(songsToScan);
                },
                onLongPress: () {
                  // Full rescan (long-press): wipe all tags and redo everything
                  final songsToScan = allSongs.isNotEmpty
                      ? allSongs
                      : ref.read(libraryProvider).allSongs;
                  taggerNotifier.rescan(songsToScan);
                },
                child: Tooltip(
                  message: 'Tap: scan new songs only\nLong-press: full rescan',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: retro.cardColor,
                      border: Border.all(color: retro.borderColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const RetroIcon('refresh', size: 12),
                        const SizedBox(width: 5),
                        Text(
                          'RE-SCAN',
                          style: RetroTypography.pixelBadge(
                            color: theme.colorScheme.onSurface,
                            fontSize: 8.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Type Filter Chips: ALL, MOODS, GENRES, ENERGY
        SizedBox(
          height: 28,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildTypeFilterChip('ALL', 'ALL', theme, retro),
              const SizedBox(width: 6),
              _buildTypeFilterChip('MOOD', 'MOODS', theme, retro),
              const SizedBox(width: 6),
              _buildTypeFilterChip('GENRE', 'GENRES', theme, retro),
              const SizedBox(width: 6),
              _buildTypeFilterChip('ENERGY', 'ENERGY', theme, retro),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // 4. Category Cards Grid
        if (displayedCategories.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: Text(
              'NO CATEGORIES FOUND IN THIS FILTER',
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 9.0,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.1,
            ),
            itemCount: displayedCategories.length,
            itemBuilder: (context, index) {
              final category = displayedCategories[index];
              return _buildCategoryCard(category, theme, retro);
            },
          ),

        // 5. Folders Section (if any)
        if (folders.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'FOLDERS',
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontSize: 8.5,
            ),
          ),
          const SizedBox(height: 10),
          ...folders.entries.map((entry) {
            final folderName = entry.key.split('/').last;
            final songCount = entry.value.length;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryDetail = SongCategory(
                    id: 'folder_${entry.key}',
                    name: folderName,
                    type: 'Folder',
                    iconName: 'folder',
                    color: theme.colorScheme.primary,
                    songs: entry.value,
                  );
                });
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border.all(color: retro.borderColor, width: 1.5),
                ),
                child: Row(
                  children: [
                    RetroIcon('folder', size: 20,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folderName.toUpperCase(),
                            style: RetroTypography.pixelBadge(
                              color: theme.colorScheme.onSurface,
                              fontSize: 9.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$songCount TRACK${songCount == 1 ? '' : 'S'}',
                            style: RetroTypography.retroMono(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const RetroIcon('chevron_right', size: 14),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildCategoryCard(
    SongCategory category,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final color = category.color;
    final trackCount = category.songs.length;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategoryDetail = category;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          border: Border.all(color: color.withValues(alpha: 0.6), width: 2.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                border: Border.all(color: color, width: 1.5),
              ),
              child: Center(
                child: RetroIcon(category.iconName, size: 18, color: color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    category.name.toUpperCase(),
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 9.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        '$trackCount TRACK${trackCount == 1 ? '' : 'S'}',
                        style: RetroTypography.retroMono(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          fontSize: 9.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• ${category.type.toUpperCase()}',
                        style: RetroTypography.retroMono(
                          color: color,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            RetroIcon('chevron_right', size: 12, color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilterChip(
    String typeKey,
    String label,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final isSelected = _selectedCategoryTypeFilter == typeKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategoryTypeFilter = typeKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : retro.cardColor,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : retro.borderColor,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: RetroTypography.pixelBadge(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 8.0,
          ),
        ),
      ),
    );
  }


  Widget _buildAllCategoriesView({
    required BuildContext context,
    required String query,
    required List<Song> matchingSongs,
    required List<Album> matchingAlbums,
    required List<Artist> matchingArtists,
    required List<Playlist> matchingPlaylists,
    required List<Song> librarySongs,
  }) {
    final retro = context.retro;

    // Empty query should never reach here now (handled by browse grid above)
    if (query.isEmpty) return const SizedBox.shrink();

    // When query is not empty, show categorized sections!
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // 1. Songs Section
        if (matchingSongs.isNotEmpty) ...[
          _buildSectionHeader(
            context: context,
            title: 'SONGS',
            iconName: 'music',
            count: matchingSongs.length,
            onSeeAll: () => setState(() => _selectedCategory = SearchCategory.songs),
          ),
          ...matchingSongs.take(4).map((song) {
            return RetroSongTile(
              song: song,
              queue: matchingSongs,
            );
          }),
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 1.5,
            color: retro.borderColor.withValues(alpha: 0.25),
          ),
        ],

        // 2. Albums Section
        if (matchingAlbums.isNotEmpty) ...[
          _buildSectionHeader(
            context: context,
            title: 'ALBUMS',
            iconName: 'disc',
            count: matchingAlbums.length,
            onSeeAll: () => setState(() => _selectedCategory = SearchCategory.albums),
          ),
          ...matchingAlbums.take(3).map((album) => _buildAlbumTile(context, album)),
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 1.5,
            color: retro.borderColor.withValues(alpha: 0.25),
          ),
        ],

        // 3. Artists Section
        if (matchingArtists.isNotEmpty) ...[
          _buildSectionHeader(
            context: context,
            title: 'ARTISTS',
            iconName: 'user',
            count: matchingArtists.length,
            onSeeAll: () => setState(() => _selectedCategory = SearchCategory.artists),
          ),
          ...matchingArtists.take(3).map((artist) => _buildArtistTile(context, artist)),
          Container(
            margin: const EdgeInsets.only(top: 8),
            height: 1.5,
            color: retro.borderColor.withValues(alpha: 0.25),
          ),
        ],

        // 4. Playlists Section
        if (matchingPlaylists.isNotEmpty) ...[
          _buildSectionHeader(
            context: context,
            title: 'PLAYLISTS',
            iconName: 'playlist',
            count: matchingPlaylists.length,
            onSeeAll: () => setState(() => _selectedCategory = SearchCategory.playlists),
          ),
          ...matchingPlaylists
              .take(3)
              .map((playlist) => _buildPlaylistTile(context, playlist, librarySongs)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required String iconName,
    required int count,
    required VoidCallback? onSeeAll,
  }) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: [
          RetroIcon(iconName, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            title,
            style: RetroTypography.pixelHeader(
              color: theme.colorScheme.onSurface,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(width: 6),
          RetroBadge(
            text: '$count',
            backgroundColor: retro.cardColor,
            textColor: theme.colorScheme.primary,
            fontSize: 7.5,
          ),
          const Spacer(),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border.all(color: retro.borderColor, width: 1.5),
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'SEE ALL',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.primary,
                        fontSize: 8.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    RetroIcon('chevron_right', size: 10, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSongsListView(List<Song> songs) {
    final retro = context.retro;
    if (songs.isEmpty) {
      return _buildEmptyCategoryState('NO SONGS FOUND');
    }
    return ListView.separated(
      itemCount: songs.length,
      separatorBuilder: (context, idx) =>
          Container(height: 1.5, color: retro.borderColor.withValues(alpha: 0.3)),
      itemBuilder: (context, index) {
        final song = songs[index];
        return RetroSongTile(
          song: song,
          index: index,
          queue: songs,
        );
      },
    );
  }

  Widget _buildAlbumsListView(BuildContext context, List<Album> albums) {
    if (albums.isEmpty) {
      return _buildEmptyCategoryState('NO ALBUMS FOUND');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: albums.length,
      itemBuilder: (context, index) => _buildAlbumTile(context, albums[index]),
    );
  }

  Widget _buildArtistsListView(BuildContext context, List<Artist> artists) {
    if (artists.isEmpty) {
      return _buildEmptyCategoryState('NO ARTISTS FOUND');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: artists.length,
      itemBuilder: (context, index) => _buildArtistTile(context, artists[index]),
    );
  }

  Widget _buildPlaylistsListView(
    BuildContext context,
    List<Playlist> playlists,
    List<Song> librarySongs,
  ) {
    if (playlists.isEmpty) {
      return _buildEmptyCategoryState('NO PLAYLISTS FOUND');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: playlists.length,
      itemBuilder: (context, index) =>
          _buildPlaylistTile(context, playlists[index], librarySongs),
    );
  }

  Widget _buildAlbumTile(BuildContext context, Album album) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: RetroCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onTap: () {
          setState(() {
            _selectedAlbum = album;
          });
        },
        child: Row(
          children: [
            RetroAlbumArt(
              artPath: album.effectiveArtPath,
              title: album.title,
              artist: album.artist,
              width: 44,
              height: 44,
              borderWidth: 1.5,
              borderColor: retro.borderColor,
              backgroundColor: retro.cardColor,
              placeholderIconSize: 20,
              placeholderColor: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    album.title,
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 10.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    album.artist,
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            RetroBadge(
              text: '${album.trackCount} TRACKS',
              backgroundColor: retro.cardColor,
              textColor: theme.colorScheme.onSurface,
              fontSize: 7.5,
            ),
            const SizedBox(width: 6),
            const RetroIcon('chevron_right', size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistTile(BuildContext context, Artist artist) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: RetroCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onTap: () {
          setState(() {
            _selectedArtist = artist;
          });
        },
        child: Row(
          children: [
            RetroAlbumArt(
              artPath: artist.artPath,
              title: artist.name,
              width: 44,
              height: 44,
              borderWidth: 1.5,
              borderColor: retro.borderColor,
              backgroundColor: retro.accentPurple,
              placeholderIconSize: 20,
              placeholderColor: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artist.name,
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${artist.trackCount} TRACKS • ${artist.albumCount} ALBUMS',
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const RetroIcon('chevron_right', size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistTile(
    BuildContext context,
    Playlist playlist,
    List<Song> librarySongs,
  ) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final validTracks = playlist.getValidSongCount(librarySongs);
    final artPath = playlist.resolveArtPath(librarySongs);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: RetroCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onTap: () {
          setState(() {
            _selectedPlaylist = playlist;
          });
        },
        child: Row(
          children: [
            RetroAlbumArt(
              artPath: artPath,
              title: playlist.name,
              width: 44,
              height: 44,
              borderWidth: context.isNothingTheme ? 0.0 : 1.5,
              borderColor: retro.borderColor,
              backgroundColor: retro.accentGreen,
              placeholderIconSize: 20,
              placeholderColor: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playlist.name.toUpperCase(),
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 10.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$validTracks TRACK${validTracks == 1 ? '' : 'S'}',
                    style: RetroTypography.retroMono(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const RetroIcon('chevron_right', size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCategoryState(String message) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RetroIcon('search', size: 32),
            const SizedBox(height: 10),
            Text(
              message,
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
