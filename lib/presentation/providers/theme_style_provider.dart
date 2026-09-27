import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import 'equalizer_provider.dart';

/// Which top-level visual design system / theme mode is active.
enum AppThemeMode {
  retro, // 8-bit arcade aesthetic (PressStart2P, chunky borders)
}

typedef AppThemeStyle = AppThemeMode;

extension AppThemeStyleX on AppThemeMode {
  String get id => name;
  bool get isRetro => true;
  bool get isNothing => false;

  static AppThemeMode fromId(String id) => AppThemeMode.retro;
}

class ThemeStyleNotifier extends Notifier<AppThemeMode> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  AppThemeMode build() {
    return AppThemeMode.retro;
  }

  Future<void> setStyle(AppThemeMode style) async {
    state = AppThemeMode.retro;
    await _repository.setThemeStyle('retro');
  }

  Future<void> toggleStyle() async {
    state = AppThemeMode.retro;
  }
}

final themeStyleProvider =
    NotifierProvider<ThemeStyleNotifier, AppThemeMode>(ThemeStyleNotifier.new);

/// Alias provider for consumers/tests referencing [themeModeProvider].
final themeModeProvider = themeStyleProvider;
