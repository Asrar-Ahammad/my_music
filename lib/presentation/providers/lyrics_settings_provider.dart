import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/file_scanner_service.dart';
import 'equalizer_provider.dart';
import 'lyrics_provider.dart';

class LyricsSettings {
  final bool onlineLyricsEnabled;
  final String? localLrcFolderPath;
  final bool prioritizeSyllableLyrics;
  final List<String> enabledSources;

  const LyricsSettings({
    required this.onlineLyricsEnabled,
    this.localLrcFolderPath,
    required this.prioritizeSyllableLyrics,
    required this.enabledSources,
  });

  LyricsSettings copyWith({
    bool? onlineLyricsEnabled,
    String? localLrcFolderPath,
    bool clearLocalLrcFolder = false,
    bool? prioritizeSyllableLyrics,
    List<String>? enabledSources,
  }) {
    return LyricsSettings(
      onlineLyricsEnabled: onlineLyricsEnabled ?? this.onlineLyricsEnabled,
      localLrcFolderPath:
          clearLocalLrcFolder ? null : (localLrcFolderPath ?? this.localLrcFolderPath),
      prioritizeSyllableLyrics:
          prioritizeSyllableLyrics ?? this.prioritizeSyllableLyrics,
      enabledSources: enabledSources ?? this.enabledSources,
    );
  }
}

class LyricsSettingsNotifier extends Notifier<LyricsSettings> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  LyricsSettings build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return LyricsSettings(
      onlineLyricsEnabled: repo.isOnlineLyricsEnabled(),
      localLrcFolderPath: repo.getLocalLrcFolderPath(),
      prioritizeSyllableLyrics: repo.isPrioritizeSyllableLyrics(),
      enabledSources: repo.getEnabledLyricSources(),
    );
  }

  Future<void> setOnlineLyricsEnabled(bool enabled) async {
    state = state.copyWith(onlineLyricsEnabled: enabled);
    await _repository.setOnlineLyricsEnabled(enabled);
    ref.read(lyricsProvider.notifier).refreshLyrics();
  }

  Future<void> setLocalLrcFolderPath(String? path) async {
    final normalized = path != null && path.trim().isNotEmpty
        ? FileScannerService.normalizeFolderPath(path.trim())
        : null;
    state = state.copyWith(
      localLrcFolderPath: normalized,
      clearLocalLrcFolder: normalized == null,
    );
    await _repository.setLocalLrcFolderPath(normalized);
    ref.read(lyricsProvider.notifier).refreshLyrics();
  }

  Future<void> setPrioritizeSyllableLyrics(bool prioritize) async {
    state = state.copyWith(prioritizeSyllableLyrics: prioritize);
    await _repository.setPrioritizeSyllableLyrics(prioritize);
    ref.read(lyricsProvider.notifier).refreshLyrics();
  }

  Future<void> toggleSource(String source, bool enabled) async {
    final list = List<String>.from(state.enabledSources);
    if (enabled && !list.contains(source)) {
      list.add(source);
    } else if (!enabled && list.contains(source)) {
      list.remove(source);
    }
    state = state.copyWith(enabledSources: list);
    await _repository.setEnabledLyricSources(list);
    ref.read(lyricsProvider.notifier).refreshLyrics();
  }
}

final lyricsSettingsProvider =
    NotifierProvider<LyricsSettingsNotifier, LyricsSettings>(
  LyricsSettingsNotifier.new,
);
