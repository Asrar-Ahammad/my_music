import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import 'equalizer_provider.dart';

enum MiniPlayerArtStyle {
  box,
  vinyl,
  cassette;

  static MiniPlayerArtStyle fromString(String val) {
    final lower = val.toLowerCase();
    if (lower == 'vinyl') return MiniPlayerArtStyle.vinyl;
    if (lower == 'cassette') return MiniPlayerArtStyle.cassette;
    return MiniPlayerArtStyle.box;
  }
}

class MiniPlayerArtSettings {
  final MiniPlayerArtStyle style;
  final bool isRotating;

  const MiniPlayerArtSettings({
    required this.style,
    required this.isRotating,
  });

  MiniPlayerArtSettings copyWith({
    MiniPlayerArtStyle? style,
    bool? isRotating,
  }) {
    return MiniPlayerArtSettings(
      style: style ?? this.style,
      isRotating: isRotating ?? this.isRotating,
    );
  }
}

class MiniPlayerArtSettingsNotifier extends Notifier<MiniPlayerArtSettings> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  MiniPlayerArtSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return MiniPlayerArtSettings(
      style: MiniPlayerArtStyle.fromString(repo.getMiniPlayerArtStyle()),
      isRotating: repo.isMiniPlayerVinylRotating(),
    );
  }

  Future<void> setStyle(MiniPlayerArtStyle style) async {
    state = state.copyWith(style: style);
    await _repository.setMiniPlayerArtStyle(style.name);
  }

  Future<void> setRotating(bool isRotating) async {
    state = state.copyWith(isRotating: isRotating);
    await _repository.setMiniPlayerVinylRotating(isRotating);
  }
}

final miniPlayerArtSettingsProvider =
    NotifierProvider<MiniPlayerArtSettingsNotifier, MiniPlayerArtSettings>(
  MiniPlayerArtSettingsNotifier.new,
);
