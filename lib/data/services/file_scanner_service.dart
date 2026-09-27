import 'dart:io';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/audio_info_parser.dart';
import '../../domain/models/audio_quality.dart';
import '../../domain/models/song.dart';
import 'storage_service.dart';

class FileScannerService {
  final StorageService _storageService;

  FileScannerService({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  static const List<String> supportedExtensions = [
    '.mp3',
    '.flac',
    '.wav',
    '.aac',
    '.m4a',
    '.ogg',
    '.opus',
    '.wma',
    '.m4b',
    '.mp4',
    '.3gp',
    '.amr',
    '.ac3',
    '.eac3',
    '.ec3',
  ];

  static const MethodChannel _mediaStoreChannel =
      MethodChannel('com.retro.mymusic/media_store');

  static String? _cachedCoversDir;
  static final Map<String, String?> _folderCoverCache = {};

  static Future<String> getCoversDirectoryPath() async {
    if (_cachedCoversDir != null) return _cachedCoversDir!;
    try {
      final appDir = await getApplicationSupportDirectory();
      final coversDir = Directory(p.join(appDir.path, 'album_covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }
      _cachedCoversDir = coversDir.path;
      return _cachedCoversDir!;
    } catch (_) {
      final tempDir = Directory.systemTemp.createTempSync('myMusic_covers_');
      _cachedCoversDir = tempDir.path;
      return _cachedCoversDir!;
    }
  }

  static const List<String> folderCoverNames = [
    'cover.jpg',
    'Cover.jpg',
    'COVER.JPG',
    'cover.png',
    'Cover.png',
    'COVER.PNG',
    'cover.jpeg',
    'Cover.jpeg',
    'cover.webp',
    'folder.jpg',
    'Folder.jpg',
    'FOLDER.JPG',
    'folder.png',
    'Folder.png',
    'FOLDER.PNG',
    'folder.jpeg',
    'album.jpg',
    'Album.jpg',
    'ALBUM.JPG',
    'album.png',
    'Album.png',
    'album.jpeg',
    'albumart.jpg',
    'AlbumArt.jpg',
    'albumart.png',
    'front.jpg',
    'Front.jpg',
    'FRONT.JPG',
    'front.png',
    'artwork.jpg',
    'Artwork.jpg',
    'art.jpg',
    'Art.jpg',
  ];

  /// Synchronously find cover image in directory using cache and direct file checks
  static String? findFolderCoverImageSync(String dirPath) {
    if (dirPath.isEmpty) return null;
    if (_folderCoverCache.containsKey(dirPath)) {
      return _folderCoverCache[dirPath];
    }

    try {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) {
        _folderCoverCache[dirPath] = null;
        return null;
      }

      for (final name in folderCoverNames) {
        final f = File(p.join(dirPath, name));
        if (f.existsSync()) {
          _folderCoverCache[dirPath] = f.path;
          return f.path;
        }
      }

      try {
        final entities = dir.listSync(followLinks: false);
        for (final entity in entities) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) {
              _folderCoverCache[dirPath] = entity.path;
              return entity.path;
            }
          }
        }
      } catch (_) {}
    } catch (_) {}

    _folderCoverCache[dirPath] = null;
    return null;
  }

  static Future<String?> findFolderCoverImage(String dirPath) async {
    return findFolderCoverImageSync(dirPath);
  }

  /// Normalize Android SAF URI or raw path to real POSIX directory path
  static String normalizeFolderPath(String rawPath) {
    var path = Uri.decodeComponent(rawPath).trim();

    if (path.startsWith('content://')) {
      if (path.contains('/tree/')) {
        path = path.split('/tree/').last;
      } else if (path.contains('/document/')) {
        path = path.split('/document/').last;
      }
    }

    if (path.startsWith('/tree/')) {
      path = path.substring(6);
    } else if (path.startsWith('/document/')) {
      path = path.substring(10);
    }

    // Handle 'raw:' prefix (Android SAF Downloads URIs)
    if (path.startsWith('raw:')) {
      path = path.substring(4);
    }

    if (path.startsWith('primary:')) {
      final sub = path.substring(8);
      path = '/storage/emulated/0/$sub';
    } else if (path.contains(':') && !path.startsWith('/')) {
      final parts = path.split(':');
      if (parts.length == 2) {
        path = '/storage/${parts[0]}/${parts[1]}';
      }
    }

    while (path.endsWith('/') && path.length > 1) {
      path = path.substring(0, path.length - 1);
    }

    return path;
  }

  /// Query all audio files from Android MediaStore (bypasses Scoped Storage restrictions).
  /// Returns list of file paths visible to the MediaStore content provider.
  /// [folderPrefixes] optionally filters results to only paths under those directories.
  static Future<List<String>> queryMediaStorePaths({List<String>? folderPrefixes}) async {
    if (kIsWeb || !Platform.isAndroid) return [];
    try {
      final raw = await _mediaStoreChannel.invokeMethod<List<dynamic>>(
        'queryAudioFiles',
        {'folderPrefixes': folderPrefixes ?? <String>[]},
      );
      if (raw == null) return [];
      return raw
          .whereType<Map>()
          .map((e) => (e['path'] as String?) ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Trigger Android MediaScannerConnection on specified paths so that
  /// recently downloaded files are immediately indexed in MediaStore.
  static Future<void> rescanMediaStorePaths(List<String> paths) async {
    if (kIsWeb || !Platform.isAndroid || paths.isEmpty) return;
    try {
      await _mediaStoreChannel.invokeMethod<void>(
        'rescanPaths',
        {'paths': paths},
      );
    } catch (_) {}
  }

  /// Get initial bundled tracks
  List<Song> getBundledSampleTracks({Set<String>? favoriteIds}) {
    return AppConstants.sampleTracks.map((raw) {
      final id = raw['id']!;
      final assetPath = raw['assetPath']!;
      final sampleRate = int.tryParse(raw['sampleRate'] ?? '44100') ?? 44100;
      final bitDepth = int.tryParse(raw['bitDepth'] ?? '16') ?? 16;
      final format = raw['format'] ?? 'WAV';
      final sec = int.tryParse(raw['durationSec'] ?? '15') ?? 15;

      return Song(
        id: id,
        title: raw['title']!,
        artist: raw['artist']!,
        album: raw['album']!,
        duration: Duration(seconds: sec),
        uri: assetPath,
        isAsset: true,
        artPath: raw['artAsset'],
        quality: AudioQuality(
          format: format,
          bitDepth: bitDepth,
          sampleRate: sampleRate,
          bitrateKbps: bitDepth == 24 ? 4608 : 1411,
        ),
        isFavorite: favoriteIds?.contains(id) ?? false,
        folderPath: 'assets/audio',
        dateAdded: DateTime.fromMillisecondsSinceEpoch(1000),
      );
    }).toList();
  }

  /// Scan a single audio file
  Future<Song?> scanSingleFile(String filePath, {Set<String>? favoriteIds}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final ext = p.extension(filePath).toLowerCase();
      if (!supportedExtensions.contains(ext)) return null;

      final fileNameWithoutExt = p.basenameWithoutExtension(filePath);
      final parentFolder = p.basename(p.dirname(filePath));

      String title = fileNameWithoutExt;
      String artist = 'Unknown Artist';
      String album = parentFolder.isNotEmpty ? parentFolder : 'Local Music';
      Duration duration = const Duration(minutes: 3);
      String? artPath;

      if (fileNameWithoutExt.contains(' - ')) {
        final parts = fileNameWithoutExt.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }

      // Check if cover artwork file already exists for this file
      final coversDirPath = await getCoversDirectoryPath();
      final hash = filePath.hashCode;
      String? existingCoverPath;
      for (final ext in ['jpg', 'png', 'webp', 'jpeg']) {
        final cand = p.join(coversDirPath, 'art_$hash.$ext');
        if (File(cand).existsSync()) {
          existingCoverPath = cand;
          break;
        }
      }

      if (existingCoverPath != null) {
        artPath = existingCoverPath;
      }

      // 1. Try reading real metadata via audio_metadata_reader
      // Only extract image bytes if we don't already have an artwork file on disk!
      int? metaBitrate;
      int? metaSampleRate;
      try {
        final meta = readMetadata(file, getImage: existingCoverPath == null);
        metaBitrate = meta.bitrate;
        metaSampleRate = meta.sampleRate;
        if (meta.title != null && meta.title!.trim().isNotEmpty) {
          title = meta.title!.trim();
        }
        if (meta.artist != null && meta.artist!.trim().isNotEmpty) {
          artist = meta.artist!.trim();
        }
        if (meta.album != null && meta.album!.trim().isNotEmpty) {
          album = meta.album!.trim();
        }
        if (meta.duration != null && meta.duration! > Duration.zero) {
          duration = meta.duration!;
        }

        // Check for embedded artwork if not already cached
        if (existingCoverPath == null && meta.pictures.isNotEmpty) {
          Picture? coverPic;
          for (final pic in meta.pictures) {
            if (pic.pictureType == PictureType.coverFront) {
              coverPic = pic;
              break;
            }
          }
          coverPic ??= meta.pictures.first;

          if (coverPic.bytes.isNotEmpty) {
            String imgExt = 'jpg';
            final mime = coverPic.mimetype.toLowerCase();
            if (mime.contains('png')) {
              imgExt = 'png';
            } else if (mime.contains('webp')) {
              imgExt = 'webp';
            }

            final coverPath = p.join(coversDirPath, 'art_$hash.$imgExt');
            final coverFile = File(coverPath);
            if (!await coverFile.exists()) {
              await coverFile.writeAsBytes(coverPic.bytes);
            }
            artPath = coverPath;
          }
        }
      } catch (metaErr) {
        debugPrint('audio_metadata_reader note for $filePath: $metaErr');
      }

      // 2. If no embedded artwork found, check directory for cover image files
      artPath ??= await findFolderCoverImage(p.dirname(filePath));

      final quality = await AudioInfoParser.parseFileQuality(
        filePath,
        parsedBitrate: metaBitrate,
        parsedSampleRate: metaSampleRate,
        duration: duration,
      );

      DateTime? dateAdded;
      try {
        dateAdded = file.statSync().modified;
      } catch (_) {}

      return Song(
        id: 'file_${filePath.hashCode}',
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        uri: filePath,
        isAsset: false,
        artPath: artPath,
        quality: quality,
        isFavorite: favoriteIds?.contains('file_${filePath.hashCode}') ?? false,
        folderPath: p.dirname(filePath),
        dateAdded: dateAdded,
      );
    } catch (_) {
      return null;
    }
  }

  /// High-performance scanning with incremental cache validation & parallel batching
  Future<List<Song>> scanFilesWithCache(
    List<String> filePaths, {
    Set<String>? favoriteIds,
    Map<String, Map<String, dynamic>>? preloadedCache,
  }) async {
    if (filePaths.isEmpty) return [];

    final cache = preloadedCache ?? _storageService.getCachedSongEntries();
    final songs = <Song>[];
    final filesToScan = <String>[];
    final newEntriesToSave = <String, Map<String, dynamic>>{};

    for (final path in filePaths) {
      final cached = cache[path];
      if (cached != null && cached['song'] is Map) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            final stat = file.statSync();
            final mtime = stat.modified.millisecondsSinceEpoch;
            final size = stat.size;
            if (cached['mtime'] == mtime && cached['size'] == size) {
              var song = Song.fromMap(Map<String, dynamic>.from(cached['song'] as Map));
              if (song.dateAdded == null && mtime > 0) {
                song = song.copyWith(dateAdded: DateTime.fromMillisecondsSinceEpoch(mtime));
              }
              final isFav = favoriteIds?.contains(song.id) ?? song.isFavorite;
              songs.add(song.copyWith(isFavorite: isFav));
              continue;
            }
          }
        } catch (_) {}
      }
      filesToScan.add(path);
    }

    // Process uncached / modified files concurrently in batches of 16
    if (filesToScan.isNotEmpty) {
      const batchSize = 16;
      for (var i = 0; i < filesToScan.length; i += batchSize) {
        final end = (i + batchSize < filesToScan.length) ? i + batchSize : filesToScan.length;
        final chunk = filesToScan.sublist(i, end);

        final parsedChunk = await Future.wait(chunk.map((filePath) async {
          final song = await scanSingleFile(filePath, favoriteIds: favoriteIds);
          if (song != null) {
            try {
              final stat = File(filePath).statSync();
              return (
                song: song,
                path: filePath,
                mtime: stat.modified.millisecondsSinceEpoch,
                size: stat.size,
              );
            } catch (_) {
              return (
                song: song,
                path: filePath,
                mtime: 0,
                size: 0,
              );
            }
          }
          return null;
        }));

        for (final item in parsedChunk) {
          if (item != null) {
            songs.add(item.song);
            newEntriesToSave[item.path] = {
              'song': item.song.toMap(),
              'mtime': item.mtime,
              'size': item.size,
            };
          }
        }
      }

      if (newEntriesToSave.isNotEmpty) {
        await _storageService.saveCachedSongEntries(newEntriesToSave);
      }
    }

    return songs;
  }

  /// Scan a list of specific audio files
  Future<List<Song>> scanFiles(List<String> filePaths, {Set<String>? favoriteIds}) async {
    return scanFilesWithCache(filePaths, favoriteIds: favoriteIds);
  }

  /// Scan a directory recursively for audio files (asynchronous & non-blocking)
  Future<List<Song>> scanDirectory(String rawDirPath, {Set<String>? favoriteIds}) async {
    final normalized = normalizeFolderPath(rawDirPath);

    try {
      final dir = Directory(normalized);
      if (!await dir.exists()) return [];

      final audioFilePaths = <String>[];
      final seenPaths = <String>{};

      try {
        await for (final entity in dir.list(recursive: true, followLinks: false).handleError((e) {
          debugPrint('Directory entity scan error: $e');
        })) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (supportedExtensions.contains(ext) && !seenPaths.contains(entity.path)) {
              seenPaths.add(entity.path);
              audioFilePaths.add(entity.path);
            }
          }
        }
      } catch (listErr) {
        // Fallback to sync list if stream fails
        try {
          final entities = dir.listSync(recursive: true, followLinks: false);
          for (final entity in entities) {
            if (entity is File) {
              final ext = p.extension(entity.path).toLowerCase();
              if (supportedExtensions.contains(ext) && !seenPaths.contains(entity.path)) {
                seenPaths.add(entity.path);
                audioFilePaths.add(entity.path);
              }
            }
          }
        } catch (_) {}
      }

      return await scanFilesWithCache(audioFilePaths, favoriteIds: favoriteIds);
    } catch (e) {
      debugPrint('Directory scan note: $e');
      return [];
    }
  }

  /// Automatically scan all device music via candidate common directories
  Future<List<Song>> scanDeviceStandardMusicDirs({Set<String>? favoriteIds}) async {
    final candidateDirs = <String>[];

    if (!kIsWeb && Platform.isAndroid) {
      candidateDirs.addAll([
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/storage/emulated/0/Audio',
        '/storage/emulated/0/Podcasts',
        '/storage/emulated/0/Media',
        '/storage/emulated/0/Recordings',
        '/storage/emulated/0/Bluetooth',
        '/storage/emulated/0/Documents',
        '/storage/emulated/0/WhatsApp/Media/WhatsApp Audio',
        '/storage/emulated/0/Telegram',
      ]);

      try {
        final extMusic = await getExternalStorageDirectories(type: StorageDirectory.music);
        if (extMusic != null) {
          for (final d in extMusic) {
            candidateDirs.add(d.path);
          }
        }
        final extDownloads = await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (extDownloads != null) {
          for (final d in extDownloads) {
            candidateDirs.add(d.path);
          }
        }
      } catch (_) {}
    } else if (!kIsWeb) {
      try {
        final musicDir = await getDownloadsDirectory();
        if (musicDir != null) candidateDirs.add(musicDir.path);
      } catch (_) {}
    }

    final cache = _storageService.getCachedSongEntries();
    final allAudioPaths = <String>[];
    final seenPaths = <String>{};

    for (final dirPath in candidateDirs) {
      final normalized = normalizeFolderPath(dirPath);
      final dir = Directory(normalized);
      if (!await dir.exists()) continue;

      try {
        await for (final entity in dir.list(recursive: true, followLinks: false).handleError((_) {})) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (supportedExtensions.contains(ext) && !seenPaths.contains(entity.path)) {
              seenPaths.add(entity.path);
              allAudioPaths.add(entity.path);
            }
          }
        }
      } catch (_) {}
    }

    return await scanFilesWithCache(
      allAudioPaths,
      favoriteIds: favoriteIds,
      preloadedCache: cache,
    );
  }
}
