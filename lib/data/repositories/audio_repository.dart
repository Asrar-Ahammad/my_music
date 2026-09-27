import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/file_scanner_service.dart';
import '../services/storage_service.dart';
import '../../domain/models/song.dart';
import '../../domain/models/album.dart';
import '../../domain/models/artist.dart';

class AudioRepository {
  final FileScannerService _scannerService;
  final StorageService _storageService;

  List<Song> _allSongs = [];

  AudioRepository({
    FileScannerService? scannerService,
    StorageService? storageService,
  })  : _scannerService = scannerService ?? FileScannerService(),
        _storageService = storageService ?? StorageService();

  List<Song> get allSongs => List.unmodifiable(_allSongs);

  /// Load bundled tracks and scanned custom folders & files.
  /// [isUserInitiatedRefresh] = true triggers MediaStore rescan for newly added files.
  Future<List<Song>> loadLibrary({bool isUserInitiatedRefresh = false}) async {
    final favorites = _storageService.getFavorites();
    final songs = <Song>[];
    final seenPaths = <String>{};

    // 1. Bundled 8-bit tracks
    final bundled = _scannerService.getBundledSampleTracks(favoriteIds: favorites);
    for (final s in bundled) {
      if (!seenPaths.contains(s.uri)) {
        seenPaths.add(s.uri);
        songs.add(s);
      }
    }

    final userFolders = _storageService.getScanFolders();
    final fetchAll = _storageService.isFetchAllAudio();
    final shouldScanDevice = fetchAll || userFolders.isEmpty || isUserInitiatedRefresh;

    // 2a. On Android with user-refresh: trigger MediaScanner on standard paths
    //     so newly downloaded files are indexed before we query MediaStore.
    if (isUserInitiatedRefresh && !kIsWeb && Platform.isAndroid) {
      final standardPaths = [
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Audio',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Recordings',
      ];
      await FileScannerService.rescanMediaStorePaths(standardPaths);
    }

    // 2b. Query Android MediaStore for all indexed audio files (bypasses Scoped Storage)
    if (shouldScanDevice && !kIsWeb && Platform.isAndroid) {
      final folderPrefixes =
          userFolders.isNotEmpty && !fetchAll ? userFolders : <String>[];
      final mediaStorePaths = await FileScannerService.queryMediaStorePaths(
        folderPrefixes: folderPrefixes,
      );
      if (mediaStorePaths.isNotEmpty) {
        final mediaStoreSongs = await _scannerService.scanFilesWithCache(
          mediaStorePaths,
          favoriteIds: favorites,
        );
        for (final s in mediaStoreSongs) {
          if (!seenPaths.contains(s.uri)) {
            seenPaths.add(s.uri);
            songs.add(s);
          }
        }
      }
    }

    // 3. Scanned user-selected folders (covers non-Android / fallback)
    for (final folder in userFolders) {
      final scanned = await _scannerService.scanDirectory(folder, favoriteIds: favorites);
      for (final s in scanned) {
        if (!seenPaths.contains(s.uri)) {
          seenPaths.add(s.uri);
          songs.add(s);
        }
      }
    }

    // 4. User picked individual/multiple files
    final customFiles = _storageService.getCustomFilePaths();
    if (customFiles.isNotEmpty) {
      final scannedFiles = await _scannerService.scanFiles(customFiles, favoriteIds: favorites);
      for (final s in scannedFiles) {
        if (!seenPaths.contains(s.uri)) {
          seenPaths.add(s.uri);
          songs.add(s);
        }
      }
    }

    // 5. Device-wide filesystem scan for non-Android platforms or fetchAll without Android
    if (shouldScanDevice && (kIsWeb || !Platform.isAndroid)) {
      final allDeviceSongs =
          await _scannerService.scanDeviceStandardMusicDirs(favoriteIds: favorites);
      for (final s in allDeviceSongs) {
        if (!seenPaths.contains(s.uri)) {
          seenPaths.add(s.uri);
          songs.add(s);
        }
      }
    }

    _allSongs = songs;

    // Prune dead cache entries for files no longer on disk
    try {
      final currentUris = songs.where((s) => !s.isAsset).map((s) => s.uri).toSet();
      final cachedEntries = _storageService.getCachedSongEntries();
      final deadKeys = cachedEntries.keys.where((k) => !currentUris.contains(k)).toList();
      if (deadKeys.isNotEmpty) {
        await _storageService.removeCachedSongEntries(deadKeys);
      }
    } catch (_) {}

    return _allSongs;
  }

  /// Returns instantly available songs from persistent cache + bundled tracks
  List<Song> getCachedSongs() {
    final cachedMap = _storageService.getCachedSongEntries();
    // If no local storage songs are in the persistent cache, return empty list
    // so the app performs a proper initial scan with loading indicator instead
    // of pretending the full library is loaded with only bundled tracks.
    if (cachedMap.isEmpty) {
      return const [];
    }

    final favorites = _storageService.getFavorites();
    final songs = <Song>[];
    final seenPaths = <String>{};

    // 1. Bundled sample tracks
    final bundled = _scannerService.getBundledSampleTracks(favoriteIds: favorites);
    for (final s in bundled) {
      if (!seenPaths.contains(s.uri)) {
        seenPaths.add(s.uri);
        songs.add(s);
      }
    }

    // 2. Cached disk songs
    for (final entry in cachedMap.values) {
      if (entry['song'] is Map) {
        try {
          var s = Song.fromMap(Map<String, dynamic>.from(entry['song'] as Map));
          if (s.dateAdded == null && entry['mtime'] is int && (entry['mtime'] as int) > 0) {
            s = s.copyWith(dateAdded: DateTime.fromMillisecondsSinceEpoch(entry['mtime'] as int));
          }
          if (!seenPaths.contains(s.uri)) {
            seenPaths.add(s.uri);
            final isFav = favorites.contains(s.id);
            songs.add(s.copyWith(isFavorite: isFav));
          }
        } catch (_) {}
      }
    }

    if (songs.isNotEmpty) {
      _allSongs = songs;
    }
    return List.unmodifiable(_allSongs);
  }

  /// Rescan and return updated song count. Passes isUserInitiatedRefresh=true
  /// so MediaStore is queried and media scanner is triggered for new downloads.
  Future<int> rescanSelectedFolders() async {
    final songs = await loadLibrary(isUserInitiatedRefresh: true);
    return songs.length;
  }

  /// Kept for API compatibility
  Future<int> autoScanDevice() async {
    return rescanSelectedFolders();
  }

  /// Add custom picked files
  Future<void> addCustomAudioFiles(List<String> paths) async {
    await _storageService.addCustomFilePaths(paths);
    await loadLibrary();
  }

  /// Toggle song favorite status
  Future<bool> toggleFavorite(String songId) async {
    final favorites = _storageService.getFavorites();
    final isFav = favorites.contains(songId);

    if (isFav) {
      favorites.remove(songId);
    } else {
      favorites.add(songId);
    }

    await _storageService.saveFavorites(favorites);

    // Update internal in-memory list
    _allSongs = _allSongs.map((s) {
      if (s.id == songId) {
        return s.copyWith(isFavorite: !isFav);
      }
      return s;
    }).toList();

    return !isFav;
  }

  List<Song> getFavorites() {
    return _allSongs.where((s) => s.isFavorite).toList();
  }

  /// Group songs by album
  List<Album> getAlbums() => getAlbumsForSongs(_allSongs);

  /// Group any song list by album
  List<Album> getAlbumsForSongs(List<Song> songs) {
    final map = <String, List<Song>>{};
    for (final song in songs) {
      map.putIfAbsent(song.album, () => []).add(song);
    }

    return map.entries.map((e) {
      final songsInAlbum = e.value;
      final first = songsInAlbum.first;

      // 1. Search all songs in this album for the first valid artPath
      String? resolvedArt;
      for (final s in songsInAlbum) {
        if (s.artPath != null && s.artPath!.trim().isNotEmpty) {
          resolvedArt = s.artPath!.trim();
          break;
        }
      }

      // 2. If no song has embedded art, check directory cover image fallback
      if (resolvedArt == null) {
        for (final s in songsInAlbum) {
          if (!s.isAsset && s.folderPath.isNotEmpty) {
            final folderArt = FileScannerService.findFolderCoverImageSync(s.folderPath);
            if (folderArt != null && folderArt.isNotEmpty) {
              resolvedArt = folderArt;
              break;
            }
          }
        }
      }

      return Album(
        title: e.key,
        artist: first.artist,
        songs: songsInAlbum,
        artPath: resolvedArt,
      );
    }).toList();
  }

  /// Group songs by artist
  List<Artist> getArtists() => getArtistsForSongs(_allSongs);

  /// Group any song list by artist
  List<Artist> getArtistsForSongs(List<Song> songs) {
    final map = <String, List<Song>>{};
    for (final song in songs) {
      map.putIfAbsent(song.artist, () => []).add(song);
    }

    return map.entries.map((e) {
      return Artist(
        name: e.key,
        songs: e.value,
      );
    }).toList();
  }

  /// Group songs by folder
  Map<String, List<Song>> getFolders() => getFoldersForSongs(_allSongs);

  /// Group any song list by folder
  Map<String, List<Song>> getFoldersForSongs(List<Song> songs) {
    final map = <String, List<Song>>{};
    for (final song in songs) {
      final folder = song.folderPath.isNotEmpty ? song.folderPath : 'Internal / Bundled';
      map.putIfAbsent(folder, () => []).add(song);
    }
    return map;
  }
}
