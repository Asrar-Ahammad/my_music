import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import 'equalizer_provider.dart';

class PaletteState {
  final String darkPaletteId;
  final String lightPaletteId;

  const PaletteState({
    required this.darkPaletteId,
    required this.lightPaletteId,
  });

  PaletteState copyWith({
    String? darkPaletteId,
    String? lightPaletteId,
  }) {
    return PaletteState(
      darkPaletteId: darkPaletteId ?? this.darkPaletteId,
      lightPaletteId: lightPaletteId ?? this.lightPaletteId,
    );
  }
}

class PaletteNotifier extends Notifier<PaletteState> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  PaletteState build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return PaletteState(
      darkPaletteId: repo.getDarkPalette(),
      lightPaletteId: repo.getLightPalette(),
    );
  }

  Future<void> setDarkPalette(String id) async {
    state = state.copyWith(darkPaletteId: id);
    await _repository.setDarkPalette(id);
  }

  Future<void> setLightPalette(String id) async {
    state = state.copyWith(lightPaletteId: id);
    await _repository.setLightPalette(id);
  }
}

final paletteProvider = NotifierProvider<PaletteNotifier, PaletteState>(PaletteNotifier.new);
