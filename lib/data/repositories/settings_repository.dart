import '../services/storage_service.dart';
import '../../presentation/providers/theme_style_provider.dart' show AppThemeMode;
export '../../presentation/providers/theme_style_provider.dart' show AppThemeMode;

class SettingsRepository {
  final StorageService _storageService;

  SettingsRepository({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  bool isDarkMode() => _storageService.isDarkMode(defaultValue: false);

  Future<void> setDarkMode(bool isDark) => _storageService.setDarkMode(isDark);

  bool isOnboardingCompleted() => _storageService.isOnboardingCompleted();

  Future<void> setOnboardingCompleted(bool completed) =>
      _storageService.setOnboardingCompleted(completed);

  String getDarkPalette() => _storageService.getDarkPalette();

  Future<void> setDarkPalette(String id) => _storageService.setDarkPalette(id);

  String getLightPalette() => _storageService.getLightPalette();

  Future<void> setLightPalette(String id) => _storageService.setLightPalette(id);

  String getAppFont() => _storageService.getAppFont();

  Future<void> setAppFont(String fontId) => _storageService.setAppFont(fontId);

  String getThemeStyle() => _storageService.getThemeStyle();

  Future<void> setThemeStyle(String style) => _storageService.setThemeStyle(style);

  AppThemeMode getThemeMode() => AppThemeMode.values.firstWhere(
        (m) => m.name == _storageService.getThemeStyle(),
        orElse: () => AppThemeMode.retro,
      );

  Future<void> setThemeMode(AppThemeMode mode) => _storageService.setThemeStyle(mode.name);


  bool isAiFeaturesEnabled() => _storageService.isAiFeaturesEnabled();

  Future<void> setAiFeaturesEnabled(bool enabled) =>
      _storageService.setAiFeaturesEnabled(enabled);


  // --- Library Auto-Tagger ---
  bool isAutoTaggerEnabled() => _storageService.isAutoTaggerEnabled();
  Future<void> setAutoTaggerEnabled(bool enabled) =>
      _storageService.setAutoTaggerEnabled(enabled);

  bool isPlaylistGridView() => _storageService.isPlaylistGridView();

  Future<void> setPlaylistGridView(bool isGrid) => _storageService.setPlaylistGridView(isGrid);

  bool isAlbumGridView() => _storageService.isAlbumGridView();

  Future<void> setAlbumGridView(bool isGrid) => _storageService.setAlbumGridView(isGrid);

  bool isArtistGridView() => _storageService.isArtistGridView();

  Future<void> setArtistGridView(bool isGrid) => _storageService.setArtistGridView(isGrid);

  List<Map<String, dynamic>> getRecentlyPlayed() => _storageService.getRecentlyPlayed();

  Future<void> saveRecentlyPlayed(List<Map<String, dynamic>> items) =>
      _storageService.saveRecentlyPlayed(items);

  List<String> getScanFolders() => _storageService.getScanFolders();

  Future<void> addScanFolder(String folder) async {
    final list = _storageService.getScanFolders();
    if (!list.contains(folder)) {
      list.add(folder);
      await _storageService.saveScanFolders(list);
    }
  }

  Future<void> removeScanFolder(String folder) async {
    final list = _storageService.getScanFolders();
    list.remove(folder);
    await _storageService.saveScanFolders(list);
  }

  Future<void> clearAllScanFolders() async {
    await _storageService.saveScanFolders([]);
    await _storageService.saveCustomFilePaths([]);
  }

  bool isFetchAllAudio() => _storageService.isFetchAllAudio();

  Future<void> setFetchAllAudio(bool enabled) => _storageService.setFetchAllAudio(enabled);

  bool isEqualizerEnabled() => _storageService.isEqualizerEnabled();

  Future<void> setEqualizerEnabled(bool enabled) => _storageService.setEqualizerEnabled(enabled);

  String getEqualizerPreset() => _storageService.getEqualizerPreset();

  Future<void> setEqualizerPreset(String preset) => _storageService.setEqualizerPreset(preset);

  List<double> getEqualizerBands() => _storageService.getEqualizerBands();

  Future<void> setEqualizerBands(List<double> bands) => _storageService.setEqualizerBands(bands);

  String getMiniPlayerArtStyle() => _storageService.getMiniPlayerArtStyle();

  Future<void> setMiniPlayerArtStyle(String style) =>
      _storageService.setMiniPlayerArtStyle(style);

  bool isMiniPlayerVinylRotating() => _storageService.isMiniPlayerVinylRotating();

  Future<void> setMiniPlayerVinylRotating(bool rotating) =>
      _storageService.setMiniPlayerVinylRotating(rotating);

  String getNowPlayingArtStyle() => _storageService.getNowPlayingArtStyle();

  Future<void> setNowPlayingArtStyle(String style) =>
      _storageService.setNowPlayingArtStyle(style);

  bool isNowPlayingVinylRotating() => _storageService.isNowPlayingVinylRotating();

  Future<void> setNowPlayingVinylRotating(bool rotating) =>
      _storageService.setNowPlayingVinylRotating(rotating);

  // --- LRC Lyrics Settings ---
  bool isOnlineLyricsEnabled() => _storageService.isOnlineLyricsEnabled();

  Future<void> setOnlineLyricsEnabled(bool enabled) =>
      _storageService.setOnlineLyricsEnabled(enabled);

  String? getLocalLrcFolderPath() => _storageService.getLocalLrcFolderPath();

  Future<void> setLocalLrcFolderPath(String? path) =>
      _storageService.setLocalLrcFolderPath(path);

  bool isPrioritizeSyllableLyrics() => _storageService.isPrioritizeSyllableLyrics();

  Future<void> setPrioritizeSyllableLyrics(bool prioritize) =>
      _storageService.setPrioritizeSyllableLyrics(prioritize);

  List<String> getEnabledLyricSources() => _storageService.getEnabledLyricSources();

  Future<void> setEnabledLyricSources(List<String> sources) =>
      _storageService.setEnabledLyricSources(sources);

  // --- Dolby Atmos & Spatial Audio ---
  bool isSpatialAudioEnabled() => _storageService.isSpatialAudioEnabled();
  Future<void> setSpatialAudioEnabled(bool enabled) => _storageService.setSpatialAudioEnabled(enabled);

  int getSpatialAudioStrength() => _storageService.getSpatialAudioStrength();
  Future<void> setSpatialAudioStrength(int strength) => _storageService.setSpatialAudioStrength(strength);

  String getSpatialAudioMode() => _storageService.getSpatialAudioMode();
  Future<void> setSpatialAudioMode(String mode) => _storageService.setSpatialAudioMode(mode);

  String getSpatialReverbPreset() => _storageService.getSpatialReverbPreset();
  Future<void> setSpatialReverbPreset(String preset) => _storageService.setSpatialReverbPreset(preset);
}
