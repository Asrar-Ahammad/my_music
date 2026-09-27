import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/audio_player_handler.dart';
import '../../data/services/spatial_audio_service.dart';
import 'equalizer_provider.dart';
import 'player_provider.dart';

class SpatialAudioPreset {
  final String id;
  final String title;
  final String subtitle;
  final String mode;
  final int strength;
  final double width;
  final double depth;
  final String icon;

  const SpatialAudioPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.strength,
    required this.width,
    required this.depth,
    required this.icon,
  });
}

class SpatialAudioState {
  final bool isEnabled;
  final int strength; // 0 to 1000
  final String mode; // 'binaural', 'transaural', 'auto'
  final String currentPreset;
  final double soundstageWidth; // 0.0 to 1.0
  final double soundstageDepth; // 0.0 to 1.0
  final SpatialAudioCapabilities capabilities;

  const SpatialAudioState({
    this.isEnabled = false,
    this.strength = 1000,
    this.mode = 'binaural',
    this.currentPreset = 'DOLBY ATMOS CINEMA',
    this.soundstageWidth = 1.0,
    this.soundstageDepth = 0.9,
    this.capabilities = const SpatialAudioCapabilities(),
  });

  SpatialAudioState copyWith({
    bool? isEnabled,
    int? strength,
    String? mode,
    String? currentPreset,
    double? soundstageWidth,
    double? soundstageDepth,
    SpatialAudioCapabilities? capabilities,
  }) {
    return SpatialAudioState(
      isEnabled: isEnabled ?? this.isEnabled,
      strength: strength ?? this.strength,
      mode: mode ?? this.mode,
      currentPreset: currentPreset ?? this.currentPreset,
      soundstageWidth: soundstageWidth ?? this.soundstageWidth,
      soundstageDepth: soundstageDepth ?? this.soundstageDepth,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}

class SpatialAudioNotifier extends Notifier<SpatialAudioState> {
  SettingsRepository get _settingsRepository =>
      ref.read(settingsRepositoryProvider);
  AudioPlayerHandler get _audioHandler => ref.read(audioHandlerProvider);

  static const List<SpatialAudioPreset> presets = [
    SpatialAudioPreset(
      id: 'dolby_cinema',
      title: 'DOLBY ATMOS CINEMA',
      subtitle: 'Full 360° Object-based 3D Virtualization',
      mode: 'binaural',
      strength: 1000,
      width: 1.0,
      depth: 0.95,
      icon: 'preset_cinema',
    ),
    SpatialAudioPreset(
      id: 'binaural_studio',
      title: 'BINAURAL 3D STUDIO',
      subtitle: 'Optimized for IEMs & Hi-Res Headphones',
      mode: 'binaural',
      strength: 850,
      width: 0.85,
      depth: 0.80,
      icon: 'preset_studio',
    ),
    SpatialAudioPreset(
      id: 'transaural_wide',
      title: 'TRANSAURAL WIDE',
      subtitle: 'Cross-talk cancellation for Speakers',
      mode: 'transaural',
      strength: 750,
      width: 0.95,
      depth: 0.60,
      icon: 'preset_transaural',
    ),
    SpatialAudioPreset(
      id: 'holographic_8bit',
      title: 'HOLOGRAPHIC RETRO',
      subtitle: 'Arcade stage depth & stereo expansion',
      mode: 'auto',
      strength: 650,
      width: 0.70,
      depth: 0.70,
      icon: 'preset_holographic',
    ),
  ];

  @override
  SpatialAudioState build() {
    final settings = ref.watch(settingsRepositoryProvider);
    final handler = ref.watch(audioHandlerProvider);

    final enabled = settings.isSpatialAudioEnabled();
    final strength = settings.getSpatialAudioStrength();
    final mode = settings.getSpatialAudioMode();
    final presetName = settings.getSpatialReverbPreset();

    handler.setSpatialAudioEnabled(enabled);
    handler.setSpatialAudioStrength(strength);
    handler.setSpatialAudioMode(mode);

    // Initial query of hardware capabilities
    Future.microtask(() => refreshCapabilities());

    // Find preset parameters if matches
    final matching = presets.firstWhere(
      (p) => p.title == presetName || p.id == presetName,
      orElse: () => presets[0],
    );

    return SpatialAudioState(
      isEnabled: enabled,
      strength: strength,
      mode: mode,
      currentPreset: matching.title,
      soundstageWidth: matching.width,
      soundstageDepth: matching.depth,
    );
  }

  Future<void> refreshCapabilities() async {
    final caps = await _audioHandler.spatialAudioService.queryCapabilities();
    state = state.copyWith(capabilities: caps);
  }

  Future<void> toggleEnabled(bool enabled) async {
    state = state.copyWith(isEnabled: enabled);
    await _settingsRepository.setSpatialAudioEnabled(enabled);
    await _audioHandler.setSpatialAudioEnabled(enabled);
  }

  Future<void> setStrength(int strength) async {
    final clamped = strength.clamp(0, 1000);
    state = state.copyWith(
      strength: clamped,
      currentPreset: 'CUSTOM',
      soundstageWidth: clamped / 1000.0,
    );
    await _settingsRepository.setSpatialAudioStrength(clamped);
    await _settingsRepository.setSpatialReverbPreset('CUSTOM');
    await _audioHandler.setSpatialAudioStrength(clamped);
  }

  Future<void> setMode(String mode) async {
    state = state.copyWith(mode: mode, currentPreset: 'CUSTOM');
    await _settingsRepository.setSpatialAudioMode(mode);
    await _settingsRepository.setSpatialReverbPreset('CUSTOM');
    await _audioHandler.setSpatialAudioMode(mode);
  }

  Future<void> applyPreset(SpatialAudioPreset preset) async {
    state = state.copyWith(
      strength: preset.strength,
      mode: preset.mode,
      currentPreset: preset.title,
      soundstageWidth: preset.width,
      soundstageDepth: preset.depth,
    );
    await _settingsRepository.setSpatialAudioStrength(preset.strength);
    await _settingsRepository.setSpatialAudioMode(preset.mode);
    await _settingsRepository.setSpatialReverbPreset(preset.title);
    await _audioHandler.setSpatialAudioStrength(preset.strength);
    await _audioHandler.setSpatialAudioMode(preset.mode);
  }

  Future<void> updateSoundstage(double width, double depth) async {
    final w = width.clamp(0.1, 1.0);
    final d = depth.clamp(0.1, 1.0);
    final calculatedStrength = (w * 1000).round().clamp(0, 1000);

    state = state.copyWith(
      soundstageWidth: w,
      soundstageDepth: d,
      strength: calculatedStrength,
      currentPreset: 'CUSTOM',
    );
    await _settingsRepository.setSpatialAudioStrength(calculatedStrength);
    await _settingsRepository.setSpatialReverbPreset('CUSTOM');
    await _audioHandler.setSpatialAudioStrength(calculatedStrength);
  }

  Future<bool> openSystemSettings() async {
    return await _audioHandler.spatialAudioService.openSystemSettings();
  }
}

final spatialAudioProvider =
    NotifierProvider<SpatialAudioNotifier, SpatialAudioState>(
  SpatialAudioNotifier.new,
);
