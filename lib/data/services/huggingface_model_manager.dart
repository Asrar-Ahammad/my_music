import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../core/constants/ai_model_config.dart';

class ModelDownloadProgress {
  final String modelId;
  final int bytesDownloaded;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final bool isCompleted;
  final String? error;

  const ModelDownloadProgress({
    required this.modelId,
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.progress,
    this.isCompleted = false,
    this.error,
  });
}

class HuggingFaceModelManager {
  static final HuggingFaceModelManager _instance = HuggingFaceModelManager._internal();
  factory HuggingFaceModelManager() => _instance;
  HuggingFaceModelManager._internal();

  final Map<String, bool> _cancellationTokens = {};
  final _progressControllers = <String, StreamController<ModelDownloadProgress>>{};

  Stream<ModelDownloadProgress> getProgressStream(String modelId) {
    if (!_progressControllers.containsKey(modelId) || _progressControllers[modelId]!.isClosed) {
      _progressControllers[modelId] = StreamController<ModelDownloadProgress>.broadcast();
    }
    return _progressControllers[modelId]!.stream;
  }

  Future<Directory> getModelsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(appDir.path, AiModelConfig.modelsDirName));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  Future<String> getModelPath(AiModelInfo model) async {
    final dir = await getModelsDirectory();
    return p.join(dir.path, model.fileName);
  }

  Future<bool> isModelDownloaded(AiModelInfo model) async {
    final path = await getModelPath(model);
    final file = File(path);
    if (!await file.exists()) return false;
    final len = await file.length();
    return len > 1024 * 1024;
  }

  Future<int> getModelSizeBytes(AiModelInfo model) async {
    final path = await getModelPath(model);
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  Future<int> getTotalAiStorageUsage() async {
    int total = 0;
    for (final model in AiModelConfig.allModels) {
      total += await getModelSizeBytes(model);
    }
    return total;
  }

  void cancelDownload(String modelId) {
    _cancellationTokens[modelId] = true;
  }

  Future<bool> downloadModel(
    AiModelInfo model, {
    void Function(ModelDownloadProgress)? onProgress,
  }) async {
    _cancellationTokens[model.id] = false;
    final dir = await getModelsDirectory();
    final targetPath = p.join(dir.path, model.fileName);
    final tempPath = '$targetPath.download';
    final tempFile = File(tempPath);

    final streamController = _progressControllers.putIfAbsent(
      model.id,
      () => StreamController<ModelDownloadProgress>.broadcast(),
    );

    const int maxRetries = 3;
    int attempt = 0;
    String? lastError;

    while (attempt < maxRetries) {
      attempt++;
      if (_cancellationTokens[model.id] == true) {
        _handleCancelled(model, streamController, onProgress, tempFile);
        return false;
      }

      HttpClient? client;
      IOSink? sink;

      try {
        int existingBytes = 0;
        if (await tempFile.exists()) {
          existingBytes = await tempFile.length();
        }

        client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 30)
          ..idleTimeout = const Duration(seconds: 60);

        final request = await client.getUrl(Uri.parse(model.huggingFaceUrl));
        request.followRedirects = true;
        request.maxRedirects = 5;
        request.headers.set(HttpHeaders.userAgentHeader, 'myMusic-OfflinePlayer/1.4.0');
        request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');

        // Resume partial download if we already have bytes
        if (existingBytes > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
        }

        final response = await request.close();

        // 416 Range Not Satisfiable: cached temp file was invalid/outdated
        if (response.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
          if (await tempFile.exists()) await tempFile.delete();
          existingBytes = 0;
          continue;
        }

        // 206 Partial Content (resumed), 200 OK (full download)
        final isPartial = response.statusCode == HttpStatus.partialContent;
        if (response.statusCode != HttpStatus.ok && !isPartial) {
          if (await tempFile.exists()) await tempFile.delete();
          throw HttpException('HTTP ${response.statusCode} (${response.reasonPhrase})');
        }

        int totalBytes;
        FileMode writeMode;

        if (isPartial) {
          final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
          if (contentRange != null && contentRange.contains('/')) {
            final totalStr = contentRange.split('/').last;
            totalBytes = int.tryParse(totalStr) ?? (existingBytes + response.contentLength);
          } else {
            totalBytes = existingBytes + response.contentLength;
          }
          writeMode = FileMode.append;
        } else {
          // Server returned full content (200), restart from 0
          existingBytes = 0;
          totalBytes = response.contentLength > 0 ? response.contentLength : model.expectedSizeBytes;
          writeMode = FileMode.write;
        }

        int receivedBytes = existingBytes;
        final activeSink = tempFile.openWrite(mode: writeMode);
        sink = activeSink;

        await for (final chunk in response) {
          if (_cancellationTokens[model.id] == true) {
            await activeSink.close();
            sink = null;
            _handleCancelled(model, streamController, onProgress, tempFile);
            return false;
          }

          activeSink.add(chunk);
          receivedBytes += chunk.length;
          final progress = (receivedBytes / totalBytes).clamp(0.0, 1.0);

          final update = ModelDownloadProgress(
            modelId: model.id,
            bytesDownloaded: receivedBytes,
            totalBytes: totalBytes,
            progress: progress,
          );
          streamController.add(update);
          onProgress?.call(update);
        }

        await activeSink.flush();
        await activeSink.close();
        sink = null;

        // Verify that we got the complete file
        final downloadedLength = await tempFile.length();
        if (downloadedLength < totalBytes * 0.95 && totalBytes > 0) {
          // Incomplete stream, retry to resume missing bytes
          throw const SocketException('Connection closed before complete download');
        }

        // Rename temp file to final target file
        final finalFile = File(targetPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await tempFile.rename(targetPath);

        final completed = ModelDownloadProgress(
          modelId: model.id,
          bytesDownloaded: downloadedLength,
          totalBytes: totalBytes,
          progress: 1.0,
          isCompleted: true,
        );
        streamController.add(completed);
        onProgress?.call(completed);
        return true;
      } catch (e) {
        lastError = _formatCleanErrorMessage(e);
        if (sink != null) {
          try {
            await sink.close();
          } catch (_) {}
        }

        // If user cancelled, don't retry
        if (_cancellationTokens[model.id] == true) {
          _handleCancelled(model, streamController, onProgress, tempFile);
          return false;
        }

        // Pause briefly before retrying
        if (attempt < maxRetries) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
      } finally {
        client?.close(force: true);
      }
    }

    final errProgress = ModelDownloadProgress(
      modelId: model.id,
      bytesDownloaded: 0,
      totalBytes: model.expectedSizeBytes,
      progress: 0.0,
      error: lastError ?? 'Download interrupted. Tap to retry.',
    );
    streamController.add(errProgress);
    onProgress?.call(errProgress);
    return false;
  }

  void _handleCancelled(
    AiModelInfo model,
    StreamController<ModelDownloadProgress> streamController,
    void Function(ModelDownloadProgress)? onProgress,
    File tempFile,
  ) async {
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    } catch (_) {}

    final cancelledProgress = ModelDownloadProgress(
      modelId: model.id,
      bytesDownloaded: 0,
      totalBytes: model.expectedSizeBytes,
      progress: 0.0,
      error: 'Cancelled by user',
    );
    streamController.add(cancelledProgress);
    onProgress?.call(cancelledProgress);
  }

  String _formatCleanErrorMessage(dynamic e) {
    final raw = e.toString();
    if (raw.contains('Connection closed while receiving data') || raw.contains('SocketException')) {
      return 'Network connection interrupted. Tap to resume.';
    }
    if (raw.contains('Failed host lookup')) {
      return 'No internet connection. Please check your network.';
    }
    if (raw.contains('timed out') || raw.contains('TimeoutException')) {
      return 'Download timed out. Tap to resume.';
    }
    if (raw.contains('HTTP 404')) {
      return 'Model file not found on server (HTTP 404).';
    }
    if (raw.contains('HTTP 401') || raw.contains('HTTP 403')) {
      return 'Model access denied or requires authorization (HTTP 401/403).';
    }
    return 'Download interrupted. Tap to resume.';
  }

  Future<bool> deleteModel(AiModelInfo model) async {
    try {
      final path = await getModelPath(model);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
      final tempFile = File('$path.download');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteAllModels() async {
    for (final model in AiModelConfig.allModels) {
      await deleteModel(model);
    }
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
