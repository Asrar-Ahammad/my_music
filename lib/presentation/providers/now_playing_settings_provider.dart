import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import 'equalizer_provider.dart';

enum NowPlayingArtStyle {
  box,
  vinyl,
  cassette;

  static NowPlayingArtStyle fromString(String val) {
    final lower = val.toLowerCase();
    if (lower == 'vinyl') return NowPlayingArtStyle.vinyl;
    if (lower == 'cassette') return NowPlayingArtStyle.cassette;
    return NowPlayingArtStyle.box;
  }
}

class NowPlayingArtSettings {
  final NowPlayingArtStyle style;
  final bool isRotating;

  const NowPlayingArtSettings({
    required this.style,
    required this.isRotating,
  });

  NowPlayingArtSettings copyWith({
    NowPlayingArtStyle? style,
    bool? isRotating,
  }) {
    return NowPlayingArtSettings(
      style: style ?? this.style,
      isRotating: isRotating ?? this.isRotating,
    );
  }
}

class NowPlayingArtSettingsNotifier extends Notifier<NowPlayingArtSettings> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  NowPlayingArtSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return NowPlayingArtSettings(
      style: NowPlayingArtStyle.fromString(repo.getNowPlayingArtStyle()),
      isRotating: repo.isNowPlayingVinylRotating(),
    );
  }

  Future<void> setStyle(NowPlayingArtStyle style) async {
    state = state.copyWith(style: style);
    await _repository.setNowPlayingArtStyle(style.name);
  }

  Future<void> setRotating(bool isRotating) async {
    state = state.copyWith(isRotating: isRotating);
    await _repository.setNowPlayingVinylRotating(isRotating);
  }
}

final nowPlayingArtSettingsProvider =
    NotifierProvider<NowPlayingArtSettingsNotifier, NowPlayingArtSettings>(
  NowPlayingArtSettingsNotifier.new,
);
