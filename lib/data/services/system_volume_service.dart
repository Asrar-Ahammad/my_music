import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final systemVolumeServiceProvider = Provider<SystemVolumeService>((ref) {
  final service = SystemVolumeService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Service controlling the Android system media / music volume (AudioManager.STREAM_MUSIC)
/// and listening for hardware volume button events.
class SystemVolumeService {
  static const MethodChannel _methodChannel =
      MethodChannel('com.retro.mymusic/volume_control');
  static const EventChannel _eventChannel =
      EventChannel('com.retro.mymusic/volume_stream');

  double _volume = 1.0;
  final _volumeController = StreamController<double>.broadcast();
  StreamSubscription? _eventSubscription;

  SystemVolumeService() {
    _init();
  }

  double get currentVolume => _volume;
  Stream<double> get volumeStream => _volumeController.stream;

  Future<void> _init() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final double? initial =
            await _methodChannel.invokeMethod<double>('getVolume');
        if (initial != null) {
          _volume = initial.clamp(0.0, 1.0);
          _volumeController.add(_volume);
        }

        _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
          (dynamic event) {
            if (event is num) {
              _volume = event.toDouble().clamp(0.0, 1.0);
              _volumeController.add(_volume);
            }
          },
          onError: (dynamic err) {
            debugPrint('System volume stream error: $err');
          },
        );
      }
    } on MissingPluginException {
      // Platform channels not registered in test / desktop environment
    } catch (e) {
      debugPrint('SystemVolumeService init error: $e');
    }
  }

  /// Sets the system media volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    _volume = clamped;
    _volumeController.add(clamped);

    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        await _methodChannel.invokeMethod('setVolume', {'volume': clamped});
      }
    } on MissingPluginException {
      // Test environment fallback
    } catch (e) {
      debugPrint('SystemVolumeService setVolume error: $e');
    }
  }

  /// Fetches latest system volume from AudioManager
  Future<double> getVolume() async {
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final double? vol =
            await _methodChannel.invokeMethod<double>('getVolume');
        if (vol != null) {
          _volume = vol.clamp(0.0, 1.0);
          _volumeController.add(_volume);
          return _volume;
        }
      }
    } on MissingPluginException {
      // Test environment fallback
    } catch (e) {
      debugPrint('SystemVolumeService getVolume error: $e');
    }
    return _volume;
  }

  void dispose() {
    _eventSubscription?.cancel();
    _volumeController.close();
  }
}
