import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';
import 'equalizer_provider.dart';
import 'library_provider.dart';
import 'recently_played_provider.dart';

class PlaylistState {
  final List<Playlist> playlists;
  final bool isLoading;

  const PlaylistState({
    this.playlists = const [],
    this.isLoading = false,
  });

  PlaylistState copyWith({
    List<Playlist>? playlists,
    bool? isLoading,
  }) {
    return PlaylistState(
      playlists: playlists ?? this.playlists,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PlaylistNotifier extends Notifier<PlaylistState> {
  PlaylistRepository get _repository => ref.read(playlistRepositoryProvider);

  @override
  PlaylistState build() {
    Future.microtask(() => loadPlaylists());
    return const PlaylistState(isLoading: true);
  }

  Future<void> loadPlaylists() async {
    state = state.copyWith(isLoading: true);
    final list = await _repository.loadPlaylists();
    state = state.copyWith(playlists: list, isLoading: false);

    try {
      final libState = ref.read(libraryProvider);
      if (!libState.isLoading && libState.allSongs.isNotEmpty) {
        await syncWithLibrary(libState.allSongs);
      }
    } catch (_) {}
  }

  /// Synchronize playlist song IDs with available library songs,
  /// removing any song IDs that were deleted from storage.
  Future<void> syncWithLibrary(List<Song> allSongs) async {
    if (allSongs.isEmpty) return;
    final changed = await _repository.syncWithLibrary(allSongs);
    if (changed) {
      state = state.copyWith(playlists: _repository.playlists);
    }
  }

  Future<Playlist> createPlaylist(String name, {String? customArtPath}) async {
    final pl = await _repository.createPlaylist(name, customArtPath: customArtPath);
    state = state.copyWith(playlists: _repository.playlists);
    return pl;
  }

  Future<void> updatePlaylistCover(String playlistId, String? customArtPath) async {
    await _repository.updatePlaylistCover(playlistId, customArtPath);
    state = state.copyWith(playlists: _repository.playlists);
  }

  Future<void> deletePlaylist(String playlistId) async {
    final playlist = _repository.playlists.where((p) => p.id == playlistId).firstOrNull;
    await _repository.deletePlaylist(playlistId);
    state = state.copyWith(playlists: _repository.playlists);
    try {
      ref.read(recentlyPlayedProvider.notifier).removePlaylist(playlistId, playlist?.name);
    } catch (_) {}
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    await _repository.renamePlaylist(playlistId, newName);
    state = state.copyWith(playlists: _repository.playlists);
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    await _repository.addSongToPlaylist(playlistId, songId);
    state = state.copyWith(playlists: _repository.playlists);
  }

  Future<void> addSongsToPlaylist(String playlistId, List<String> songIds) async {
    await _repository.addSongsToPlaylist(playlistId, songIds);
    state = state.copyWith(playlists: _repository.playlists);
  }


  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    await _repository.removeSongFromPlaylist(playlistId, songId);
    state = state.copyWith(playlists: _repository.playlists);
  }
}

final playlistRepositoryProvider = Provider<PlaylistRepository>((ref) {
  return PlaylistRepository();
});

final playlistProvider = NotifierProvider<PlaylistNotifier, PlaylistState>(PlaylistNotifier.new);

class PlaylistViewModeNotifier extends Notifier<bool> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  bool build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.isPlaylistGridView();
  }

  Future<void> toggleViewMode() async {
    state = !state;
    await _repository.setPlaylistGridView(state);
  }

  Future<void> setGridView(bool isGrid) async {
    state = isGrid;
    await _repository.setPlaylistGridView(isGrid);
  }
}

final playlistViewModeProvider = NotifierProvider<PlaylistViewModeNotifier, bool>(PlaylistViewModeNotifier.new);
