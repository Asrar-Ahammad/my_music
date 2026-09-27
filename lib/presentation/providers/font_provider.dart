import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/retro_typography.dart';
import '../../data/repositories/settings_repository.dart';
import 'equalizer_provider.dart';

class FontNotifier extends Notifier<String> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  String build() {
    final repo = ref.watch(settingsRepositoryProvider);
    final savedFont = repo.getAppFont();
    RetroTypography.setFontFamily(savedFont);
    return RetroTypography.currentFontFamily;
  }

  Future<void> setFont(String fontId) async {
    RetroTypography.setFontFamily(fontId);
    state = RetroTypography.currentFontFamily;
    await _repository.setAppFont(state);
  }
}

final fontProvider = NotifierProvider<FontNotifier, String>(FontNotifier.new);
