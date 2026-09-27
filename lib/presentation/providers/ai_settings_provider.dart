import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ai_model_config.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/services/huggingface_model_manager.dart';
import 'equalizer_provider.dart';

class SingleModelUiState {
  final AiModelInfo model;
  final AiModelDownloadState state;
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? errorMessage;

  const SingleModelUiState({
    required this.model,
    this.state = AiModelDownloadState.notDownloaded,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.errorMessage,
  });

  bool get isReady => state == AiModelDownloadState.ready;
  bool get isDownloading => state == AiModelDownloadState.downloading;

  SingleModelUiState copyWith({
    AiModelDownloadState? state,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? errorMessage,
  }) {
    return SingleModelUiState(
      model: model,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class AiSettingsState {
  final bool isAiEnabled;
  final Map<String, SingleModelUiState> models;
  final int totalStorageBytes;
  final bool isLoading;

  const AiSettingsState({
    this.isAiEnabled = false,
    this.models = const {},
    this.totalStorageBytes = 0,
    this.isLoading = false,
  });

  SingleModelUiState getModel(String id) {
    return models[id] ??
        SingleModelUiState(
          model: AiModelConfig.getById(id) ?? AiModelConfig.smolLm135m,
        );
  }

  bool get isSmolLmReady => getModel(AiModelConfig.smolLm135m.id).isReady;

  String get formattedTotalStorage => HuggingFaceModelManager.formatBytes(totalStorageBytes);

  AiSettingsState copyWith({
    bool? isAiEnabled,
    Map<String, SingleModelUiState>? models,
    int? totalStorageBytes,
    bool? isLoading,
  }) {
    return AiSettingsState(
      isAiEnabled: isAiEnabled ?? this.isAiEnabled,
      models: models ?? this.models,
      totalStorageBytes: totalStorageBytes ?? this.totalStorageBytes,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AiSettingsNotifier extends Notifier<AiSettingsState> {
  SettingsRepository get _settingsRepository => ref.read(settingsRepositoryProvider);
  final HuggingFaceModelManager _modelManager = HuggingFaceModelManager();
  final Map<String, StreamSubscription<ModelDownloadProgress>> _subscriptions = {};

  @override
  AiSettingsState build() {
    ref.onDispose(() {
      for (final sub in _subscriptions.values) {
        sub.cancel();
      }
    });

    Future.microtask(() => _init());
    return const AiSettingsState(isLoading: true);
  }

  Future<void> _init() async {
    final isEnabled = _settingsRepository.isAiFeaturesEnabled();
    final Map<String, SingleModelUiState> initialModels = {};

    for (final model in AiModelConfig.allModels) {
      final isDownloaded = await _modelManager.isModelDownloaded(model);
      final size = isDownloaded ? await _modelManager.getModelSizeBytes(model) : 0;
      initialModels[model.id] = SingleModelUiState(
        model: model,
        state: isDownloaded ? AiModelDownloadState.ready : AiModelDownloadState.notDownloaded,
        progress: isDownloaded ? 1.0 : 0.0,
        downloadedBytes: size,
        totalBytes: isDownloaded ? size : model.expectedSizeBytes,
      );
    }

    final totalUsage = await _modelManager.getTotalAiStorageUsage();

    state = AiSettingsState(
      isAiEnabled: isEnabled,
      models: initialModels,
      totalStorageBytes: totalUsage,
      isLoading: false,
    );
  }

  Future<void> toggleAiEnabled() async {
    final newValue = !state.isAiEnabled;
    await _settingsRepository.setAiFeaturesEnabled(newValue);
    state = state.copyWith(isAiEnabled: newValue);
  }

  Future<void> refresh() async {
    await _init();
  }

  Future<void> downloadModel(AiModelInfo model) async {
    final current = state.models[model.id] ?? SingleModelUiState(model: model);
    if (current.isDownloading) return;

    final updatedModels = Map<String, SingleModelUiState>.from(state.models);
    updatedModels[model.id] = current.copyWith(
      state: AiModelDownloadState.downloading,
      progress: 0.0,
      errorMessage: null,
    );
    state = state.copyWith(models: updatedModels);

    _subscriptions[model.id]?.cancel();
    _subscriptions[model.id] = _modelManager.getProgressStream(model.id).listen((progressEvent) {
      final m = state.models[model.id];
      if (m == null) return;

      final updated = Map<String, SingleModelUiState>.from(state.models);
      if (progressEvent.isCompleted) {
        updated[model.id] = m.copyWith(
          state: AiModelDownloadState.ready,
          progress: 1.0,
          downloadedBytes: progressEvent.bytesDownloaded,
          totalBytes: progressEvent.totalBytes,
          errorMessage: null,
        );
      } else if (progressEvent.error != null) {
        updated[model.id] = m.copyWith(
          state: AiModelDownloadState.error,
          progress: 0.0,
          errorMessage: progressEvent.error,
        );
      } else {
        updated[model.id] = m.copyWith(
          state: AiModelDownloadState.downloading,
          progress: progressEvent.progress,
          downloadedBytes: progressEvent.bytesDownloaded,
          totalBytes: progressEvent.totalBytes,
        );
      }
      state = state.copyWith(models: updated);
    });

    final success = await _modelManager.downloadModel(model);
    final totalBytes = await _modelManager.getTotalAiStorageUsage();

    final finalMap = Map<String, SingleModelUiState>.from(state.models);
    if (success) {
      final size = await _modelManager.getModelSizeBytes(model);
      finalMap[model.id] = SingleModelUiState(
        model: model,
        state: AiModelDownloadState.ready,
        progress: 1.0,
        downloadedBytes: size,
        totalBytes: size,
      );
    } else {
      if (finalMap[model.id]?.state != AiModelDownloadState.error) {
        finalMap[model.id] = finalMap[model.id]?.copyWith(
          state: AiModelDownloadState.notDownloaded,
          progress: 0.0,
        ) ?? SingleModelUiState(model: model);
      }
    }
    state = state.copyWith(models: finalMap, totalStorageBytes: totalBytes);
  }

  void cancelDownload(String modelId) {
    _modelManager.cancelDownload(modelId);
    final current = state.models[modelId];
    if (current != null) {
      final updated = Map<String, SingleModelUiState>.from(state.models);
      updated[modelId] = current.copyWith(
        state: AiModelDownloadState.notDownloaded,
        progress: 0.0,
      );
      state = state.copyWith(models: updated);
    }
  }

  Future<void> deleteModel(AiModelInfo model) async {
    _modelManager.cancelDownload(model.id);
    await _modelManager.deleteModel(model);
    final totalUsage = await _modelManager.getTotalAiStorageUsage();

    final updated = Map<String, SingleModelUiState>.from(state.models);
    updated[model.id] = SingleModelUiState(
      model: model,
      state: AiModelDownloadState.notDownloaded,
      progress: 0.0,
      downloadedBytes: 0,
      totalBytes: model.expectedSizeBytes,
    );
    state = state.copyWith(models: updated, totalStorageBytes: totalUsage);
  }

  Future<void> deleteAllModels() async {
    for (final model in AiModelConfig.allModels) {
      _modelManager.cancelDownload(model.id);
    }
    await _modelManager.deleteAllModels();
    final updated = <String, SingleModelUiState>{};
    for (final model in AiModelConfig.allModels) {
      updated[model.id] = SingleModelUiState(
        model: model,
        state: AiModelDownloadState.notDownloaded,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: model.expectedSizeBytes,
      );
    }
    state = state.copyWith(models: updated, totalStorageBytes: 0);
  }
}

final aiSettingsProvider = NotifierProvider<AiSettingsNotifier, AiSettingsState>(AiSettingsNotifier.new);
