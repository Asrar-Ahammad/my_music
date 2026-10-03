import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Service that fetches artist photos from free public APIs (Deezer with iTunes fallback),
/// caching results both in memory and persistently in Hive.
class ArtistPhotoService {
  ArtistPhotoService._();

  static final Map<String, String> _memoryCache = {};
  static Box? _box;
  static bool _initialized = false;

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 4),
      receiveTimeout: const Duration(seconds: 4),
    ),
  );

  /// Initializes the persistent cache box.
  static Future<void> init() async {
    if (_initialized) return;
    try {
      _box = await Hive.openBox('artist_photos_cache');
      _initialized = true;
    } catch (e) {
      debugPrint('ArtistPhotoService init error: $e');
    }
  }

  /// Extracts the primary artist name from a comma-separated artist string.
  /// E.g. "Iqlipse Nova, Aditya Rikhari" -> "Iqlipse Nova"
  static String extractPrimaryArtist(String rawArtist) {
    final trimmed = rawArtist.trim();
    if (trimmed.isEmpty) return 'Unknown Artist';

    final commaSpaceIdx = trimmed.indexOf(', ');
    if (commaSpaceIdx != -1) {
      final first = trimmed.substring(0, commaSpaceIdx).trim();
      if (first.isNotEmpty) return first;
    }

    final commaIdx = trimmed.indexOf(',');
    if (commaIdx != -1) {
      final first = trimmed.substring(0, commaIdx).trim();
      if (first.isNotEmpty) return first;
    }

    return trimmed;
  }

  /// Fetches an artist photo URL given an artist name string (handles comma separation).
  /// Checks memory cache -> Hive cache -> Deezer API -> iTunes API.
  static Future<String?> getArtistPhoto(String rawArtist) async {
    final cleanName = extractPrimaryArtist(rawArtist);
    if (cleanName.isEmpty || cleanName.toLowerCase() == 'unknown artist') {
      return null;
    }

    final key = cleanName.toLowerCase();

    // 1. Check in-memory cache
    if (_memoryCache.containsKey(key)) {
      final cached = _memoryCache[key];
      return (cached != null && cached.isNotEmpty) ? cached : null;
    }

    // 2. Check persistent Hive cache
    if (_box != null && _box!.isOpen) {
      final persisted = _box!.get(key) as String?;
      if (persisted != null) {
        _memoryCache[key] = persisted;
        return persisted.isNotEmpty ? persisted : null;
      }
    }

    // 3. Query Deezer API (free, no API key, reliable artist images)
    try {
      final response = await _dio.get(
        'https://api.deezer.com/search/artist',
        queryParameters: {'q': cleanName, 'limit': 1},
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data['data'];
        if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) {
            final pic = first['picture_big'] ??
                first['picture_medium'] ??
                first['picture_xl'] ??
                first['picture'];
            if (pic is String && pic.isNotEmpty) {
              _save(key, pic);
              return pic;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Deezer artist photo fetch error for "$cleanName": $e');
    }

    // 4. Fallback: iTunes Search API (free, no API key)
    try {
      final itunesRes = await _dio.get(
        'https://itunes.apple.com/search',
        queryParameters: {
          'term': cleanName,
          'entity': 'musicArtist',
          'limit': 1,
        },
      );
      if (itunesRes.statusCode == 200) {
        final resData = itunesRes.data is String
            ? jsonDecode(itunesRes.data as String)
            : itunesRes.data;
        if (resData is Map && resData['results'] is List) {
          final results = resData['results'] as List;
          if (results.isNotEmpty && results.first is Map) {
            final art = results.first['artworkUrl100'] as String?;
            if (art != null && art.isNotEmpty) {
              final highRes = art.replaceAll('100x100bb.jpg', '500x500bb.jpg');
              _save(key, highRes);
              return highRes;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('iTunes artist photo fetch error for "$cleanName": $e');
    }

    return null;
  }

  static void _save(String key, String url) {
    _memoryCache[key] = url;
    try {
      _box?.put(key, url);
    } catch (_) {}
  }
}
