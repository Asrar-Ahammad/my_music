import '../services/storage_service.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';

class PlaylistRepository {
  final StorageService _storageService;
  List<Playlist> _playlists = [];

  PlaylistRepository({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  Future<List<Playlist>> loadPlaylists() async {
    _playlists = _storageService.getPlaylists();
    return _playlists;
  }

  Future<Playlist> createPlaylist(String name, {String? customArtPath}) async {
    final newPlaylist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      songIds: [],
      createdAt: DateTime.now(),
      customArtPath: customArtPath,
    );
    _playlists.add(newPlaylist);
    await _storageService.savePlaylists(_playlists);
    return newPlaylist;
  }

  Future<void> deletePlaylist(String playlistId) async {
    _playlists.removeWhere((p) => p.id == playlistId);
    await _storageService.savePlaylists(_playlists);
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index] = _playlists[index].copyWith(name: newName);
      await _storageService.savePlaylists(_playlists);
    }
  }

  Future<void> updatePlaylistCover(String playlistId, String? customArtPath) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index] = _playlists[index].copyWith(
        customArtPath: customArtPath,
        clearCustomArt: customArtPath == null,
      );
      await _storageService.savePlaylists(_playlists);
    }
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final currentSongs = List<String>.from(_playlists[index].songIds);
      if (!currentSongs.contains(songId)) {
        currentSongs.add(songId);
        _playlists[index] = _playlists[index].copyWith(songIds: currentSongs);
        await _storageService.savePlaylists(_playlists);
      }
    }
  }

  /// Adds multiple songs at once with a single persistence write.
  Future<void> addSongsToPlaylist(String playlistId, List<String> songIds) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final currentSongs = List<String>.from(_playlists[index].songIds);
      var changed = false;
      for (final id in songIds) {
        if (!currentSongs.contains(id)) {
          currentSongs.add(id);
          changed = true;
        }
      }
      if (changed) {
        _playlists[index] = _playlists[index].copyWith(songIds: currentSongs);
        await _storageService.savePlaylists(_playlists);
      }
    }
  }


  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      final currentSongs = List<String>.from(_playlists[index].songIds);
      currentSongs.remove(songId);
      _playlists[index] = _playlists[index].copyWith(songIds: currentSongs);
      await _storageService.savePlaylists(_playlists);
    }
  }

  List<Song> getSongsForPlaylist(Playlist playlist, List<Song> allSongs) {
    final idMap = <String, Song>{};
    final uriMap = <String, Song>{};
    final baseMap = <String, Song>{};

    for (final s in allSongs) {
      idMap[s.id] = s;
      uriMap[s.uri] = s;
      final base = s.uri.split('/').last.split('\\').last;
      if (base.isNotEmpty) {
        baseMap[base] = s;
      }
    }

    final result = <Song>[];
    for (final id in playlist.songIds) {
      final match = idMap[id] ?? uriMap[id] ?? baseMap[id];
      if (match != null) {
        result.add(match);
      } else {
        Song? found;
        for (final s in allSongs) {
          if (s.uri == id || s.id == id || s.uri.endsWith(id) || id.endsWith(s.uri)) {
            found = s;
            break;
          }
        }
        if (found != null) {
          result.add(found);
        }
      }
    }
    return result;
  }

  /// Prunes song IDs that no longer exist in [allSongs] from all playlists,
  /// persisting any changes.
  Future<bool> syncWithLibrary(List<Song> allSongs) async {
    if (allSongs.isEmpty) return false;
    // CRITICAL: Do NOT prune user playlists if allSongs only contains bundled sample tracks!
    if (allSongs.every((s) => s.isAsset)) return false;

    final validSongIds = allSongs.map((s) => s.id).toSet();
    final validUris = allSongs.map((s) => s.uri).toSet();

    var changed = false;
    final updatedPlaylists = <Playlist>[];
    for (final pl in _playlists) {
      final filteredIds = pl.songIds.where((id) =>
        validSongIds.contains(id) ||
        validUris.contains(id) ||
        allSongs.any((s) => s.uri.endsWith(id) || id.endsWith(s.uri))
      ).toList();

      if (filteredIds.length != pl.songIds.length) {
        changed = true;
        updatedPlaylists.add(pl.copyWith(songIds: filteredIds));
      } else {
        updatedPlaylists.add(pl);
      }
    }
    if (changed) {
      _playlists = updatedPlaylists;
      await _storageService.savePlaylists(_playlists);
    }
    return changed;
  }
}
