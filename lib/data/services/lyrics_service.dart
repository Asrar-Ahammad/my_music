import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/utils/lrc_parser.dart';
import '../../core/utils/permission_helper.dart';
import '../../domain/models/lrc_model.dart';
import '../../domain/models/song.dart';
import '../repositories/settings_repository.dart';
import 'file_scanner_service.dart';

class LyricsResult {
  final LrcDocument document;
  final String sourceName;
  final bool isFromCache;

  const LyricsResult({
    required this.document,
    required this.sourceName,
    this.isFromCache = false,
  });
}

/// Private sentinel returned by [LyricsService._checkCache] when the cache
/// contains a valid negative entry (song confirmed to have no online lyrics).
/// Using a subclass keeps the public return type of [_checkCache] as
/// [LyricsResult?] while giving callers a way to distinguish a negative hit
/// from a plain cache-miss (null).
class _NegativeCacheHit extends LyricsResult {
  static final _NegativeCacheHit _instance = _NegativeCacheHit._();
  _NegativeCacheHit._()
      : super(
          document: LrcDocument(
            lines: const [],
            isSynced: false,
            title: null,
            artist: null,
            album: null,
            rawContent: '',
          ),
          sourceName: '',
        );
}

class LyricsService {
  final SettingsRepository _settingsRepository;
  final HttpClient _httpClient;

  LyricsService({
    SettingsRepository? settingsRepository,
    HttpClient? httpClient,
  })  : _settingsRepository = settingsRepository ?? SettingsRepository(),
        _httpClient = httpClient ?? HttpClient() {
    _httpClient.connectionTimeout = const Duration(seconds: 8);
  }

  /// Fetches lyrics for a given song according to priority:
  /// Fetches lyrics for a given song according to priority:
  /// 1. Local file alongside song (.lrc)
  /// 2. User-configured Local LRC Directory (.lrc)
  /// 3. Persistent cache
  /// 4. Online providers (enabled via Settings → Lyrics Providers) if enabled
  ///
  /// When [prioritizeSyllableLyrics] is enabled in settings, sources with
  /// explicit syllable/word-level timings are prioritized, and synced lines
  /// are enriched with real-time word timings.
  Future<LyricsResult?> getLyrics(Song song) async {
    final prioritizeSyllables = _settingsRepository.isPrioritizeSyllableLyrics();

    // 1. Check local file alongside audio file (Top Priority)
    final fileResult = await _checkLocalSongFile(song);
    if (fileResult != null) {
      return _applySettingsToResult(fileResult);
    }

    // 2. Check local LRC folder from settings (Always takes priority over network/cache)
    final folderResult = await _checkLocalLrcFolder(song, prioritizeSyllables: prioritizeSyllables);
    if (folderResult != null) {
      return _applySettingsToResult(folderResult);
    }

    LyricsResult? fallbackResult;

    // 3. Check persistent cache
    final cachedResult = await _checkCache(song);
    if (cachedResult != null) {
      if (cachedResult.document.hasSyllableTimings || !prioritizeSyllables) {
        return _applySettingsToResult(cachedResult);
      }
      fallbackResult ??= cachedResult;
    }

    // 4. If online lyrics are enabled, query online API
    if (_settingsRepository.isOnlineLyricsEnabled()) {
      // Skip the API entirely if the cache has a fresh negative sentinel.
      final cacheHit = await _checkCache(song);
      if (cacheHit is _NegativeCacheHit) {
        // Known no-lyrics song within TTL — don't call the API.
        return fallbackResult != null ? _applySettingsToResult(fallbackResult) : null;
      }

      final onlineResult = await _fetchOnlineLyrics(song);
      if (onlineResult != null) {
        // Save to cache for offline reuse
        await _saveToCache(song, onlineResult.document.rawContent);
        if (onlineResult.document.hasSyllableTimings || fallbackResult == null) {
          return _applySettingsToResult(onlineResult);
        }
      } else {
        // No lyrics found online — cache a negative sentinel to avoid
        // hammering the API on every play of this song.
        await _saveNegativeToCache(song);
      }
    }

    if (fallbackResult != null) {
      return _applySettingsToResult(fallbackResult);
    }

    return null;
  }

  LyricsResult _applySettingsToResult(LyricsResult result) {
    // Preserve genuine document timestamps: line-synced lyrics remain line-synced,
    // and enhanced lyrics preserve their genuine word timestamps.
    return result;
  }

  /// Safely decodes raw LRC bytes, handling UTF-8 BOM, standard UTF-8, Latin-1, and malformed encodings
  static String _decodeLrcBytes(List<int> bytes) {
    if (bytes.isEmpty) return '';
    var cleanBytes = bytes;
    // Strip UTF-8 BOM (0xEF, 0xBB, 0xBF)
    if (cleanBytes.length >= 3 &&
        cleanBytes[0] == 0xEF &&
        cleanBytes[1] == 0xBB &&
        cleanBytes[2] == 0xBF) {
      cleanBytes = cleanBytes.sublist(3);
    }
    try {
      return utf8.decode(cleanBytes, allowMalformed: false);
    } catch (_) {
      try {
        return utf8.decode(cleanBytes, allowMalformed: true);
      } catch (_) {
        try {
          return latin1.decode(cleanBytes);
        } catch (_) {
          return String.fromCharCodes(cleanBytes);
        }
      }
    }
  }

  static String cleanSongTitle(String rawTitle) {
    var title = rawTitle;
    // Strip leading track numbers: "01. ", "01 - ", "1. ", "01 "
    title = title.replaceFirst(RegExp(r'^\d+[\s\.\-_]+'), '');
    // Strip audio extensions if present: .mp3, .flac, .m4a, etc.
    title = title.replaceFirst(RegExp(r'\.(mp3|flac|m4a|wav|ogg|opus|aac|wma)$', caseSensitive: false), '');
    // Strip web domains: www.site.com, site.com, songs.pk, etc.
    title = title.replaceAll(RegExp(r'www\.[^\s]+', caseSensitive: false), '');
    title = title.replaceAll(RegExp(r'\b[a-zA-Z0-9_\-]+\.(com|net|org|pk|in|me|info|io|co|biz)\b', caseSensitive: false), '');
    // Strip bracketed web tags / download tags / site tags: [Songs.pk], [PagalWorld], etc.
    title = title.replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*(\.[a-zA-Z]{2,4}|download|official|lyric|audio|hq|hd|remaster|kbps|rip|songs|mp3|video)[^\)\]\}]*[\)\]\}]', caseSensitive: false), '');
    // Strip tag noise: [Official Video], (Audio), [HQ], (320kbps), (Lyrics), etc.
    title = title.replaceAll(RegExp(r'[\(\[\{]\s*(official\s*(video|audio|music\s*video|track)?|audio|lyric(s)?(\s*video)?|hq|hd|remaster(ed)?(\s*\d+)?|320\s*kbps|128\s*kbps|[^\)\]\}]*download[^\)\]\}]*)\s*[\)\]\}]', caseSensitive: false), '');
    // Strip parenthetical feat: (feat. ...)
    title = title.replaceAll(RegExp(r'[\(\[\{]\s*(feat|ft)\.?\s+[^\)\]\}]+[\)\]\}]', caseSensitive: false), '');
    // Clean up empty brackets leftover
    title = title.replaceAll(RegExp(r'[\(\[\{]\s*[\)\]\}]'), '');
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String cleanArtistName(String rawArtist) {
    var cleaned = rawArtist.replaceAll(RegExp(r'www\.[^\s]+', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'\b[a-zA-Z0-9_\-]+\.(com|net|org|pk|in|me|info|io|co|biz)\b', caseSensitive: false), '');
    final lower = cleaned.toLowerCase().trim();
    if (lower.isEmpty ||
        lower == 'unknown' ||
        lower == 'unknown artist' ||
        lower == '<unknown>' ||
        lower == 'various artists' ||
        lower == 'various' ||
        lower == 'artist') {
      return '';
    }
    final primary = cleaned.split(RegExp(r'[,/|]|\bfeat\.?\b|\bft\.?\b|\b&\b', caseSensitive: false)).first.trim();
    return primary;
  }

  static String _normalizeForMatching(String input) {
    return input
        .toLowerCase()
        // Strip parenthetical extra tags like (feat. ...), [official audio], etc.
        .replaceAll(RegExp(r'[\(\[\{][^\)\]\}]*[\)\]\}]'), ' ')
        // Remove common punctuation and symbols while preserving unicode letters and numbers
        .replaceAll(RegExp(r'[\p{P}\p{S}]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool matchesSong(String lrcBaseName, Song song) => _matchesSong(lrcBaseName, song);

  static bool _matchesSong(String lrcBaseName, Song song) {
    final cleanLrc = lrcBaseName.toLowerCase().trim();
    final normLrc = _normalizeForMatching(lrcBaseName);
    if (normLrc.isEmpty) return false;

    // 1. Direct song title (exact or cleaned)
    final cleanTitle = song.title.toLowerCase().trim();
    final normTitle = _normalizeForMatching(song.title);
    if (cleanLrc == cleanTitle || normLrc == normTitle) return true;

    final cleanedTitle = cleanSongTitle(song.title);
    final normCleanTitle = _normalizeForMatching(cleanedTitle);
    if (normCleanTitle.isNotEmpty && (cleanLrc == cleanedTitle.toLowerCase() || normLrc == normCleanTitle)) {
      return true;
    }

    // 2. Artist - Title or Title - Artist
    final cleanArtist = song.artist.toLowerCase().trim();
    final normArtist = _normalizeForMatching(song.artist);
    final cleanedArtist = cleanArtistName(song.artist);
    final normCleanArtist = _normalizeForMatching(cleanedArtist);

    if (normArtist.isNotEmpty && normTitle.isNotEmpty) {
      if (normLrc == '$normArtist $normTitle' || normLrc == '$normTitle $normArtist') {
        return true;
      }
      if (cleanLrc == '$cleanArtist - $cleanTitle' || cleanLrc == '$cleanTitle - $cleanArtist') {
        return true;
      }
    }
    if (normCleanArtist.isNotEmpty && normCleanTitle.isNotEmpty) {
      if (normLrc == '$normCleanArtist $normCleanTitle' || normLrc == '$normCleanTitle $normCleanArtist') {
        return true;
      }
    }

    // 3. Audio file base name from song.uri (Exact match only)
    if (song.uri.isNotEmpty) {
      final uriClean = song.uri.split('?').first;
      final audioBase = p.basenameWithoutExtension(uriClean);
      final cleanAudio = audioBase.toLowerCase().trim();
      final normAudio = _normalizeForMatching(audioBase);
      if (cleanLrc == cleanAudio || normLrc == normAudio) return true;
    }

    // 4. Song ID (e.g. sample_01)
    if (song.id.isNotEmpty) {
      final cleanId = song.id.toLowerCase().trim();
      final normId = _normalizeForMatching(song.id);
      if (cleanLrc == cleanId || normLrc == normId) return true;
    }

    // 5. Track number prefix strip (e.g. "01 - Title" or "01. Title")
    final withoutTrackNum = normLrc.replaceFirst(RegExp(r'^\d+\s*'), '').trim();
    if (withoutTrackNum.isNotEmpty) {
      if (normTitle.isNotEmpty && withoutTrackNum == normTitle) return true;
      if (normCleanTitle.isNotEmpty && withoutTrackNum == normCleanTitle) return true;
    }

    // 6. Split filename on "-" or "_" to test segments: e.g. "Artist - Title"
    if (lrcBaseName.contains('-') || lrcBaseName.contains('_')) {
      final segments = lrcBaseName
          .split(RegExp(r'[-_]'))
          .map(_normalizeForMatching)
          .where((s) => s.isNotEmpty)
          .toList();

      final titleMatches = segments.any((s) => s == normTitle || (normCleanTitle.isNotEmpty && s == normCleanTitle));
      if (titleMatches) {
        if (normCleanArtist.isEmpty || song.artist.toLowerCase().contains('unknown')) {
          return true;
        }
        final artistMatches = segments.any((s) => s == normCleanArtist || s == normArtist || s.contains(normCleanArtist) || normCleanArtist.contains(s));
        if (artistMatches) {
          return true;
        }
      }
    }

    return false;
  }

  /// Check for an .lrc file in the same folder as the song
  Future<LyricsResult?> _checkLocalSongFile(Song song) async {
    if (song.isAsset) return null;
    try {
      final uri = song.uri;
      final candidates = <String>[];

      // 1. Direct path check alongside audio file
      if (!uri.startsWith('http') && !uri.startsWith('content:')) {
        final lastDot = uri.lastIndexOf('.');
        if (lastDot > 0) {
          candidates.add('${uri.substring(0, lastDot)}.lrc');
        }
      }

      for (final path in candidates) {
        final lrcFile = File(path);
        if (await lrcFile.exists()) {
          final bytes = await lrcFile.readAsBytes();
          final content = _decodeLrcBytes(bytes);
          final doc = LrcParser.parse(content);
          if (doc.lines.isNotEmpty) {
            return LyricsResult(
              document: doc,
              sourceName: 'LOCAL FILE',
            );
          }
        }
      }

      // 2. Search parent directory for matching .lrc files
      final searchDirs = <Directory>[];
      if (!uri.startsWith('http') && !uri.startsWith('content:')) {
        searchDirs.add(File(uri).parent);
      }
      if (song.folderPath.isNotEmpty) {
        final normPath = FileScannerService.normalizeFolderPath(song.folderPath);
        final folderDir = Directory(normPath);
        if (!searchDirs.any((d) => d.path == folderDir.path)) {
          searchDirs.add(folderDir);
        }
      }

      for (final dir in searchDirs) {
        if (!await dir.exists()) continue;
        try {
          final entities = await dir.list().toList();
          final lrcFiles = <File>[];
          for (final entity in entities) {
            if (entity is File && entity.path.toLowerCase().endsWith('.lrc')) {
              lrcFiles.add(entity);
            }
          }

          // First pass: match by filename
          for (final file in lrcFiles) {
            final baseName = p.basenameWithoutExtension(file.path);
            if (_matchesSong(baseName, song)) {
              final bytes = await file.readAsBytes();
              final content = _decodeLrcBytes(bytes);
              if (content.trim().isNotEmpty) {
                final doc = LrcParser.parse(content);
                if (doc.lines.isNotEmpty) {
                  return LyricsResult(
                    document: doc,
                    sourceName: 'LOCAL FILE',
                  );
                }
              }
            }
          }

          // Second pass: inspect internal tags ([ti:...], [ar:...])
          for (final file in lrcFiles) {
            try {
              final bytes = await file.readAsBytes();
              final content = _decodeLrcBytes(bytes);
              if (content.trim().isEmpty) continue;
              final doc = LrcParser.parse(content);
              if (doc.lines.isNotEmpty && doc.title != null) {
                if (_matchesSong(doc.title!, song)) {
                  return LyricsResult(
                    document: doc,
                    sourceName: 'LOCAL FILE',
                  );
                }
              }
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Error searching directory ${dir.path} for lyrics: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking local song LRC file: $e');
    }
    return null;
  }

  /// Check user's selected local LRC folder
  Future<LyricsResult?> _checkLocalLrcFolder(Song song, {bool prioritizeSyllables = false}) async {
    final rawFolderPath = _settingsRepository.getLocalLrcFolderPath();
    if (rawFolderPath == null || rawFolderPath.trim().isEmpty) return null;

    final folderPath = FileScannerService.normalizeFolderPath(rawFolderPath);

    try {
      final dir = Directory(folderPath);
      if (!await dir.exists()) {
        if (!await PermissionHelper.hasStoragePermission()) {
          await PermissionHelper.requestStoragePermission();
        }
        if (!await dir.exists()) return null;
      }

      List<FileSystemEntity> entities = [];
      try {
        entities = await dir.list(recursive: true).toList();
      } catch (_) {
        try {
          entities = await dir.list(recursive: false).toList();
        } catch (e) {
          debugPrint('Error listing local LRC folder: $e');
          return null;
        }
      }

      LyricsResult? firstMatch;

      for (final entity in entities) {
        if (entity is! File) continue;
        final path = entity.path;
        if (!path.toLowerCase().endsWith('.lrc')) continue;

        final baseName = p.basenameWithoutExtension(path);
        if (_matchesSong(baseName, song)) {
          try {
            final bytes = await entity.readAsBytes();
            final content = _decodeLrcBytes(bytes);
            if (content.trim().isEmpty) continue;

            final doc = LrcParser.parse(content);
            if (doc.lines.isNotEmpty) {
              final result = LyricsResult(
                document: doc,
                sourceName: 'LOCAL FOLDER',
              );
              // If prioritizing syllables, return immediately if this file has explicit syllable timings
              if (prioritizeSyllables && doc.hasSyllableTimings) {
                return result;
              }
              firstMatch ??= result;
            }
          } catch (fileErr) {
            debugPrint('Error reading LRC file $path: $fileErr');
          }
        }
      }

      if (firstMatch == null) {
        for (final entity in entities) {
          if (entity is! File) continue;
          final path = entity.path;
          if (!path.toLowerCase().endsWith('.lrc')) continue;
          try {
            final bytes = await entity.readAsBytes();
            final content = _decodeLrcBytes(bytes);
            if (content.trim().isEmpty) continue;
            final doc = LrcParser.parse(content);
            if (doc.lines.isNotEmpty && doc.title != null && _matchesSong(doc.title!, song)) {
              final result = LyricsResult(
                document: doc,
                sourceName: 'LOCAL FOLDER',
              );
              if (prioritizeSyllables && doc.hasSyllableTimings) {
                return result;
              }
              firstMatch ??= result;
            }
          } catch (_) {}
        }
      }

      return firstMatch;
    } catch (e) {
      debugPrint('Error scanning local LRC folder: $e');
    }
    return null;
  }

  /// Check temporary / app cache directory.
  ///
  /// Returns:
  /// - A [LyricsResult] for a valid cached positive entry.
  /// - A [_NegativeCacheHit] sentinel (null) when the song is known to have
  ///   no online lyrics — caller should skip the API.
  /// - `null` on cache miss or expired entry.
  Future<LyricsResult?> _checkCache(Song song) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheKey = _getCacheFilename(song);
      final cacheFile = File('${cacheDir.path}/$cacheKey');

      if (!await cacheFile.exists()) return null;

      final stat = await cacheFile.stat();
      final age = DateTime.now().difference(stat.modified);
      final bytes = await cacheFile.readAsBytes();
      final content = _decodeLrcBytes(bytes);

      // --- Negative sentinel: song has no online lyrics ---
      if (content.trimLeft().startsWith(_kNegativeSentinel)) {
        if (age > _kNegativeTtl) {
          // Expired — delete so we try the API again next time.
          try { await cacheFile.delete(); } catch (_) {}
          return null;
        }
        // Within TTL — signal caller to skip the API.
        return _NegativeCacheHit._instance;
      }

      // --- Positive cache entry ---
      if (age > _kPositiveTtl) {
        // Expired — delete and let caller fetch fresh from API.
        try { await cacheFile.delete(); } catch (_) {}
        return null;
      }

      final doc = LrcParser.parse(content);
      if (doc.lines.isNotEmpty) {
        // Guard against a cached entry that belongs to a different song
        // (hash collision or corrupted file).
        if (doc.title != null && doc.title!.trim().isNotEmpty) {
          final normDocTitle = _normalizeForMatching(doc.title!);
          final normSongTitle = _normalizeForMatching(cleanSongTitle(song.title));
          if (normDocTitle.isNotEmpty &&
              normSongTitle.isNotEmpty &&
              normDocTitle != normSongTitle &&
              !normSongTitle.contains(normDocTitle) &&
              !normDocTitle.contains(normSongTitle)) {
            try { await cacheFile.delete(); } catch (_) {}
            return null;
          }
        }
        return LyricsResult(
          document: doc,
          sourceName: 'LRCLIB (CACHED)',
          isFromCache: true,
        );
      }
    } catch (e) {
      debugPrint('Error reading lyrics cache: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Cache limits & TTL
  // ---------------------------------------------------------------------------
  static const int _kMaxCacheEntries = 100;
  static const int _kMaxCacheSizeBytes = 10 * 1024 * 1024; // 10 MB
  static const Duration _kPositiveTtl = Duration(days: 30);
  static const Duration _kNegativeTtl = Duration(days: 7);

  /// Sentinel content written for songs with no online lyrics, so we do not
  /// re-query the API on every play.
  static const String _kNegativeSentinel = '#NO_LYRICS';

  /// Save downloaded LRC to cache (with LRU eviction afterwards).
  Future<void> _saveToCache(Song song, String rawLrc) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheKey = _getCacheFilename(song);
      final cacheFile = File('${cacheDir.path}/$cacheKey');
      await cacheFile.writeAsString(rawLrc);
      await _evictCacheIfNeeded(cacheDir);
    } catch (e) {
      debugPrint('Error writing lyrics cache: $e');
    }
  }

  /// Persist a negative sentinel so we skip the API for [_kNegativeTtl].
  Future<void> _saveNegativeToCache(Song song) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheKey = _getCacheFilename(song);
      final cacheFile = File('${cacheDir.path}/$cacheKey');
      await cacheFile.writeAsString(_kNegativeSentinel);
      await _evictCacheIfNeeded(cacheDir);
    } catch (e) {
      debugPrint('Error writing negative lyrics cache: $e');
    }
  }

  /// Evict stale (TTL-expired) entries first, then enforce entry count and
  /// total-size limits by removing the oldest files (LRU by `modified` time).
  Future<void> _evictCacheIfNeeded(Directory cacheDir) async {
    try {
      final now = DateTime.now();
      final entities = await cacheDir.list().toList();
      final files = <File>[];

      // Step 1: delete TTL-expired files
      for (final entity in entities) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        final age = now.difference(stat.modified);
        final content = await entity.readAsString();
        final isNegative = content.trimLeft().startsWith(_kNegativeSentinel);
        final ttl = isNegative ? _kNegativeTtl : _kPositiveTtl;
        if (age > ttl) {
          try {
            await entity.delete();
          } catch (_) {}
        } else {
          files.add(entity);
        }
      }

      // Step 2: sort surviving files oldest-first (LRU order)
      final fileStats = <(File, FileStat)>[];
      for (final f in files) {
        try {
          fileStats.add((f, await f.stat()));
        } catch (_) {}
      }
      fileStats.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));

      // Step 3: enforce entry count cap
      while (fileStats.length > _kMaxCacheEntries) {
        final oldest = fileStats.removeAt(0);
        try {
          await oldest.$1.delete();
        } catch (_) {}
      }

      // Step 4: enforce total size cap
      int totalBytes = fileStats.fold(0, (sum, e) => sum + e.$2.size);
      while (totalBytes > _kMaxCacheSizeBytes && fileStats.isNotEmpty) {
        final oldest = fileStats.removeAt(0);
        totalBytes -= oldest.$2.size;
        try {
          await oldest.$1.delete();
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error evicting lyrics cache: $e');
    }
  }

  Future<Directory> _getCacheDirectory() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory('${temp.path}/lyrics_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  String _getCacheFilename(Song song) {
    final safeArtist = _sanitizeFilename(cleanArtistName(song.artist));
    final safeTitle = _sanitizeFilename(cleanSongTitle(song.title));
    // Use a stable djb2 hash instead of Dart's non-deterministic hashCode.
    final uriHash = _stableHash(song.uri.isNotEmpty ? song.uri : song.id)
        .toRadixString(16);
    return '${safeArtist}_${safeTitle}_$uriHash.lrc';
  }

  /// djb2 hash — stable across Dart VM restarts and all platforms.
  static int _stableHash(String input) {
    var hash = 5381;
    for (final codeUnit in input.codeUnits) {
      hash = ((hash << 5) + hash) ^ codeUnit;
      hash &= 0xFFFFFFFF; // keep 32-bit unsigned
    }
    return hash;
  }

  String _sanitizeFilename(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '').trim();
  }

  // ---------------------------------------------------------------------------
  // Multi-provider online fetch
  // ---------------------------------------------------------------------------

  /// Tries each enabled online source in order and returns the first successful result.
  /// Sources are checked against the user's enabled list from Settings.
  Future<LyricsResult?> _fetchOnlineLyrics(Song song) async {
    final enabledSources = _settingsRepository.getEnabledLyricSources();
    if (enabledSources.isEmpty) return null;

    for (final source in enabledSources) {
      try {
        final result = await _fetchFromSource(source, song);
        if (result != null) return result;
      } catch (e) {
        debugPrint('[$source] fetch error: $e');
      }
    }
    return null;
  }

  /// Dispatches a single provider fetch by [source] name.
  Future<LyricsResult?> _fetchFromSource(String source, Song song) async {
    switch (source) {
      case 'LRCLIB':
        return _fetchLrclib(
          song,
          host: 'lrclib.net',
          sourceName: 'LRCLIB',
        );
      case 'LyricsPlus':
        // Community mirror running the same LRCLIB-compatible API.
        return _fetchLrclib(
          song,
          host: 'lrclib.shinylib.net',
          sourceName: 'LyricsPlus',
        );
      case 'PaxSenix':
        // PaxSenix hosts a public LRCLIB-compatible mirror.
        return _fetchLrclib(
          song,
          host: 'lyrics.paxsenix.biz.id',
          sourceName: 'PaxSenix',
        );
      case 'BetterLyrics':
        // Fallback to LRCLIB search-only path for broader coverage.
        return _fetchLrclibSearchOnly(song, sourceName: 'BetterLyrics');
      case 'SimpMusic':
        return _fetchLrclib(
          song,
          host: 'lrclib.net',
          sourceName: 'SimpMusic',
          preferPlain: true, // SimpMusic is known for plain-text lyrics
        );
      case 'KuGou':
        return _fetchKuGou(song);
      case 'Musixmatch':
        return _fetchMusixmatch(song);
      default:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // LRCLIB-compatible provider (covers LRCLIB, LyricsPlus mirror, PaxSenix)
  // ---------------------------------------------------------------------------

  Future<LyricsResult?> _fetchLrclib(
    Song song, {
    required String host,
    required String sourceName,
    bool preferPlain = false,
  }) async {
    try {
      final cleanTitle = cleanSongTitle(song.title);
      final cleanArtist = cleanArtistName(song.artist);

      Map<String, dynamic>? data;

      // 1. Direct /api/get match
      if (cleanTitle.isNotEmpty &&
          (cleanArtist.isNotEmpty ||
              (song.artist.isNotEmpty &&
                  !song.artist.toLowerCase().contains('unknown')))) {
        final directParams = <String, String>{
          'track_name': cleanTitle.isNotEmpty ? cleanTitle : song.title,
          if (cleanArtist.isNotEmpty)
            'artist_name': cleanArtist
          else
            'artist_name': song.artist,
          if (song.album.isNotEmpty &&
              !song.album.toLowerCase().contains('unknown'))
            'album_name': song.album,
          if (song.duration > Duration.zero)
            'duration': song.duration.inSeconds.toString(),
        };

        final directUri = Uri.https(host, '/api/get', directParams);
        final res = await _fetchJson(directUri);
        if (res is Map<String, dynamic> &&
            (res['syncedLyrics'] != null || res['plainLyrics'] != null)) {
          data = res;
        }
      }

      // 2. Raw title fallback if clean title differs
      if (data == null &&
          cleanTitle != song.title &&
          song.title.trim().isNotEmpty &&
          cleanArtist.isNotEmpty) {
        final rawParams = <String, String>{
          'track_name': song.title,
          'artist_name': cleanArtist,
          if (song.duration > Duration.zero)
            'duration': song.duration.inSeconds.toString(),
        };
        final rawUri = Uri.https(host, '/api/get', rawParams);
        final res = await _fetchJson(rawUri);
        if (res is Map<String, dynamic> &&
            (res['syncedLyrics'] != null || res['plainLyrics'] != null)) {
          data = res;
        }
      }

      // 3. /api/search fallback
      data ??= await _lrclibSearch(host, song, cleanTitle, cleanArtist);

      return _parseLrclibResponse(data, sourceName, preferPlain: preferPlain);
    } catch (e) {
      debugPrint('Error fetching from $sourceName ($host): $e');
      return null;
    }
  }

  /// Search-only LRCLIB path (used for BetterLyrics fallback)
  Future<LyricsResult?> _fetchLrclibSearchOnly(
    Song song, {
    required String sourceName,
  }) async {
    try {
      final cleanTitle = cleanSongTitle(song.title);
      final cleanArtist = cleanArtistName(song.artist);
      final data =
          await _lrclibSearch('lrclib.net', song, cleanTitle, cleanArtist);
      return _parseLrclibResponse(data, sourceName);
    } catch (e) {
      debugPrint('Error fetching from $sourceName (search-only): $e');
      return null;
    }
  }

  /// Shared LRCLIB /api/search implementation.
  Future<Map<String, dynamic>?> _lrclibSearch(
    String host,
    Song song,
    String cleanTitle,
    String cleanArtist,
  ) async {
    final searchTerms = [cleanTitle.isNotEmpty ? cleanTitle : song.title, cleanArtist]
        .where((s) => s.isNotEmpty)
        .join(' ');

    if (searchTerms.trim().isEmpty) return null;

    final searchUri = Uri.https(host, '/api/search', {'q': searchTerms});
    final searchData = await _fetchJson(searchUri);
    if (searchData is! List || searchData.isEmpty) return null;

    Map<String, dynamic>? bestMatch;
    int bestScore = -1;

    final normCleanTitle = _normalizeForMatching(
        cleanTitle.isNotEmpty ? cleanTitle : song.title);
    final normCleanArtist = _normalizeForMatching(cleanArtist);

    for (final item in searchData) {
      if (item is! Map<String, dynamic>) continue;
      final syncedLyrics = item['syncedLyrics'] as String?;
      final plainLyrics = item['plainLyrics'] as String?;
      if ((syncedLyrics == null || syncedLyrics.isEmpty) &&
          (plainLyrics == null || plainLyrics.isEmpty)) {
        continue;
      }

      final candidateTrack = (item['trackName'] as String? ?? '').trim();
      final candidateArtist = (item['artistName'] as String? ?? '').trim();
      final candidateDuration =
          (item['duration'] as num?)?.toDouble() ?? 0.0;

      final normCandidateTrack = _normalizeForMatching(candidateTrack);
      final normCandidateArtist = _normalizeForMatching(candidateArtist);

      final isExactTitle = normCandidateTrack == normCleanTitle;
      final isPrefixTitle = normCleanTitle.length >= 4 &&
          (normCandidateTrack.startsWith(normCleanTitle) ||
              normCleanTitle.startsWith(normCandidateTrack));

      if (!isExactTitle && !isPrefixTitle) continue;

      int score = isExactTitle ? 100 : 50;

      if (normCleanArtist.isNotEmpty) {
        if (normCandidateArtist == normCleanArtist) {
          score += 60;
        } else if (normCandidateArtist.contains(normCleanArtist) ||
            normCleanArtist.contains(normCandidateArtist)) {
          score += 30;
        } else {
          continue; // Contradicting artist
        }
      }

      if (song.duration > Duration.zero && candidateDuration > 0) {
        final diff = (song.duration.inSeconds - candidateDuration).abs();
        if (diff <= 3) {
          score += 30;
        } else if (diff <= 8) {
          score += 15;
        } else if (diff > 18) {
          continue;
        }
      }

      if (syncedLyrics != null && syncedLyrics.isNotEmpty) score += 20;

      if (score > bestScore) {
        bestScore = score;
        bestMatch = item;
      }
    }

    return bestMatch;
  }

  /// Parses a LRCLIB-shaped JSON response into a [LyricsResult].
  LyricsResult? _parseLrclibResponse(
    Map<String, dynamic>? data,
    String sourceName, {
    bool preferPlain = false,
  }) {
    if (data == null) return null;
    final syncedLyrics = data['syncedLyrics'] as String?;
    final plainLyrics = data['plainLyrics'] as String?;

    final String? lrcContent;
    if (preferPlain) {
      lrcContent = (plainLyrics != null && plainLyrics.isNotEmpty)
          ? plainLyrics
          : (syncedLyrics != null && syncedLyrics.isNotEmpty
              ? syncedLyrics
              : null);
    } else {
      lrcContent = (syncedLyrics != null && syncedLyrics.isNotEmpty)
          ? syncedLyrics
          : plainLyrics;
    }

    if (lrcContent == null || lrcContent.isEmpty) return null;

    final doc = LrcParser.parse(lrcContent);
    if (doc.lines.isEmpty) return null;

    return LyricsResult(document: doc, sourceName: sourceName);
  }

  // ---------------------------------------------------------------------------
  // KuGou provider
  // ---------------------------------------------------------------------------

  /// Queries the KuGou open lyrics API.
  /// KuGou returns LRC-formatted lyrics directly from their search.
  Future<LyricsResult?> _fetchKuGou(Song song) async {
    try {
      final cleanTitle = cleanSongTitle(song.title);
      final cleanArtist = cleanArtistName(song.artist);
      final keyword = [cleanArtist, cleanTitle]
          .where((s) => s.isNotEmpty)
          .join(' - ');
      if (keyword.trim().isEmpty) return null;

      // Step 1: Search for the song ID
      final searchUri = Uri.https('mobilecdn.kugou.com', '/api/v3/search/song', {
        'format': 'json',
        'keyword': keyword,
        'page': '1',
        'pagesize': '5',
      });
      final searchData = await _fetchJson(searchUri);
      if (searchData is! Map) return null;
      final lists = searchData['data']?['info'] as List?;
      if (lists == null || lists.isEmpty) return null;

      String? hash;
      for (final item in lists) {
        if (item is! Map) continue;
        hash = item['hash'] as String?;
        if (hash != null && hash.isNotEmpty) break;
      }
      if (hash == null) return null;

      // Step 2: Fetch lyrics by hash
      final lyricsUri = Uri.https('lyrics.kugou.com', '/download', {
        'ver': '1',
        'man': 'yes',
        'client': 'pc',
        'hash': hash,
        'fmt': 'lrc',
      });
      final lyricsData = await _fetchJson(lyricsUri);
      if (lyricsData is! Map) return null;

      final content = lyricsData['content'] as String?;
      if (content == null || content.isEmpty) return null;

      // KuGou returns base64-encoded LRC
      String decoded;
      try {
        decoded = utf8.decode(base64.decode(content));
      } catch (_) {
        decoded = content;
      }

      final doc = LrcParser.parse(decoded);
      if (doc.lines.isEmpty) return null;

      return LyricsResult(document: doc, sourceName: 'KuGou');
    } catch (e) {
      debugPrint('KuGou fetch error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Musixmatch provider
  // ---------------------------------------------------------------------------

  /// Queries the Musixmatch unofficial lyrics API.
  /// Uses the community token endpoint that many open-source apps use.
  Future<LyricsResult?> _fetchMusixmatch(Song song) async {
    try {
      final cleanTitle = cleanSongTitle(song.title);
      final cleanArtist = cleanArtistName(song.artist);
      if (cleanTitle.isEmpty) return null;

      // Use the Musixmatch web-based matcher endpoint (no API key required)
      final uri = Uri.https('apic-desktop.musixmatch.com', '/ws/1.1/matcher.lyrics.get', {
        'format': 'json',
        'namespace': 'lyrics_synched',
        'q_track': cleanTitle,
        if (cleanArtist.isNotEmpty) 'q_artist': cleanArtist,
        'usertoken': '2203269256194b0f4af5a3c3592ea4ce17a4ea91915ebab9a00c25',
        'app_id': 'web-desktop-app-v1.0',
      });

      final data = await _fetchJson(uri);
      if (data is! Map) return null;

      final message = data['message'] as Map?;
      final body = message?['body'] as Map?;
      if (body == null) return null;

      // Try subtitle (synced) first
      final subtitle = body['subtitle'] as Map?;
      final subtitleBody = subtitle?['subtitle_body'] as String?;
      if (subtitleBody != null && subtitleBody.isNotEmpty) {
        // Musixmatch subtitles are in JSON format, convert to LRC
        final lrcContent = _musixmatchSubtitleToLrc(subtitleBody);
        if (lrcContent != null) {
          final doc = LrcParser.parse(lrcContent);
          if (doc.lines.isNotEmpty) {
            return LyricsResult(document: doc, sourceName: 'Musixmatch');
          }
        }
      }

      // Fall back to plain lyrics
      final lyrics = body['lyrics'] as Map?;
      final lyricsBody = lyrics?['lyrics_body'] as String?;
      if (lyricsBody != null && lyricsBody.isNotEmpty) {
        final doc = LrcParser.parse(lyricsBody);
        if (doc.lines.isNotEmpty) {
          return LyricsResult(document: doc, sourceName: 'Musixmatch');
        }
      }

      return null;
    } catch (e) {
      debugPrint('Musixmatch fetch error: $e');
      return null;
    }
  }

  /// Converts Musixmatch JSON subtitle format to LRC text.
  String? _musixmatchSubtitleToLrc(String subtitleBody) {
    try {
      final lines = json.decode(subtitleBody) as List;
      final buffer = StringBuffer();
      for (final line in lines) {
        if (line is! Map) continue;
        final text = line['text'] as String? ?? '';
        final time = line['time'] as Map?;
        if (time == null) continue;
        final minutes = (time['minutes'] as num?)?.toInt() ?? 0;
        final seconds = (time['seconds'] as num?)?.toDouble() ?? 0.0;
        final centiseconds = ((seconds - seconds.truncate()) * 100).round();
        buffer.writeln(
          '[${minutes.toString().padLeft(2, '0')}:${seconds.truncate().toString().padLeft(2, '0')}.${centiseconds.toString().padLeft(2, '0')}]$text',
        );
      }
      final result = buffer.toString().trim();
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  Future<dynamic> _fetchJson(Uri uri) async {
    try {
      final request = await _httpClient.getUrl(uri);
      request.headers.set('User-Agent', 'myMusic Retro Audio/1.0 (https://github.com/myMusic)');
      final response = await request.close();

      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return json.decode(body);
      }
    } catch (e) {
      debugPrint('HTTP error fetching $uri: $e');
    }
    return null;
  }
}
