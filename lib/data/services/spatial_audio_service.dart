import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final spatialAudioServiceProvider = Provider<SpatialAudioService>((ref) {
  final service = SpatialAudioService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Hardware & Framework capabilities for Dolby Atmos and Spatial Audio.
class SpatialAudioCapabilities {
  final bool strengthSupported;
  final int currentStrength;
  final bool isSpatializerAvailable;
  final bool isSpatializerEnabled;
  final bool isHeadTrackerAvailable;
  final int immersiveAudioLevel;
  final bool hasDolbyEac3Decoder;
  final bool hasDolbyAc4Decoder;
  final bool hasSystemAudioEffectPanel;
  final int sdkVersion;

  const SpatialAudioCapabilities({
    this.strengthSupported = true,
    this.currentStrength = 1000,
    this.isSpatializerAvailable = false,
    this.isSpatializerEnabled = false,
    this.isHeadTrackerAvailable = false,
    this.immersiveAudioLevel = 0,
    this.hasDolbyEac3Decoder = false,
    this.hasDolbyAc4Decoder = false,
    this.hasSystemAudioEffectPanel = false,
    this.sdkVersion = 0,
  });

  bool get hasDolbyAtmosHardwareSupport =>
      hasDolbyEac3Decoder || hasDolbyAc4Decoder || hasSystemAudioEffectPanel;

  factory SpatialAudioCapabilities.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const SpatialAudioCapabilities();
    return SpatialAudioCapabilities(
      strengthSupported: (map['strengthSupported'] as bool?) ?? true,
      currentStrength: (map['currentStrength'] as int?) ?? 1000,
      isSpatializerAvailable: (map['isSpatializerAvailable'] as bool?) ?? false,
      isSpatializerEnabled: (map['isSpatializerEnabled'] as bool?) ?? false,
      isHeadTrackerAvailable: (map['isHeadTrackerAvailable'] as bool?) ?? false,
      immersiveAudioLevel: (map['immersiveAudioLevel'] as int?) ?? 0,
      hasDolbyEac3Decoder: (map['hasDolbyEac3Decoder'] as bool?) ?? false,
      hasDolbyAc4Decoder: (map['hasDolbyAc4Decoder'] as bool?) ?? false,
      hasSystemAudioEffectPanel: (map['hasSystemAudioEffectPanel'] as bool?) ?? false,
      sdkVersion: (map['sdkVersion'] as int?) ?? 0,
    );
  }
}

/// Service interfacing with native Android 3D Virtualizer and Dolby Atmos effects.
class SpatialAudioService {
  static const MethodChannel _channel =
      MethodChannel('com.retro.mymusic/spatial_audio_control');

  int _sessionId = 0;
  bool _isEnabled = false;
  int _strength = 1000;
  String _mode = 'binaural';
  SpatialAudioCapabilities _capabilities = const SpatialAudioCapabilities();

  int get sessionId => _sessionId;
  bool get isEnabled => _isEnabled;
  int get strength => _strength;
  String get mode => _mode;
  SpatialAudioCapabilities get capabilities => _capabilities;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Initializes or binds spatial audio virtualization to an active [sessionId].
  Future<bool> init(
    int sessionId, {
    bool isEnabled = false,
    int strength = 1000,
    String mode = 'binaural',
  }) async {
    _sessionId = sessionId;
    _isEnabled = isEnabled;
    _strength = strength;
    _mode = mode;

    if (!_isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('init', {
        'sessionId': sessionId,
        'enabled': isEnabled,
        'strength': strength,
        'mode': mode,
      });
      await queryCapabilities();
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('SpatialAudioService init error: $e');
      return false;
    }
  }

  /// Enables or disables 3D virtualization and spatial audio processing.
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
      debugPrint('SpatialAudioService setEnabled error: $e');
      return false;
    }
  }

  /// Sets virtualization strength from 0 to 1000 (0 = subtle/narrow, 1000 = full 3D soundstage).
  Future<bool> setStrength(int strength) async {
    _strength = strength.clamp(0, 1000);
    if (!_isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('setStrength', {
        'strength': _strength,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('SpatialAudioService setStrength error: $e');
      return false;
    }
  }

  /// Sets virtualization rendering mode ('binaural' for headphones, 'transaural' for speakers, 'auto').
  Future<bool> setMode(String mode) async {
    _mode = mode;
    if (!_isAndroid) return false;

    try {
      final success = await _channel.invokeMethod<bool>('setMode', {
        'mode': mode,
      });
      return success ?? false;
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint('SpatialAudioService setMode error: $e');
      return false;
    }
  }

  /// Queries native hardware capabilities and Android framework spatializer status.
  Future<SpatialAudioCapabilities> queryCapabilities() async {
    if (!_isAndroid) return _capabilities;

    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>('getCapabilities');
      _capabilities = SpatialAudioCapabilities.fromMap(res);
      return _capabilities;
    } on MissingPluginException {
      return _capabilities;
    } catch (e) {
      debugPrint('SpatialAudioService queryCapabilities error: $e');
      return _capabilities;
    }
  }

  /// Launches the system Dolby Atmos / OEM SoundAlive audio effect control panel.
  Future<bool> openSystemSettings() async {
    if (!_isAndroid) return false;

    try {
      final res = await _channel.invokeMethod<bool>('openSystemSettings');
      return res ?? false;
    } catch (e) {
      debugPrint('SpatialAudioService openSystemSettings error: $e');
      return false;
    }
  }

  /// Releases the native virtualizer.
  Future<void> dispose() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod('release');
    } catch (_) {}
  }
}
