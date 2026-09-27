import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import 'equalizer_provider.dart';
export 'theme_style_provider.dart' show AppThemeMode, themeModeProvider;

class ThemeNotifier extends Notifier<bool> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  bool build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.isDarkMode();
  }

  Future<void> toggleTheme() async {
    state = !state;
    await _repository.setDarkMode(state);
  }

  Future<void> setDarkMode(bool isDark) async {
    state = isDark;
    await _repository.setDarkMode(isDark);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);
