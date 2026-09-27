import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/audio_player_handler.dart';
import 'player_provider.dart';

class EqualizerState {
  final bool isEnabled;
  final String currentPreset;
  final List<double> bandGains; // 5 bands in dB (-10 to +10)

  const EqualizerState({
    this.isEnabled = false,
    this.currentPreset = 'Normal',
    this.bandGains = const [0.0, 0.0, 0.0, 0.0, 0.0],
  });

  EqualizerState copyWith({
    bool? isEnabled,
    String? currentPreset,
    List<double>? bandGains,
  }) {
    return EqualizerState(
      isEnabled: isEnabled ?? this.isEnabled,
      currentPreset: currentPreset ?? this.currentPreset,
      bandGains: bandGains ?? this.bandGains,
    );
  }
}

class EqualizerNotifier extends Notifier<EqualizerState> {
  SettingsRepository get _settingsRepository => ref.read(settingsRepositoryProvider);
  AudioPlayerHandler get _audioHandler => ref.read(audioHandlerProvider);

  static const Map<String, List<double>> presets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    '8-Bit Chiptune': [4.0, -1.0, 2.0, 6.0, 8.0],
    'Bass Boost': [8.0, 5.0, 1.0, 0.0, 0.0],
    'Retro Arcade': [5.0, 2.0, -2.0, 4.0, 6.0],
    'Vocal / Lead': [-2.0, 2.0, 6.0, 3.0, -1.0],
  };

  @override
  EqualizerState build() {
    final settings = ref.watch(settingsRepositoryProvider);
    final handler = ref.watch(audioHandlerProvider);

    final enabled = settings.isEqualizerEnabled();
    final preset = settings.getEqualizerPreset();
    final bands = settings.getEqualizerBands();

    handler.setEqualizerEnabled(enabled);
    handler.applyPreset(bands);

    return EqualizerState(
      isEnabled: enabled,
      currentPreset: preset,
      bandGains: bands,
    );
  }

  Future<void> toggleEnabled(bool enabled) async {
    state = state.copyWith(isEnabled: enabled);
    await _settingsRepository.setEqualizerEnabled(enabled);
    _audioHandler.setEqualizerEnabled(enabled);
  }

  Future<void> setBandGain(int index, double gain) async {
    if (index >= 0 && index < state.bandGains.length) {
      final updated = List<double>.from(state.bandGains);
      updated[index] = gain;
      state = state.copyWith(bandGains: updated, currentPreset: 'Custom');

      await _settingsRepository.setEqualizerBands(updated);
      await _settingsRepository.setEqualizerPreset('Custom');
      _audioHandler.setEqualizerBand(index, gain);
    }
  }

  Future<void> setPreset(String presetName) async {
    final gains = presets[presetName] ?? [0.0, 0.0, 0.0, 0.0, 0.0];
    state = state.copyWith(
      isEnabled: true,
      currentPreset: presetName,
      bandGains: gains,
    );

    await _settingsRepository.setEqualizerEnabled(true);
    await _settingsRepository.setEqualizerPreset(presetName);
    await _settingsRepository.setEqualizerBands(gains);
    _audioHandler.setEqualizerEnabled(true);
    _audioHandler.applyPreset(gains);
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final equalizerProvider = NotifierProvider<EqualizerNotifier, EqualizerState>(EqualizerNotifier.new);
