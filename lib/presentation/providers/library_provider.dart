import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/permission_helper.dart';
import '../../data/repositories/audio_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/song.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';
import 'equalizer_provider.dart';
import 'player_provider.dart';
import 'playlist_provider.dart';

enum SongSortMode { title, artist, duration, format, date }

class LibraryState {
  final List<Song> allSongs;
  final List<Album> albums;
  final List<Artist> artists;
  final Map<String, List<Song>> folders;
  final bool isLoading;
  final String searchQuery;
  final SongSortMode sortMode;
  final bool sortAscending;

  final Map<String, bool>? explicitSongFavoriteMap;
  final List<Song>? explicitFilteredSongs;

  const LibraryState({
    this.allSongs = const [],
    this.albums = const [],
    this.artists = const [],
    this.folders = const {},
    this.isLoading = false,
    this.searchQuery = '',
    this.sortMode = SongSortMode.title,
    this.sortAscending = true,
    this.explicitSongFavoriteMap,
    this.explicitFilteredSongs,
  });

  /// O(1) favorite lookup per tile — built once and cached for the lifetime
  /// of this state instance.
  Map<String, bool> get songFavoriteMap =>
      explicitSongFavoriteMap ?? {for (final s in allSongs) s.id: s.isFavorite};

  /// Cached filtered + sorted view. Computed once per state instance so that
  /// the list is not re-created on every widget rebuild.
  List<Song> get filteredSongs =>
      explicitFilteredSongs ?? _computeFilteredSongs();

  List<Song> _computeFilteredSongs() {
    var list = List<Song>.from(allSongs);

    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      list = list.where((s) {
        return s.title.toLowerCase().contains(q) ||
            s.artist.toLowerCase().contains(q) ||
            s.album.toLowerCase().contains(q);
      }).toList();
    }

    list.sort((a, b) {
      int cmp = 0;
      switch (sortMode) {
        case SongSortMode.title:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case SongSortMode.artist:
          cmp = a.artist.toLowerCase().compareTo(b.artist.toLowerCase());
          break;
        case SongSortMode.duration:
          cmp = a.duration.compareTo(b.duration);
          break;
        case SongSortMode.format:
          cmp = a.quality.format.compareTo(b.quality.format);
          break;
        case SongSortMode.date:
          final aDate = a.dateAdded?.millisecondsSinceEpoch ?? 0;
          final bDate = b.dateAdded?.millisecondsSinceEpoch ?? 0;
          cmp = aDate.compareTo(bDate);
          if (cmp == 0) {
            cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          }
          break;
      }
      return sortAscending ? cmp : -cmp;
    });

    return list;
  }

  List<Song> get favoriteSongs => allSongs.where((s) => s.isFavorite).toList();

  LibraryState copyWith({
    List<Song>? allSongs,
    List<Album>? albums,
    List<Artist>? artists,
    Map<String, List<Song>>? folders,
    bool? isLoading,
    String? searchQuery,
    SongSortMode? sortMode,
    bool? sortAscending,
  }) {
    final newAllSongs = allSongs ?? this.allSongs;
    final newSearchQuery = searchQuery ?? this.searchQuery;
    final newSortMode = sortMode ?? this.sortMode;
    final newSortAscending = sortAscending ?? this.sortAscending;
    final songsChanged = allSongs != null;
    final filterChanged = songsChanged ||
        searchQuery != null ||
        sortMode != null ||
        sortAscending != null;

    final newFavoriteMap = songsChanged
        ? {for (final s in newAllSongs) s.id: s.isFavorite}
        : explicitSongFavoriteMap;

    return LibraryState(
      allSongs: newAllSongs,
      albums: albums ?? this.albums,
      artists: artists ?? this.artists,
      folders: folders ?? this.folders,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: newSearchQuery,
      sortMode: newSortMode,
      sortAscending: newSortAscending,
      explicitSongFavoriteMap: newFavoriteMap,
      explicitFilteredSongs: filterChanged ? null : explicitFilteredSongs,
    );
  }
}

class LibraryNotifier extends Notifier<LibraryState> {
  AudioRepository get _audioRepository => ref.read(audioRepositoryProvider);

  @override
  LibraryState build() {
    final cachedSongs = _audioRepository.getCachedSongs();
    if (cachedSongs.isNotEmpty) {
      final albums = _audioRepository.getAlbumsForSongs(cachedSongs);
      final artists = _audioRepository.getArtistsForSongs(cachedSongs);
      final folders = _audioRepository.getFoldersForSongs(cachedSongs);
      Future.microtask(() => _silentRefreshLibrary());
      return LibraryState(
        allSongs: cachedSongs,
        albums: albums,
        artists: artists,
        folders: folders,
        isLoading: false,
        explicitSongFavoriteMap: {for (final s in cachedSongs) s.id: s.isFavorite},
      );
    }

    Future.microtask(() => loadLibrary());
    return const LibraryState(isLoading: true);
  }

  Future<void> _silentRefreshLibrary() async {
    final songs = await _audioRepository.loadLibrary();
    final albums = _audioRepository.getAlbums();
    final artists = _audioRepository.getArtists();
    final folders = _audioRepository.getFolders();

    state = state.copyWith(
      allSongs: songs,
      albums: albums,
      artists: artists,
      folders: folders,
      isLoading: false,
    );

    try {
      ref.read(playlistProvider.notifier).syncWithLibrary(songs);
    } catch (_) {}
  }

  Future<void> loadLibrary() async {
    state = state.copyWith(isLoading: true);
    final songs = await _audioRepository.loadLibrary();
    final albums = _audioRepository.getAlbums();
    final artists = _audioRepository.getArtists();
    final folders = _audioRepository.getFolders();

    state = state.copyWith(
      allSongs: songs,
      albums: albums,
      artists: artists,
      folders: folders,
      isLoading: false,
    );

    try {
      ref.read(playlistProvider.notifier).syncWithLibrary(songs);
    } catch (_) {}
  }

  Future<void> toggleFavorite(String songId) async {
    final isFav = await _audioRepository.toggleFavorite(songId);
    final updatedSongs = _audioRepository.allSongs;
    final albums = _audioRepository.getAlbums();
    final artists = _audioRepository.getArtists();

    state = state.copyWith(
      allSongs: updatedSongs,
      albums: albums,
      artists: artists,
    );

    // Synchronize PlayerNotifier currentSong and queue
    ref.read(playerProvider.notifier).updateSongFavorite(songId, isFav);

  }

  /// Perform a full library rescan, requesting permissions if needed.
  /// Returns a record with [totalCount] and [newCount] (songs newly discovered).
  Future<({int totalCount, int newCount})> rescanLibrary() async {
    final previousIds = state.allSongs.map((s) => s.id).toSet();

    // Request storage/audio permission before scanning
    try {
      await PermissionHelper.requestStoragePermission();
    } catch (_) {}

    state = state.copyWith(isLoading: true);
    final songs = await _audioRepository.loadLibrary(isUserInitiatedRefresh: true);
    final albums = _audioRepository.getAlbums();
    final artists = _audioRepository.getArtists();
    final folders = _audioRepository.getFolders();

    state = state.copyWith(
      allSongs: songs,
      albums: albums,
      artists: artists,
      folders: folders,
      isLoading: false,
    );

    try {
      ref.read(playlistProvider.notifier).syncWithLibrary(songs);
    } catch (_) {}

    final newCount = songs.where((s) => !previousIds.contains(s.id)).length;
    return (totalCount: songs.length, newCount: newCount);
  }

  Future<int> rescanSelectedFolders() async {
    final result = await rescanLibrary();
    return result.totalCount;
  }

  /// Kept for backward compatibility: strictly rescans only selected folders
  Future<int> autoScanDevice() async {
    return rescanSelectedFolders();
  }

  Future<void> addCustomAudioFiles(List<String> paths) async {
    state = state.copyWith(isLoading: true);
    await _audioRepository.addCustomAudioFiles(paths);
    final albums = _audioRepository.getAlbums();
    final artists = _audioRepository.getArtists();
    final folders = _audioRepository.getFolders();

    state = state.copyWith(
      allSongs: _audioRepository.allSongs,
      albums: albums,
      artists: artists,
      folders: folders,
      isLoading: false,
    );

    try {
      ref.read(playlistProvider.notifier).syncWithLibrary(_audioRepository.allSongs);
    } catch (_) {}
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortMode(SongSortMode mode) {
    if (state.sortMode == mode) {
      state = state.copyWith(sortAscending: !state.sortAscending);
    } else {
      state = state.copyWith(
        sortMode: mode,
        sortAscending: mode == SongSortMode.date ? false : true,
      );
    }
  }

  void toggleSortDirection() {
    state = state.copyWith(sortAscending: !state.sortAscending);
  }

  void setSortAscending(bool ascending) {
    state = state.copyWith(sortAscending: ascending);
  }
}

final audioRepositoryProvider = Provider<AudioRepository>((ref) {
  return AudioRepository();
});

final libraryProvider = NotifierProvider<LibraryNotifier, LibraryState>(LibraryNotifier.new);

class AlbumViewModeNotifier extends Notifier<bool> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  bool build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.isAlbumGridView();
  }

  Future<void> toggleViewMode() async {
    state = !state;
    await _repository.setAlbumGridView(state);
  }

  Future<void> setGridView(bool isGrid) async {
    state = isGrid;
    await _repository.setAlbumGridView(isGrid);
  }
}

final albumViewModeProvider =
    NotifierProvider<AlbumViewModeNotifier, bool>(AlbumViewModeNotifier.new);

class ArtistViewModeNotifier extends Notifier<bool> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  bool build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.isArtistGridView();
  }

  Future<void> toggleViewMode() async {
    state = !state;
    await _repository.setArtistGridView(state);
  }

  Future<void> setGridView(bool isGrid) async {
    state = isGrid;
    await _repository.setArtistGridView(isGrid);
  }
}

final artistViewModeProvider =
    NotifierProvider<ArtistViewModeNotifier, bool>(ArtistViewModeNotifier.new);

// ── Tab Search & Sort Providers ──────────────────────────────────────────────
class TabStringNotifier extends Notifier<String> {
  final String _initial;
  TabStringNotifier(this._initial);

  @override
  String build() => _initial;

  @override
  String get state => super.state;

  @override
  set state(String value) => super.state = value;

  void set(String value) => super.state = value;
}

class TabBoolNotifier extends Notifier<bool> {
  final bool _initial;
  TabBoolNotifier(this._initial);

  @override
  bool build() => _initial;

  @override
  bool get state => super.state;

  @override
  set state(bool value) => super.state = value;

  void set(bool value) => super.state = value;
  void toggle() => super.state = !super.state;
}

final albumSearchProvider =
    NotifierProvider<TabStringNotifier, String>(() => TabStringNotifier(''));
final albumSortModeProvider =
    NotifierProvider<TabStringNotifier, String>(() => TabStringNotifier('title'));
final albumSortAscendingProvider =
    NotifierProvider<TabBoolNotifier, bool>(() => TabBoolNotifier(true));

final artistSearchProvider =
    NotifierProvider<TabStringNotifier, String>(() => TabStringNotifier(''));
final artistSortModeProvider =
    NotifierProvider<TabStringNotifier, String>(() => TabStringNotifier('name'));
final artistSortAscendingProvider =
    NotifierProvider<TabBoolNotifier, bool>(() => TabBoolNotifier(true));

final folderSearchProvider =
    NotifierProvider<TabStringNotifier, String>(() => TabStringNotifier(''));
final folderSortModeProvider =
    NotifierProvider<TabStringNotifier, String>(() => TabStringNotifier('name'));
final folderSortAscendingProvider =
    NotifierProvider<TabBoolNotifier, bool>(() => TabBoolNotifier(true));

class SongSelectionState {
  final bool isSelecting;
  final Set<String> selectedIds;

  const SongSelectionState({
    this.isSelecting = false,
    this.selectedIds = const {},
  });

  SongSelectionState copyWith({
    bool? isSelecting,
    Set<String>? selectedIds,
  }) {
    return SongSelectionState(
      isSelecting: isSelecting ?? this.isSelecting,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class SongSelectionNotifier extends Notifier<SongSelectionState> {
  @override
  SongSelectionState build() => const SongSelectionState();

  void enterSelectionMode(String firstId) {
    state = SongSelectionState(isSelecting: true, selectedIds: {firstId});
  }

  void exitSelectionMode() {
    state = const SongSelectionState();
  }

  void toggleSong(String id) {
    final next = Set<String>.from(state.selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(List<String> allIds) {
    state = state.copyWith(selectedIds: allIds.toSet());
  }

  void clearSelection() {
    state = state.copyWith(selectedIds: {});
  }
}

final songSelectionProvider =
    NotifierProvider<SongSelectionNotifier, SongSelectionState>(SongSelectionNotifier.new);
