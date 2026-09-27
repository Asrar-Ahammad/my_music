/// Global constants for Retro Music Player
class AppConstants {
  AppConstants._();

  static const String appName = "MyMusic";
  static const String appVersion = "2.1.0";
  static const String appTagline = "OFFLINE HI-RES AUDIO";

  // Hive Box Names
  static const String settingsBox = "retro_settings_box";
  static const String playlistsBox = "retro_playlists_box";
  static const String favoritesBox = "retro_favorites_box";
  static const String scanFoldersBox = "retro_scan_folders_box";
  static const String songsCacheBox = "retro_songs_cache_box";

  // Setting keys
  static const String keyDarkMode = "is_dark_mode";
  static const String keyScanFolders = "scan_folders";
  static const String keyEqualizerEnabled = "equalizer_enabled";
  static const String keyEqualizerPreset = "equalizer_preset";
  static const String keyOnboardingCompleted = "onboarding_completed";
  static const String keyFetchAllAudio = "fetch_all_audio";
  static const String keySpatialAudioEnabled = "spatial_audio_enabled";
  static const String keySpatialAudioStrength = "spatial_audio_strength";
  static const String keySpatialAudioMode = "spatial_audio_mode";
  static const String keySpatialReverbPreset = "spatial_reverb_preset";
  static const String keyAppFont = "app_font";
  static const String defaultAppFont = "PressStart2P";
  static const String keyThemeStyle = "theme_style"; // 'retro' | 'nothing'
  static const String defaultThemeStyle = "retro";

  // On-Device AI keys
  static const String keyAiFeaturesEnabled = "ai_features_enabled";
  static const String keyAutoAlignLyrics = "ai_auto_align_lyrics";

  // Library Auto-Tagger keys
  static const String keyAutoTaggerEnabled = "ai_auto_tagger_enabled";
  static const String aiSongTagsBox = "ai_song_tags_box";

  // Bundled 8-bit tracks
  static const List<Map<String, String>> sampleTracks = [
    {
      'id': 'bundled_track_1',
      'title': 'Chiptune Quest',
      'artist': 'Pixel Hero',
      'album': 'Overworld Odyssey',
      'assetPath': 'assets/audio/chiptune_quest.wav',
      'artAsset': 'assets/album_art/retro_quest.svg',
      'durationSec': '16',
      'format': 'WAV',
      'bitDepth': '16',
      'sampleRate': '44100',
    },
    {
      'id': 'bundled_track_2',
      'title': 'Arcade Rush',
      'artist': 'Synth Samurai',
      'album': 'Neon Stage 1',
      'assetPath': 'assets/audio/arcade_rush.wav',
      'artAsset': 'assets/album_art/arcade_rush.svg',
      'durationSec': '14',
      'format': 'WAV',
      'bitDepth': '16',
      'sampleRate': '48000',
    },
    {
      'id': 'bundled_track_3',
      'title': 'Neon Dungeon Synth (24b/96k)',
      'artist': 'Retro Mage',
      'album': 'Hi-Res Crypt',
      'assetPath': 'assets/audio/neon_dungeon_hi_res.wav',
      'artAsset': 'assets/album_art/neon_dungeon.svg',
      'durationSec': '12',
      'format': 'WAV 24b/96k',
      'bitDepth': '24',
      'sampleRate': '96000',
    },
  ];
}
