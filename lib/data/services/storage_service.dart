import 'package:hive_flutter/hive_flutter.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/playlist.dart';
import '../../domain/models/song.dart';
import 'listening_history_service.dart';

/// Hive-based local storage service for fast, offline persistence.
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late Box _settingsBox;
  late Box _playlistsBox;
  late Box _favoritesBox;
  late Box _scanFoldersBox;
  Box? _songsCacheBox;
  Box? _aiSongTagsBox;
  final Map<String, Map<String, dynamic>> _memorySongsCache = {};
  List<Map<String, dynamic>> _memoryRecentlyPlayed = [];
  List<String> _memoryScanFolders = [];
  List<String> _memoryCustomFiles = [];

  Future<void> init([String? testPath]) async {
    if (testPath != null) {
      Hive.init(testPath);
    } else {
      await Hive.initFlutter();
    }
    _settingsBox = await Hive.openBox(AppConstants.settingsBox);
    _playlistsBox = await Hive.openBox(AppConstants.playlistsBox);
    _favoritesBox = await Hive.openBox(AppConstants.favoritesBox);
    _scanFoldersBox = await Hive.openBox(AppConstants.scanFoldersBox);
    try {
      _songsCacheBox = await Hive.openBox(AppConstants.songsCacheBox);
    } catch (_) {}
    try {
      _aiSongTagsBox = await Hive.openBox(AppConstants.aiSongTagsBox);
    } catch (_) {}
    try {
      await ListeningHistoryService().init();
      await ListeningHistoryService().pruneOldEvents(
          retentionMonths: AppConstants.defaultHistoryRetentionMonths);
    } catch (_) {}
  }

  // --- Theme Mode & Palettes ---
  bool isDarkMode({bool defaultValue = false}) {
    return _settingsBox.get(AppConstants.keyDarkMode, defaultValue: defaultValue) as bool;
  }

  Future<void> setDarkMode(bool isDark) async {
    await _settingsBox.put(AppConstants.keyDarkMode, isDark);
  }

  // --- Onboarding Completion Status ---
  bool isOnboardingCompleted({bool defaultValue = false}) {
    try {
      return _settingsBox.get(AppConstants.keyOnboardingCompleted, defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setOnboardingCompleted(bool completed) async {
    try {
      await _settingsBox.put(AppConstants.keyOnboardingCompleted, completed);
    } catch (_) {}
  }

  // --- Fetch All Audio & Music ---
  bool isFetchAllAudio({bool defaultValue = false}) {
    try {
      return _settingsBox.get(AppConstants.keyFetchAllAudio, defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setFetchAllAudio(bool enabled) async {
    try {
      await _settingsBox.put(AppConstants.keyFetchAllAudio, enabled);
    } catch (_) {}
  }

  // --- On-Device AI Features ---
  bool isAiFeaturesEnabled({bool defaultValue = false}) {
    try {
      return _settingsBox.get(AppConstants.keyAiFeaturesEnabled, defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setAiFeaturesEnabled(bool enabled) async {
    try {
      await _settingsBox.put(AppConstants.keyAiFeaturesEnabled, enabled);
    } catch (_) {}
  }



  // --- Library Auto-Tagger toggle ---
  bool isAutoTaggerEnabled({bool defaultValue = true}) {
    try {
      return _settingsBox.get(AppConstants.keyAutoTaggerEnabled, defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setAutoTaggerEnabled(bool enabled) async {
    try {
      await _settingsBox.put(AppConstants.keyAutoTaggerEnabled, enabled);
    } catch (_) {}
  }

  // --- AI Song Tags CRUD ---
  Future<void> saveAiSongTags(Map<String, dynamic> tagsMap) async {
    try {
      final songId = tagsMap['songId'] as String?;
      if (songId == null || songId.isEmpty) return;
      await _aiSongTagsBox?.put(songId, tagsMap);
    } catch (_) {}
  }

  Map<String, dynamic>? getAiSongTags(String songId) {
    try {
      final raw = _aiSongTagsBox?.get(songId);
      if (raw == null) return null;
      return Map<String, dynamic>.from(raw as Map);
    } catch (_) {
      return null;
    }
  }

  Map<String, Map<String, dynamic>> getAllAiSongTags() {
    final result = <String, Map<String, dynamic>>{};
    try {
      final box = _aiSongTagsBox;
      if (box == null) return result;
      for (final key in box.keys) {
        final raw = box.get(key);
        if (raw != null) {
          result[key.toString()] = Map<String, dynamic>.from(raw as Map);
        }
      }
    } catch (_) {}
    return result;
  }

  Future<void> clearAllAiSongTags() async {
    try {
      await _aiSongTagsBox?.clear();
    } catch (_) {}
  }

  String getDarkPalette({String defaultValue = 'warm_espresso'}) {
    try {
      return _settingsBox.get('key_dark_palette', defaultValue: defaultValue) as String;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setDarkPalette(String id) async {
    try {
      await _settingsBox.put('key_dark_palette', id);
    } catch (_) {}
  }

  String getLightPalette({String defaultValue = 'vintage_handheld'}) {
    try {
      return _settingsBox.get('key_light_palette', defaultValue: defaultValue) as String;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setLightPalette(String id) async {
    try {
      await _settingsBox.put('key_light_palette', id);
    } catch (_) {}
  }

  // --- App Font Selection ---
  String getAppFont({String defaultValue = AppConstants.defaultAppFont}) {
    try {
      return _settingsBox.get(AppConstants.keyAppFont, defaultValue: defaultValue) as String;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setAppFont(String fontId) async {
    try {
      await _settingsBox.put(AppConstants.keyAppFont, fontId);
    } catch (_) {}
  }

  // --- Theme Style (retro | nothing) ---
  String getThemeStyle({String defaultValue = AppConstants.defaultThemeStyle}) {
    try {
      return _settingsBox.get(AppConstants.keyThemeStyle, defaultValue: defaultValue) as String;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setThemeStyle(String style) async {
    try {
      await _settingsBox.put(AppConstants.keyThemeStyle, style);
    } catch (_) {}
  }


  // --- Playlist View Mode (List vs Grid) ---
  bool isPlaylistGridView({bool defaultValue = false}) {
    try {
      return _settingsBox.get('playlist_grid_view', defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setPlaylistGridView(bool isGrid) async {
    try {
      await _settingsBox.put('playlist_grid_view', isGrid);
    } catch (_) {}
  }

  // --- Album View Mode (Grid vs List) ---
  bool isAlbumGridView({bool defaultValue = true}) {
    try {
      return _settingsBox.get('album_grid_view', defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setAlbumGridView(bool isGrid) async {
    try {
      await _settingsBox.put('album_grid_view', isGrid);
    } catch (_) {}
  }

  // --- Artist View Mode (List vs Grid) ---
  bool isArtistGridView({bool defaultValue = false}) {
    try {
      return _settingsBox.get('artist_grid_view', defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setArtistGridView(bool isGrid) async {
    try {
      await _settingsBox.put('artist_grid_view', isGrid);
    } catch (_) {}
  }

  // --- Recently Played ---
  List<Map<String, dynamic>> getRecentlyPlayed() {
    try {
      final raw = _settingsBox.get('recently_played_items');
      if (raw is List) {
        return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (_) {}
    return List.from(_memoryRecentlyPlayed);
  }

  Future<void> saveRecentlyPlayed(List<Map<String, dynamic>> items) async {
    _memoryRecentlyPlayed = List.from(items);
    try {
      await _settingsBox.put('recently_played_items', items);
    } catch (_) {}
  }

  // --- Favorites ---
  Set<String> getFavorites() {
    try {
      final list = _favoritesBox.get('favorite_ids', defaultValue: <dynamic>[]) as List;
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> saveFavorites(Set<String> favorites) async {
    try {
      await _favoritesBox.put('favorite_ids', favorites.toList());
    } catch (_) {}
  }

  // --- Playlists ---
  List<Playlist> getPlaylists() {
    try {
      final rawList = _playlistsBox.get('all_playlists', defaultValue: <dynamic>[]) as List;
      var playlists = <Playlist>[];
      for (final item in rawList) {
        if (item is Map) {
          playlists.add(Playlist.fromMap(Map<String, dynamic>.from(item)));
        }
      }

      // AUTO-RECOVERY: If playlists exist but have 0 songs, check if all_playlists_backup has the songs!
      final totalSongs = playlists.fold<int>(0, (sum, p) => sum + p.songIds.length);
      if (playlists.isNotEmpty && totalSongs == 0) {
        final backup = _playlistsBox.get('all_playlists_backup');
        if (backup is List && backup.isNotEmpty) {
          final backupPlaylists = <Playlist>[];
          for (final item in backup) {
            if (item is Map) {
              backupPlaylists.add(Playlist.fromMap(Map<String, dynamic>.from(item)));
            }
          }
          final backupTotalSongs = backupPlaylists.fold<int>(0, (sum, p) => sum + p.songIds.length);
          if (backupTotalSongs > 0) {
            // Restore from backup!
            playlists = backupPlaylists;
            _playlistsBox.put('all_playlists', backup);
          }
        }
      }

      return playlists;
    } catch (_) {
      return [];
    }
  }

  Future<void> savePlaylists(List<Playlist> playlists) async {
    try {
      final rawList = playlists.map((p) => p.toMap()).toList();
      final totalSongsNow = playlists.fold<int>(0, (sum, p) => sum + p.songIds.length);
      if (totalSongsNow > 0) {
        // Save safety backup of playlists with songs
        await _playlistsBox.put('all_playlists_backup', rawList);
      } else if (playlists.isEmpty) {
        await _playlistsBox.put('all_playlists_backup', <dynamic>[]);
      }
      await _playlistsBox.put('all_playlists', rawList);
    } catch (_) {}
  }

  // --- Scan Folders ---
  List<String> getScanFolders() {
    try {
      final list = _scanFoldersBox.get('folders', defaultValue: <dynamic>[]) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return List.from(_memoryScanFolders);
    }
  }

  Future<void> saveScanFolders(List<String> folders) async {
    _memoryScanFolders = List.from(folders);
    try {
      await _scanFoldersBox.put('folders', folders);
    } catch (_) {}
  }

  // --- Picked Audio Files ---
  List<String> getCustomFilePaths() {
    try {
      final list = _scanFoldersBox.get('custom_files', defaultValue: <dynamic>[]) as List;
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return List.from(_memoryCustomFiles);
    }
  }

  Future<void> saveCustomFilePaths(List<String> paths) async {
    _memoryCustomFiles = List.from(paths);
    try {
      await _scanFoldersBox.put('custom_files', paths);
    } catch (_) {}
  }

  Future<void> addCustomFilePaths(List<String> paths) async {
    final current = getCustomFilePaths();
    final updated = {...current, ...paths}.toList();
    await saveCustomFilePaths(updated);
  }

  // --- Song Metadata Cache (Fast Startup & Incremental Rescan) ---
  Map<String, Map<String, dynamic>> getCachedSongEntries() {
    if (_songsCacheBox != null && _songsCacheBox!.isOpen) {
      try {
        final result = <String, Map<String, dynamic>>{};
        for (final key in _songsCacheBox!.keys) {
          final val = _songsCacheBox!.get(key);
          if (val is Map) {
            result[key.toString()] = Map<String, dynamic>.from(val);
          }
        }
        return result;
      } catch (_) {}
    }
    return Map.from(_memorySongsCache);
  }

  Future<void> saveCachedSongEntries(Map<String, Map<String, dynamic>> entries) async {
    _memorySongsCache.addAll(entries);
    if (_songsCacheBox != null && _songsCacheBox!.isOpen) {
      try {
        await _songsCacheBox!.putAll(entries);
      } catch (_) {}
    }
  }

  Future<void> removeCachedSongEntries(Iterable<String> keys) async {
    for (final k in keys) {
      _memorySongsCache.remove(k);
    }
    if (_songsCacheBox != null && _songsCacheBox!.isOpen) {
      try {
        await _songsCacheBox!.deleteAll(keys);
      } catch (_) {}
    }
  }

  Future<void> clearCachedSongs() async {
    _memorySongsCache.clear();
    if (_songsCacheBox != null && _songsCacheBox!.isOpen) {
      try {
        await _songsCacheBox!.clear();
      } catch (_) {}
    }
  }

  // --- Equalizer ---
  bool isEqualizerEnabled() {
    return _settingsBox.get(AppConstants.keyEqualizerEnabled, defaultValue: false) as bool;
  }

  Future<void> setEqualizerEnabled(bool enabled) async {
    await _settingsBox.put(AppConstants.keyEqualizerEnabled, enabled);
  }

  String getEqualizerPreset() {
    return _settingsBox.get(AppConstants.keyEqualizerPreset, defaultValue: 'Normal') as String;
  }

  Future<void> setEqualizerPreset(String preset) async {
    await _settingsBox.put(AppConstants.keyEqualizerPreset, preset);
  }

  List<double> getEqualizerBands() {
    final list = _settingsBox.get('equalizer_bands', defaultValue: [0.0, 0.0, 0.0, 0.0, 0.0]) as List;
    return list.map((e) => (e as num).toDouble()).toList();
  }

  Future<void> setEqualizerBands(List<double> bands) async {
    await _settingsBox.put('equalizer_bands', bands);
  }

  // --- Dolby Atmos & Spatial Audio ---
  bool isSpatialAudioEnabled({bool defaultValue = false}) {
    try {
      return _settingsBox.get(AppConstants.keySpatialAudioEnabled, defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setSpatialAudioEnabled(bool enabled) async {
    try {
      await _settingsBox.put(AppConstants.keySpatialAudioEnabled, enabled);
    } catch (_) {}
  }

  int getSpatialAudioStrength({int defaultValue = 1000}) {
    try {
      return (_settingsBox.get(AppConstants.keySpatialAudioStrength, defaultValue: defaultValue) as num).toInt();
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setSpatialAudioStrength(int strength) async {
    try {
      await _settingsBox.put(AppConstants.keySpatialAudioStrength, strength);
    } catch (_) {}
  }

  String getSpatialAudioMode({String defaultValue = 'binaural'}) {
    try {
      return _settingsBox.get(AppConstants.keySpatialAudioMode, defaultValue: defaultValue) as String;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setSpatialAudioMode(String mode) async {
    try {
      await _settingsBox.put(AppConstants.keySpatialAudioMode, mode);
    } catch (_) {}
  }

  String getSpatialReverbPreset({String defaultValue = 'studio'}) {
    try {
      return _settingsBox.get(AppConstants.keySpatialReverbPreset, defaultValue: defaultValue) as String;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setSpatialReverbPreset(String preset) async {
    try {
      await _settingsBox.put(AppConstants.keySpatialReverbPreset, preset);
    } catch (_) {}
  }

  // --- MiniPlayer Cover Art Appearance ---
  String getMiniPlayerArtStyle({String defaultValue = 'box'}) {
    return _settingsBox.get('mini_player_art_style', defaultValue: defaultValue) as String;
  }

  Future<void> setMiniPlayerArtStyle(String style) async {
    await _settingsBox.put('mini_player_art_style', style);
  }

  bool isMiniPlayerVinylRotating({bool defaultValue = true}) {
    return _settingsBox.get('mini_player_vinyl_rotating', defaultValue: defaultValue) as bool;
  }

  Future<void> setMiniPlayerVinylRotating(bool rotating) async {
    await _settingsBox.put('mini_player_vinyl_rotating', rotating);
  }

  // --- Now Playing Cover Art Appearance ---
  String getNowPlayingArtStyle({String defaultValue = 'box'}) {
    return _settingsBox.get('now_playing_art_style', defaultValue: defaultValue) as String;
  }

  Future<void> setNowPlayingArtStyle(String style) async {
    await _settingsBox.put('now_playing_art_style', style);
  }

  bool isNowPlayingVinylRotating({bool defaultValue = true}) {
    return _settingsBox.get('now_playing_vinyl_rotating', defaultValue: defaultValue) as bool;
  }

  Future<void> setNowPlayingVinylRotating(bool rotating) async {
    await _settingsBox.put('now_playing_vinyl_rotating', rotating);
  }

  // --- Synchronized LRC Lyrics Settings ---
  bool isOnlineLyricsEnabled({bool defaultValue = true}) {
    return _settingsBox.get('online_lyrics_enabled', defaultValue: defaultValue) as bool;
  }

  Future<void> setOnlineLyricsEnabled(bool enabled) async {
    await _settingsBox.put('online_lyrics_enabled', enabled);
  }

  String? getLocalLrcFolderPath() {
    return _settingsBox.get('local_lrc_folder_path') as String?;
  }

  Future<void> setLocalLrcFolderPath(String? path) async {
    if (path == null) {
      await _settingsBox.delete('local_lrc_folder_path');
    } else {
      await _settingsBox.put('local_lrc_folder_path', path);
    }
  }

  bool isPrioritizeSyllableLyrics({bool defaultValue = true}) {
    return _settingsBox.get('prioritize_syllable_lyrics', defaultValue: defaultValue) as bool;
  }

  Future<void> setPrioritizeSyllableLyrics(bool prioritize) async {
    await _settingsBox.put('prioritize_syllable_lyrics', prioritize);
  }

  List<String> getEnabledLyricSources() {
    final defaultSources = [
      'LyricsPlus',
      'PaxSenix',
      'BetterLyrics',
      'SimpMusic',
      'KuGou',
      'LRCLIB',
      'Musixmatch',
    ];
    final list = _settingsBox.get('enabled_lyric_sources', defaultValue: defaultSources) as List;
    return list.map((e) => e.toString()).toList();
  }

  Future<void> setEnabledLyricSources(List<String> sources) async {
    await _settingsBox.put('enabled_lyric_sources', sources);
  }

  // --- Playlist Playback Settings (Shuffle & Loop) ---
  final Map<String, Map<String, dynamic>> _inMemoryPlaylistSettings = {};

  Map<String, dynamic> getPlaylistPlaybackSettings(String playlistId) {
    try {
      final data = _playlistsBox.get('playback_settings_$playlistId');
      if (data is Map) {
        final result = Map<String, dynamic>.from(data);
        _inMemoryPlaylistSettings[playlistId] = result;
        return result;
      }
    } catch (_) {}
    return _inMemoryPlaylistSettings[playlistId] ?? {'isShuffle': false, 'loopMode': 'off'};
  }

  Future<void> savePlaylistPlaybackSettings(
    String playlistId, {
    required bool isShuffle,
    required String loopMode,
  }) async {
    _inMemoryPlaylistSettings[playlistId] = {
      'isShuffle': isShuffle,
      'loopMode': loopMode,
    };
    try {
      await _playlistsBox.put('playback_settings_$playlistId', {
        'isShuffle': isShuffle,
        'loopMode': loopMode,
      });
    } catch (_) {}
  }

  // --- Preserved Playback State (Mini Player & Now Playing) ---
  Map<String, dynamic>? getSavedPlaybackState() {
    try {
      final raw = _settingsBox.get('saved_playback_state');
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {}
    return null;
  }

  Future<void> savePlaybackState({
    required Song currentSong,
    required Duration position,
    required List<Song> queue,
    required List<Song> originalQueue,
    required int currentIndex,
    required bool isShuffle,
    required String loopMode,
    String? playlistId,
  }) async {
    try {
      await _settingsBox.put('saved_playback_state', {
        'song': currentSong.toMap(),
        'positionMs': position.inMilliseconds,
        'queue': queue.take(500).map((s) => s.toMap()).toList(),
        'originalQueue': originalQueue.take(500).map((s) => s.toMap()).toList(),
        'currentIndex': currentIndex,
        'isShuffle': isShuffle,
        'loopMode': loopMode,
        'playlistId': playlistId,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {}
  }

  Future<void> savePlaybackPosition(Duration position) async {
    try {
      final state = getSavedPlaybackState();
      if (state != null) {
        state['positionMs'] = position.inMilliseconds;
        state['savedAt'] = DateTime.now().millisecondsSinceEpoch;
        await _settingsBox.put('saved_playback_state', state);
      }
    } catch (_) {}
  }

  Future<void> clearSavedPlaybackState() async {
    try {
      await _settingsBox.delete('saved_playback_state');
    } catch (_) {}
  }

  bool isNowPlayingDrawerOpen({bool defaultValue = false}) {
    try {
      return _settingsBox.get('now_playing_drawer_open', defaultValue: defaultValue) as bool;
    } catch (_) {
      return defaultValue;
    }
  }

  Future<void> setNowPlayingDrawerOpen(bool isOpen) async {
    try {
      await _settingsBox.put('now_playing_drawer_open', isOpen);
    } catch (_) {}
  }
}

