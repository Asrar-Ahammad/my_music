import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import 'equalizer_provider.dart';

class OnboardingNotifier extends Notifier<bool> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  bool build() {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.isOnboardingCompleted();
  }

  /// Permanently complete onboarding and persist flag in storage
  Future<void> completeOnboarding() async {
    state = true;
    await _repository.setOnboardingCompleted(true);
  }

  /// Reset onboarding (e.g. to replay the tutorial from settings)
  Future<void> resetOnboarding() async {
    state = false;
    await _repository.setOnboardingCompleted(false);
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);
