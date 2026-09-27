import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/playlist.dart';

class PlaylistNavigationTarget {
  final Playlist playlist;
  final bool isFavorites;

  const PlaylistNavigationTarget({
    required this.playlist,
    this.isFavorites = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaylistNavigationTarget &&
          runtimeType == other.runtimeType &&
          playlist.id == other.playlist.id &&
          isFavorites == other.isFavorites;

  @override
  int get hashCode => playlist.id.hashCode ^ isFavorites.hashCode;
}

class OpenPlaylistRequestNotifier extends Notifier<PlaylistNavigationTarget?> {
  @override
  PlaylistNavigationTarget? build() => null;

  void request(PlaylistNavigationTarget target) {
    state = target;
  }

  void clear() {
    state = null;
  }
}

final openPlaylistRequestProvider =
    NotifierProvider<OpenPlaylistRequestNotifier, PlaylistNavigationTarget?>(
  OpenPlaylistRequestNotifier.new,
);

class LibraryTabTarget {
  final int tabIndex; // 1 for Albums, 2 for Artists
  final String? filterQuery;

  const LibraryTabTarget({
    required this.tabIndex,
    this.filterQuery,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LibraryTabTarget &&
          runtimeType == other.runtimeType &&
          tabIndex == other.tabIndex &&
          filterQuery == other.filterQuery;

  @override
  int get hashCode => tabIndex.hashCode ^ (filterQuery?.hashCode ?? 0);
}

class LibraryTabRequestNotifier extends Notifier<LibraryTabTarget?> {
  @override
  LibraryTabTarget? build() => null;

  void request(LibraryTabTarget target) {
    state = target;
  }

  void clear() {
    state = null;
  }
}

final libraryTabRequestProvider =
    NotifierProvider<LibraryTabRequestNotifier, LibraryTabTarget?>(
  LibraryTabRequestNotifier.new,
);

class HomeNavigationNotifier extends Notifier<int> {
  final List<int> _tabHistory = [0];

  @override
  int build() {
    _tabHistory.clear();
    _tabHistory.add(0);
    return 0;
  }

  List<int> get tabHistory => List.unmodifiable(_tabHistory);

  void setTab(int index) {
    if (state == index) return;
    if (index == 0) {
      _tabHistory.clear();
      _tabHistory.add(0);
    } else {
      _tabHistory.add(index);
    }
    state = index;
  }

  bool canPopTab() {
    return state != 0;
  }

  bool popTab() {
    while (_tabHistory.isNotEmpty && _tabHistory.last == state) {
      _tabHistory.removeLast();
    }

    if (_tabHistory.isNotEmpty) {
      final previousTab = _tabHistory.removeLast();
      state = previousTab;
      return true;
    } else if (state != 0) {
      state = 0;
      return true;
    }
    return false;
  }

  void openPlaylist(Playlist playlist, {bool isFavorites = false}) {
    ref.read(openPlaylistRequestProvider.notifier).request(
      PlaylistNavigationTarget(
        playlist: playlist,
        isFavorites: isFavorites,
      ),
    );
    setTab(1); // Tab 1: Playlists
  }

  void openAlbum(String albumName) {
    ref.read(libraryTabRequestProvider.notifier).request(
      LibraryTabTarget(
        tabIndex: 1, // Tab 1: Albums
        filterQuery: albumName,
      ),
    );
    setTab(0); // Tab 0: Library
  }

  void openArtist(String artistName) {
    ref.read(libraryTabRequestProvider.notifier).request(
      LibraryTabTarget(
        tabIndex: 2, // Tab 2: Artists
        filterQuery: artistName,
      ),
    );
    setTab(0); // Tab 0: Library
  }
}

final homeTabProvider = NotifierProvider<HomeNavigationNotifier, int>(
  HomeNavigationNotifier.new,
);
