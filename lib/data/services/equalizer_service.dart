import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final equalizerServiceProvider = Provider<EqualizerService>((ref) {
  final service = EqualizerService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Service interfacing with native Android [Equalizer] via platform channels.
class EqualizerService {
  static const MethodChannel _channel =
      MethodChannel('com.retro.mymusic/equalizer_control');

  int _sessionId = 0;
  bool _isEnabled = false;
  List<double> _bandGains = const [0.0, 0.0, 0.0, 0.0, 0.0];

  int get sessionId => _sessionId;
  bool get isEnabled => _isEnabled;
  List<double> get bandGains => List.unmodifiable(_bandGains);

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Initializes or binds the equalizer to an active [sessionId].
  Future<bool> init(
    int sessionId, {
    bool isEnabled = false,
    List<double> bandGains = const [0.0, 0.0, 0.0, 0.0, 0.0],
  }) async {
    _sessionId = sessionId;
    _isEnabled = isEnabled;
    _bandGains = List<double>.from(bandGains);

    if (!_isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('init', {
        'sessionId': sessionId,
        'enabled': isEnabled,
        'bandGains': bandGains,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('EqualizerService init error: $e');
      return false;
    }
  }

  /// Enables or disables equalizer processing.
  Future<bool> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    if (!_isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('setEnabled', {
        'enabled': enabled,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('EqualizerService setEnabled error: $e');
      return false;
    }
  }

  /// Sets gain (in dB) for a specific band index (0 to 4).
  Future<bool> setBandGain(int bandIndex, double gain) async {
    if (bandIndex >= 0 && bandIndex < _bandGains.length) {
      final updated = List<double>.from(_bandGains);
      updated[bandIndex] = gain;
      _bandGains = updated;
    }

    if (!_isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('setBandGain', {
        'band': bandIndex,
        'gain': gain,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('EqualizerService setBandGain error: $e');
      return false;
    }
  }

  /// Sets all band gains (in dB) at once.
  Future<bool> setAllBands(List<double> gains) async {
    _bandGains = List<double>.from(gains);
    if (!_isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('setAllBands', {
        'bandGains': gains,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('EqualizerService setAllBands error: $e');
      return false;
    }
  }

  /// Fetches native equalizer parameters (bands, min/max level, center frequencies).
  Future<Map<String, dynamic>?> getParameters() async {
    if (!_isAndroid) return null;

    try {
      final params =
          await _channel.invokeMapMethod<String, dynamic>('getParameters');
      return params;
    } on MissingPluginException {
      return null;
    } catch (e) {
      debugPrint('EqualizerService getParameters error: $e');
      return null;
    }
  }

  /// Releases native equalizer resources.
  Future<void> release() async {
    if (!_isAndroid) return;

    try {
      await _channel.invokeMethod('release');
    } on MissingPluginException {
      // Ignored
    } catch (e) {
      debugPrint('EqualizerService release error: $e');
    }
  }

  void dispose() {
    release();
  }
}
