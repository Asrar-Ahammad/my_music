import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/utils/permission_helper.dart';
import '../../domain/models/song.dart';
import '../repositories/settings_repository.dart';
import 'equalizer_service.dart';
import 'spatial_audio_service.dart';
import 'storage_service.dart';
import 'system_volume_service.dart';

enum RetroLoopMode { off, all, one }

class AudioPlayerHandler extends BaseAudioHandler with QueueHandler {
  static final AudioPlayerHandler _instance = AudioPlayerHandler._internal();
  factory AudioPlayerHandler() => _instance;
  AudioPlayerHandler._internal() {
    _broadcastPlaybackState();
  }

  final AudioPlayer _player = AudioPlayer();
  // ignore: deprecated_member_use
  ConcatenatingAudioSource? _playlistSource;

  List<Song> _queue = [];
  List<Song> _originalQueue = [];
  int _currentIndex = -1;
  int _userQueueCount = 0;
  RetroLoopMode _loopMode = RetroLoopMode.off;
  bool _isShuffle = false;
  bool _isReorderingQueue = false;
  bool _wasPlayingBeforeInterruption = false;

  int get userQueueCount => _userQueueCount;

  Timer? _sleepTimer;
  Duration? _sleepTimerRemaining;
  final _sleepTimerController = StreamController<Duration?>.broadcast();

  // Equalizer values (-10.0 to +10.0 dB)
  final List<double> _bandGains = [0.0, 0.0, 0.0, 0.0, 0.0];
  bool _equalizerEnabled = false;

  final _currentIndexController = StreamController<int?>.broadcast();


  // Streams
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<int?> get currentIndexStream => _currentIndexController.stream;
  Stream<Duration?> get sleepTimerStream => _sleepTimerController.stream;

  final StorageService _storage = StorageService();
  String? _currentPlaylistId;
  String? get currentPlaylistId => _currentPlaylistId;

  Duration _savedRestoredPosition = Duration.zero;
  Duration get playbackPosition => _player.position > Duration.zero ? _player.position : _savedRestoredPosition;
  Duration? get currentDuration => _player.duration ?? currentSong?.duration;

  DateTime? _lastPositionSaveTime;
  Duration _lastSavedPosition = Duration.zero;

  void _onPositionChanged(Duration pos) {
    _savedRestoredPosition = pos;
    final now = DateTime.now();
    if (_lastPositionSaveTime == null || now.difference(_lastPositionSaveTime!) > const Duration(seconds: 2)) {
      if ((pos - _lastSavedPosition).abs() >= const Duration(seconds: 1)) {
        _lastPositionSaveTime = now;
        _lastSavedPosition = pos;
        _storage.savePlaybackPosition(pos);
      }
    }
  }

  void saveCurrentPlaybackState() {
    final song = currentSong;
    if (song != null && _queue.isNotEmpty) {
      _storage.savePlaybackState(
        currentSong: song,
        position: _player.position > Duration.zero ? _player.position : _savedRestoredPosition,
        queue: _queue,
        originalQueue: _originalQueue.isNotEmpty ? _originalQueue : _queue,
        currentIndex: _currentIndex >= 0 ? _currentIndex : 0,
        isShuffle: _isShuffle,
        loopMode: _loopMode.name,
        playlistId: _currentPlaylistId,
      );
    }
  }

  Future<void> restoreSavedPlaybackState() async {
    try {
      final saved = _storage.getSavedPlaybackState();
      if (saved == null) return;

      final songMap = saved['song'];
      if (songMap is! Map) return;
      final restoredSong = Song.fromMap(Map<String, dynamic>.from(songMap));

      final rawQueue = saved['queue'];
      List<Song> restoredQueue = [];
      if (rawQueue is List) {
        for (final item in rawQueue) {
          if (item is Map) {
            restoredQueue.add(Song.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }
      if (restoredQueue.isEmpty) {
        restoredQueue = [restoredSong];
      }

      final rawOrigQueue = saved['originalQueue'];
      List<Song> restoredOrigQueue = [];
      if (rawOrigQueue is List) {
        for (final item in rawOrigQueue) {
          if (item is Map) {
            restoredOrigQueue.add(Song.fromMap(Map<String, dynamic>.from(item)));
          }
        }
      }
      if (restoredOrigQueue.isEmpty) {
        restoredOrigQueue = List.from(restoredQueue);
      }

      int restoredIndex = saved['currentIndex'] as int? ?? restoredQueue.indexWhere((s) => s.id == restoredSong.id);
      if (restoredIndex < 0 || restoredIndex >= restoredQueue.length) {
        restoredIndex = 0;
      }

      final isShuffle = saved['isShuffle'] as bool? ?? false;
      final loopStr = saved['loopMode'] as String? ?? 'off';
      final loopMode = RetroLoopMode.values.firstWhere(
        (e) => e.name == loopStr,
        orElse: () => RetroLoopMode.off,
      );
      final playlistId = saved['playlistId'] as String?;

      final posMs = saved['positionMs'] as int? ?? 0;
      var initialPosition = Duration(milliseconds: posMs);
      if (restoredSong.duration > Duration.zero && initialPosition >= restoredSong.duration - const Duration(seconds: 1)) {
        initialPosition = Duration.zero;
      }

      _queue = List.from(restoredQueue);
      _originalQueue = List.from(restoredOrigQueue);
      _currentIndex = restoredIndex;
      _isShuffle = isShuffle;
      _loopMode = loopMode;
      _currentPlaylistId = playlistId;
      _savedRestoredPosition = initialPosition;

      queue.add(_queue.map(_toMediaItem).toList());
      _broadcastMediaItem(currentSong);
      _currentIndexController.add(_currentIndex);

      final audioSources = <AudioSource>[];
      for (final song in _queue) {
        audioSources.add(_createAudioSource(song));
      }

      try {
        // ignore: deprecated_member_use
        _playlistSource = ConcatenatingAudioSource(
          useLazyPreparation: true,
          children: audioSources,
        );
        await _player.setAudioSource(
          _playlistSource!,
          initialIndex: _currentIndex,
          initialPosition: initialPosition,
        );
        try {
          await _player.setShuffleModeEnabled(false);
          await _player.setLoopMode(switch (_loopMode) {
            RetroLoopMode.off => LoopMode.off,
            RetroLoopMode.one => LoopMode.one,
            RetroLoopMode.all => LoopMode.all,
          });
        } catch (_) {}
      } catch (e) {
        debugPrint("Error restoring audio source: $e");
        _playlistSource = null;
      }

      _broadcastPlaybackState();
    } catch (e) {
      debugPrint("Error in restoreSavedPlaybackState: $e");
    }
  }

  List<Song> get songQueue => List.unmodifiable(_queue);
  List<Song> get originalQueue => List.unmodifiable(_originalQueue);
  int get currentIndex => _currentIndex;
  Song? get currentSong => (_currentIndex >= 0 && _currentIndex < _queue.length) ? _queue[_currentIndex] : null;
  bool get isPlaying => _player.playing;
  RetroLoopMode get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;
  List<double> get bandGains => List.unmodifiable(_bandGains);
  bool get equalizerEnabled => _equalizerEnabled;
  Duration? get sleepTimerRemaining => _sleepTimerRemaining;
  int? get androidAudioSessionId => _player.androidAudioSessionId;

  final SystemVolumeService _systemVolumeService = SystemVolumeService();
  SystemVolumeService get systemVolumeService => _systemVolumeService;

  final EqualizerService _equalizerService = EqualizerService();
  EqualizerService get equalizerService => _equalizerService;

  final SpatialAudioService _spatialAudioService = SpatialAudioService();
  SpatialAudioService get spatialAudioService => _spatialAudioService;

  bool _spatialAudioEnabled = false;
  int _spatialAudioStrength = 1000;
  String _spatialAudioMode = 'binaural';
  bool get spatialAudioEnabled => _spatialAudioEnabled;
  int get spatialAudioStrength => _spatialAudioStrength;
  String get spatialAudioMode => _spatialAudioMode;

  int? _lastSessionId;

  void _syncEqualizerSession() {
    final sessionId = _player.androidAudioSessionId;
    if (sessionId != null && sessionId > 0 && sessionId != _lastSessionId) {
      _lastSessionId = sessionId;
      _equalizerService.init(
        sessionId,
        isEnabled: _equalizerEnabled,
        bandGains: _bandGains,
      );
      _spatialAudioService.init(
        sessionId,
        isEnabled: _spatialAudioEnabled,
        strength: _spatialAudioStrength,
        mode: _spatialAudioMode,
      );
    }
  }

  Stream<double> get volumeStream => _systemVolumeService.volumeStream;
  double get volume => _systemVolumeService.currentVolume;
  Future<void> setVolume(double vol) async {
    await _systemVolumeService.setVolume(vol);
  }

  Future<void> init() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      // Activate the audio session so Android knows we want audio focus
      await session.setActive(true);

      // Handle audio interruptions (calls, notifications, other apps stealing focus)
      session.interruptionEventStream.listen((event) async {
        if (event.begin) {
          // Another app / system took audio focus — track whether we were playing
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Minor interruption: duck volume, keep playing (just_audio handles this)
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              // Save whether we were playing so we can resume
              _wasPlayingBeforeInterruption = _player.playing;
              if (_player.playing) {
                await _player.pause();
              }
              break;
          }
        } else {
          // Interruption ended — resume if we were playing before
          switch (event.type) {
            case AudioInterruptionType.duck:
              // Volume was ducked, nothing to do
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              if (_wasPlayingBeforeInterruption) {
                _wasPlayingBeforeInterruption = false;
                await _player.play();
              }
              break;
          }
        }
      });

      // Handle audio focus loss/gain events from Android
      session.becomingNoisyEventStream.listen((_) async {
        // Headphones unplugged — pause playback (standard Android behavior)
        if (_player.playing) {
          await _player.pause();
        }
      });
    } catch (e) {
      debugPrint("AudioSession init note: $e");
    }

    try {
      final settings = SettingsRepository();
      _equalizerEnabled = settings.isEqualizerEnabled();
      final savedBands = settings.getEqualizerBands();
      if (savedBands.isNotEmpty) {
        for (int i = 0; i < _bandGains.length && i < savedBands.length; i++) {
          _bandGains[i] = savedBands[i];
        }
      }
      _spatialAudioEnabled = settings.isSpatialAudioEnabled();
      _spatialAudioStrength = settings.getSpatialAudioStrength();
      _spatialAudioMode = settings.getSpatialAudioMode();
    } catch (e) {
      debugPrint("SettingsRepository EQ/Spatial load note: $e");
    }

    _player.positionStream.listen(_onPositionChanged);

    _player.playbackEventStream.listen((_) {
      _syncEqualizerSession();
      _broadcastPlaybackState();
    });

    _player.playerStateStream.listen((state) {
      _syncEqualizerSession();
      _broadcastPlaybackState();
      if (state.processingState == ProcessingState.completed) {
        if (_loopMode == RetroLoopMode.one) {
          _player.seek(Duration.zero);
          _player.play();
        }
      }
    });

    _player.currentIndexStream.listen((index) {
      if (_isReorderingQueue) return;
      if (index != null && index >= 0 && index < _queue.length) {
        final currentTag = _player.sequenceState.currentSource?.tag;
        final oldIndex = _currentIndex;
        if (currentTag is MediaItem) {
          final matchedIdx = _queue.indexWhere((s) => s.id == currentTag.id);
          if (matchedIdx != -1) {
            _currentIndex = matchedIdx;
          } else {
            _currentIndex = index;
          }
        } else {
          _currentIndex = index;
        }
        if (oldIndex >= 0 && _currentIndex > oldIndex) {
          final delta = _currentIndex - oldIndex;
          _userQueueCount = (_userQueueCount - delta).clamp(0, _queue.length);
        } else if (_currentIndex < oldIndex) {
          _userQueueCount = 0;
        }
        _broadcastMediaItem(currentSong);
        _broadcastPlaybackState();
        _currentIndexController.add(_currentIndex);
      }
    });

    await restoreSavedPlaybackState();
    _broadcastPlaybackState();
  }

  void _broadcastPlaybackState() {
    final isPlaying = _player.playing;
    final processingState = _player.processingState;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (isPlaying) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: switch (_loopMode) {
              RetroLoopMode.one => 'drawable/ic_repeat_one',
              RetroLoopMode.all => 'drawable/ic_repeat_dot',
              RetroLoopMode.off => 'drawable/ic_repeat',
            },
            label: _loopMode == RetroLoopMode.one
                ? 'Repeat One'
                : (_loopMode == RetroLoopMode.all ? 'Repeat All' : 'Repeat Off'),
            name: 'toggle_repeat',
          ),
          MediaControl.custom(
            androidIcon: _isShuffle ? 'drawable/ic_shuffle_dot' : 'drawable/ic_shuffle',
            label: _isShuffle ? 'Shuffle On' : 'Shuffle Off',
            name: 'toggle_shuffle',
          ),
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.setRepeatMode,
          MediaAction.setShuffleMode,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[processingState] ?? AudioProcessingState.idle,
        playing: isPlaying,
        updatePosition: _player.position > Duration.zero ? _player.position : _savedRestoredPosition,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        repeatMode: switch (_loopMode) {
          RetroLoopMode.off => AudioServiceRepeatMode.none,
          RetroLoopMode.one => AudioServiceRepeatMode.one,
          RetroLoopMode.all => AudioServiceRepeatMode.all,
        },
        shuffleMode: _isShuffle
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
        queueIndex: _currentIndex >= 0 ? _currentIndex : null,
      ),
    );
  }

  void _broadcastMediaItem(Song? song) {
    if (song == null) {
      mediaItem.add(null);
      return;
    }
    mediaItem.add(_toMediaItem(song));
  }

  MediaItem _toMediaItem(Song song) {
    return MediaItem(
      id: song.id,
      album: song.album,
      title: song.title,
      artist: song.artist,
      duration: song.duration,
      artUri: song.artPath != null
          ? (song.artPath!.startsWith('http')
              ? Uri.tryParse(song.artPath!)
              : Uri.file(song.artPath!))
          : null,
      extras: {
        'uri': song.uri,
        'isAsset': song.isAsset,
        'format': song.quality.format,
        'sampleRate': song.quality.sampleRate,
        'bitDepth': song.quality.bitDepth,
        'bitrateKbps': song.quality.bitrateKbps,
      },
    );
  }

  /// Play a song immediately with a surrounding queue
  Future<void> setQueueAndPlay(
    List<Song> songs,
    int initialIndex, {
    List<Song>? originalList,
    bool? isShuffle,
    String? playlistId,
    Duration initialPosition = Duration.zero,
  }) async {
    if (songs.isEmpty) return;
    _currentPlaylistId = playlistId;
    _savedRestoredPosition = initialPosition;
    _originalQueue = List.from(originalList ?? songs);
    _queue = List.from(songs);
    _currentIndex = (initialIndex >= 0 && initialIndex < songs.length) ? initialIndex : 0;
    _userQueueCount = 0;
    if (isShuffle != null) {
      _isShuffle = isShuffle;
    }

    queue.add(_queue.map(_toMediaItem).toList());
    _broadcastMediaItem(currentSong);
    _currentIndexController.add(_currentIndex);

    final audioSources = <AudioSource>[];
    for (final song in _queue) {
      audioSources.add(_createAudioSource(song));
    }

    // ignore: deprecated_member_use
    _playlistSource = ConcatenatingAudioSource(
      useLazyPreparation: true,
      children: audioSources,
    );

    try {
      await PermissionHelper.requestNotificationPermission();
      await _player.setAudioSource(
        _playlistSource!,
        initialIndex: _currentIndex,
        initialPosition: initialPosition,
      );
      try {
        await _player.setShuffleModeEnabled(false);
        await _player.setLoopMode(switch (_loopMode) {
          RetroLoopMode.off => LoopMode.off,
          RetroLoopMode.one => LoopMode.one,
          RetroLoopMode.all => LoopMode.all,
        });
      } catch (_) {}
      await _player.play();
      saveCurrentPlaybackState();
    } catch (e) {
      debugPrint("Error loading audio source: $e");
    }
  }

  AudioSource _createAudioSource(Song song) {
    final uri = song.uri;
    if (song.isAsset) {
      return AudioSource.asset(uri, tag: _toMediaItem(song));
    } else {
      return AudioSource.file(uri, tag: _toMediaItem(song));
    }
  }

  Timer? _mediaClickTimer;
  int _mediaClickCount = 0;
  @visibleForTesting
  Duration mediaClickTimeout = const Duration(milliseconds: 320);

  void _resetMediaClick() {
    _mediaClickTimer?.cancel();
    _mediaClickTimer = null;
    _mediaClickCount = 0;
  }

  @override
  Future<void> click([MediaButton button = MediaButton.media]) async {
    switch (button) {
      case MediaButton.media:
        _mediaClickCount++;
        _mediaClickTimer?.cancel();
        _mediaClickTimer = Timer(mediaClickTimeout, () async {
          final count = _mediaClickCount;
          _resetMediaClick();

          if (count == 1) {
            // Single click: Toggle Play / Pause
            if (_player.playing) {
              await pause();
            } else {
              await play();
            }
          } else if (count == 2) {
            // Double click: Skip to Next track
            await skipToNext();
          } else if (count >= 3) {
            // Triple click: Skip to Previous track
            await skipToPrevious();
          }
        });
        break;
      case MediaButton.next:
        _resetMediaClick();
        await skipToNext();
        break;
      case MediaButton.previous:
        _resetMediaClick();
        await skipToPrevious();
        break;
    }
  }

  @override
  Future<void> play() async {
    _resetMediaClick();
    await PermissionHelper.requestNotificationPermission();
    // Re-activate the audio session in case Android released it while in background
    try {
      final session = await AudioSession.instance;
      await session.setActive(true);
    } catch (_) {}
    if (_player.audioSource == null && _queue.isNotEmpty && _currentIndex >= 0 && _currentIndex < _queue.length) {
      try {
        await setQueueAndPlay(
          _queue,
          _currentIndex,
          originalList: _originalQueue,
          isShuffle: _isShuffle,
          playlistId: _currentPlaylistId,
          initialPosition: _savedRestoredPosition,
        );
      } catch (e) {
        debugPrint("setQueueAndPlay note: $e");
      }
      return;
    }
    try {
      await _player.play();
    } catch (e) {
      debugPrint("play note: $e");
    }
  }

  @override
  Future<void> pause() async {
    _resetMediaClick();
    try {
      await _player.pause();
    } catch (e) {
      debugPrint("pause note: $e");
    }
    saveCurrentPlaybackState();
  }

  @override
  Future<void> stop() async {
    _resetMediaClick();
    try {
      await _player.stop();
    } catch (e) {
      debugPrint("stop note: $e");
    }
    _broadcastPlaybackState();
    await super.stop();
  }

  @override
  Future<void> onTaskRemoved() async {
    saveCurrentPlaybackState();
    await stop();
    await super.onTaskRemoved();
  }

  @override
  Future<void> seek(Duration position) async {
    _savedRestoredPosition = position;
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint("seek note: $e");
    }
    saveCurrentPlaybackState();
  }

  @override
  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
      } else if (_currentIndex + 1 < _queue.length) {
        await playAtIndex(_currentIndex + 1);
      } else if (_loopMode == RetroLoopMode.all) {
        await playAtIndex(0);
      }
    } catch (_) {
      if (_currentIndex + 1 < _queue.length) {
        await playAtIndex(_currentIndex + 1);
      } else if (_loopMode == RetroLoopMode.all) {
        await playAtIndex(0);
      }
    }
    saveCurrentPlaybackState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;
    try {
      if (_player.position.inSeconds > 3) {
        await _player.seek(Duration.zero);
      } else if (_player.hasPrevious) {
        await _player.seekToPrevious();
      } else if (_currentIndex - 1 >= 0) {
        await playAtIndex(_currentIndex - 1);
      } else if (_loopMode == RetroLoopMode.all && _queue.isNotEmpty) {
        await playAtIndex(_queue.length - 1);
      } else {
        await _player.seek(Duration.zero);
      }
    } catch (_) {
      if (_currentIndex - 1 >= 0) {
        await playAtIndex(_currentIndex - 1);
      } else if (_loopMode == RetroLoopMode.all && _queue.isNotEmpty) {
        await playAtIndex(_queue.length - 1);
      }
    }
    saveCurrentPlaybackState();
  }

  @override
  Future<void> skipToQueueItem(int index) async => playAtIndex(index);

  Future<void> playAtIndex(int index) async {
    if (index >= 0 && index < _queue.length) {
      final oldIndex = _currentIndex;
      _currentIndex = index;
      if (oldIndex >= 0 && index > oldIndex) {
        final delta = index - oldIndex;
        _userQueueCount = (_userQueueCount - delta).clamp(0, _queue.length);
      } else if (index < oldIndex) {
        _userQueueCount = 0;
      }
      _broadcastMediaItem(currentSong);
      _currentIndexController.add(_currentIndex);
      if (_player.audioSource != null) {
        await _player.seek(Duration.zero, index: index);
        await play();
        saveCurrentPlaybackState();
      }
    }
  }

  // --- Queue Operations ---
  void addSongToQueue(Song song) {
    if (_queue.isEmpty || _currentIndex < 0) {
      setQueueAndPlay([song], 0);
      return;
    }
    // Spotify-style: "Add to Queue" appends to the end of the user queue (on top of existing context queue)
    final insertIndex = (_currentIndex + 1 + _userQueueCount).clamp(0, _queue.length);
    _queue.insert(insertIndex, song);
    _playlistSource?.insert(insertIndex, _createAudioSource(song)).catchError((_) {});

    final current = currentSong;
    final origIdx = current != null ? _originalQueue.indexWhere((s) => s.id == current.id) : -1;
    final origInsert = origIdx != -1
        ? (origIdx + 1 + _userQueueCount).clamp(0, _originalQueue.length)
        : _originalQueue.length;
    if (origInsert <= _originalQueue.length) {
      _originalQueue.insert(origInsert, song);
    } else {
      _originalQueue.add(song);
    }
    _userQueueCount++;

    queue.add(_queue.map(_toMediaItem).toList());
    saveCurrentPlaybackState();
  }

  void addSongNext(Song song) {
    if (_queue.isEmpty || _currentIndex < 0) {
      setQueueAndPlay([song], 0);
      return;
    }
    // Spotify-style: "Play Next" places song immediately after current song at the top of the queue
    final nextIndex = (_currentIndex + 1).clamp(0, _queue.length);
    _queue.insert(nextIndex, song);
    _userQueueCount++;
    _playlistSource?.insert(nextIndex, _createAudioSource(song)).catchError((_) {});

    final current = currentSong;
    final origIdx = current != null ? _originalQueue.indexWhere((s) => s.id == current.id) : -1;
    final origInsert = origIdx != -1
        ? (origIdx + 1).clamp(0, _originalQueue.length)
        : _originalQueue.length;
    if (origInsert <= _originalQueue.length) {
      _originalQueue.insert(origInsert, song);
    } else {
      _originalQueue.add(song);
    }

    queue.add(_queue.map(_toMediaItem).toList());
    saveCurrentPlaybackState();
  }

  void removeQueueAt(int index) {
    if (index >= 0 && index < _queue.length) {
      final removed = _queue.removeAt(index);
      _originalQueue.removeWhere((s) => s.id == removed.id);
      _playlistSource?.removeAt(index).catchError((_) {});
      if (index > _currentIndex && index <= _currentIndex + _userQueueCount) {
        _userQueueCount = (_userQueueCount - 1).clamp(0, _queue.length);
      }
      if (index < _currentIndex) {
        _currentIndex -= 1;
      } else if (_currentIndex >= _queue.length) {
        _currentIndex = _queue.length - 1;
      }
      queue.add(_queue.map(_toMediaItem).toList());
      _broadcastMediaItem(currentSong);
      _currentIndexController.add(_currentIndex);
      saveCurrentPlaybackState();
    }
  }

  void updateSongInQueue(String songId, {required bool isFavorite}) {
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].id == songId) {
        _queue[i] = _queue[i].copyWith(isFavorite: isFavorite);
      }
    }
    for (int i = 0; i < _originalQueue.length; i++) {
      if (_originalQueue[i].id == songId) {
        _originalQueue[i] = _originalQueue[i].copyWith(isFavorite: isFavorite);
      }
    }
    queue.add(_queue.map(_toMediaItem).toList());
    saveCurrentPlaybackState();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    if (oldIndex < 0 || oldIndex >= _queue.length) return;
    if (newIndex < 0 || newIndex > _queue.length) return;

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final song = _queue.removeAt(oldIndex);
    _queue.insert(newIndex, song);
    _playlistSource?.move(oldIndex, newIndex).catchError((_) {});

    if (!_isShuffle) {
      _originalQueue = List<Song>.from(_queue);
    }

    if (_currentIndex == oldIndex) {
      _currentIndex = newIndex;
    } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
      _currentIndex -= 1;
    } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
      _currentIndex += 1;
    }
    queue.add(_queue.map(_toMediaItem).toList());
    _broadcastMediaItem(currentSong);
    _currentIndexController.add(_currentIndex);
    saveCurrentPlaybackState();
  }

  Future<void> clearQueue() async {
    _userQueueCount = 0;
    final current = currentSong;
    if (current != null && _currentIndex >= 0 && _currentIndex < _queue.length) {
      final initialIndex = _currentIndex;
      // Retain the active track so playback continues seamlessly
      _queue = [current];
      _currentIndex = 0;
      _originalQueue = [current];
      queue.add([_toMediaItem(current)]);
      _broadcastMediaItem(current);
      _broadcastPlaybackState();
      _currentIndexController.add(_currentIndex);
      saveCurrentPlaybackState();

      final source = _playlistSource;
      if (source != null) {
        try {
          if (source.length > initialIndex + 1) {
            await source.removeRange(initialIndex + 1, source.length);
          }
          if (initialIndex > 0 && source.length > 0) {
            final removeEnd = initialIndex.clamp(0, source.length);
            if (removeEnd > 0) {
              await source.removeRange(0, removeEnd);
            }
          }
        } catch (_) {}
      }
    } else {
      _queue.clear();
      _originalQueue.clear();
      try {
        _playlistSource?.clear().catchError((_) {});
      } catch (_) {}
      _playlistSource = null;
      _currentIndex = -1;
      _savedRestoredPosition = Duration.zero;
      _currentPlaylistId = null;
      queue.add([]);
      mediaItem.add(null);
      _currentIndexController.add(-1);
      if (_player.audioSource != null) {
        try {
          await _player.stop();
        } catch (_) {}
      }
      _storage.clearSavedPlaybackState();
    }
  }

  @visibleForTesting
  void resetForTesting() {
    _resetMediaClick();
    mediaClickTimeout = const Duration(milliseconds: 320);
    _queue.clear();
    _originalQueue.clear();
    try {
      _playlistSource?.clear().catchError((_) {});
    } catch (_) {}
    _playlistSource = null;
    _currentIndex = -1;
    _savedRestoredPosition = Duration.zero;
    _currentPlaylistId = null;
    queue.add([]);
    mediaItem.add(null);
    _currentIndexController.add(-1);
  }

  @visibleForTesting
  void setQueueForTesting({
    required List<Song> songs,
    required int currentIndex,
    List<Song>? originalList,
    bool isShuffle = false,
    Duration position = Duration.zero,
  }) {
    _originalQueue = List.from(originalList ?? songs);
    _queue = List.from(songs);
    _currentIndex = currentIndex;
    _isShuffle = isShuffle;
    _savedRestoredPosition = position;
    queue.add(_queue.map(_toMediaItem).toList());
    _broadcastMediaItem(currentSong);
    _broadcastPlaybackState();
    _currentIndexController.add(_currentIndex);
  }

  // --- Loop & Shuffle ---
  Future<void> toggleLoopMode() async {
    switch (_loopMode) {
      case RetroLoopMode.off:
        await setRepeatMode(AudioServiceRepeatMode.all);
        break;
      case RetroLoopMode.all:
        await setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RetroLoopMode.one:
        await setRepeatMode(AudioServiceRepeatMode.none);
        break;
    }
  }

  Future<void> toggleShuffle() async {
    await setShuffle(!_isShuffle);
  }

  Future<void> setShuffle(bool enabled) async {
    if (_isShuffle == enabled) return;
    _isShuffle = enabled;
    if (_isShuffle) {
      await _shuffleQueue();
    } else {
      await _unshuffleQueue();
    }
    _broadcastPlaybackState();
    saveCurrentPlaybackState();
  }

  Future<void> reshuffleQueue() async {
    if (_queue.length <= 1) return;
    _isShuffle = true;
    await _shuffleQueue();
  }

  Future<void> _shuffleQueue() async {
    if (_queue.length <= 1) return;
    if (_originalQueue.isEmpty || _originalQueue.length != _queue.length) {
      _originalQueue = List<Song>.from(_queue);
    }
    final current = currentSong;
    final oldList = List<Song>.from(_queue);

    if (current != null) {
      final others = List<Song>.from(_originalQueue);
      final currentIdxInOrig = others.indexWhere((s) => s.id == current.id);
      if (currentIdxInOrig != -1) {
        others.removeAt(currentIdxInOrig);
      }
      others.shuffle();
      _queue = [current, ...others];
      _currentIndex = 0;
    } else {
      _queue = List<Song>.from(_originalQueue)..shuffle();
      _currentIndex = 0;
    }

    await _syncPlaylistSourceOrder(oldList, _queue);
    if (current != null) {
      final finalIdx = _queue.indexWhere((s) => s.id == current.id);
      if (finalIdx != -1) {
        _currentIndex = finalIdx;
      }
    }
    queue.add(_queue.map(_toMediaItem).toList());
    _broadcastMediaItem(currentSong);
    _broadcastPlaybackState();
    _currentIndexController.add(_currentIndex);
  }

  Future<void> _unshuffleQueue() async {
    if (_originalQueue.isEmpty) return;
    final current = currentSong;
    final oldList = List<Song>.from(_queue);

    if (current != null) {
      final origIdx = _originalQueue.indexWhere((s) => s.id == current.id);
      if (origIdx != -1) {
        _queue = List<Song>.from(_originalQueue);
        _currentIndex = origIdx;
      } else {
        _queue = List<Song>.from(_originalQueue);
        _currentIndex = 0;
      }
    } else {
      _queue = List<Song>.from(_originalQueue);
      _currentIndex = 0;
    }

    await _syncPlaylistSourceOrder(oldList, _queue);
    if (current != null) {
      final finalIdx = _queue.indexWhere((s) => s.id == current.id);
      if (finalIdx != -1) {
        _currentIndex = finalIdx;
      }
    }
    queue.add(_queue.map(_toMediaItem).toList());
    _broadcastMediaItem(currentSong);
    _broadcastPlaybackState();
    _currentIndexController.add(_currentIndex);
  }

  Future<void> _syncPlaylistSourceOrder(List<Song> oldList, List<Song> targetQueue) async {
    if (_playlistSource == null || _playlistSource!.length != targetQueue.length) {
      return;
    }
    _isReorderingQueue = true;
    try {
      final currentIds = oldList.map((s) => s.id).toList();

      for (int targetIdx = 0; targetIdx < targetQueue.length; targetIdx++) {
        final targetId = targetQueue[targetIdx].id;
        final currentIdx = currentIds.indexOf(targetId);
        if (currentIdx != -1 && currentIdx != targetIdx) {
          try {
            await _playlistSource!.move(currentIdx, targetIdx);
            final movedId = currentIds.removeAt(currentIdx);
            currentIds.insert(targetIdx, movedId);
          } catch (e) {
            debugPrint("Error moving audio source in playlist: $e");
          }
        }
      }
    } finally {
      // Allow trailing asynchronous platform move events to arrive and be ignored
      await Future.delayed(const Duration(milliseconds: 100));
      _isReorderingQueue = false;
    }
  }

  Future<void> setRetroLoopMode(RetroLoopMode mode) async {
    switch (mode) {
      case RetroLoopMode.off:
        await setRepeatMode(AudioServiceRepeatMode.none);
        break;
      case RetroLoopMode.one:
        await setRepeatMode(AudioServiceRepeatMode.one);
        break;
      case RetroLoopMode.all:
        await setRepeatMode(AudioServiceRepeatMode.all);
        break;
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        _loopMode = RetroLoopMode.off;
        if (_playlistSource != null) {
          try {
            await _player.setLoopMode(LoopMode.off);
          } catch (_) {}
        }
        break;
      case AudioServiceRepeatMode.one:
        _loopMode = RetroLoopMode.one;
        if (_playlistSource != null) {
          try {
            await _player.setLoopMode(LoopMode.one);
          } catch (_) {}
        }
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        _loopMode = RetroLoopMode.all;
        if (_playlistSource != null) {
          try {
            await _player.setLoopMode(LoopMode.all);
          } catch (_) {}
        }
        break;
    }
    _broadcastPlaybackState();
    saveCurrentPlaybackState();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    await setShuffle(enabled);
  }

  @override
  Future<dynamic> customAction(String name, [Map<String, dynamic>? extras]) async {
    if (name == 'toggle_repeat') {
      await toggleLoopMode();
      return true;
    }
    if (name == 'toggle_shuffle') {
      await toggleShuffle();
      return true;
    }
    return super.customAction(name, extras);
  }

  // --- Sleep Timer ---
  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    if (duration == null || duration <= Duration.zero) {
      _sleepTimerRemaining = null;
      _sleepTimerController.add(null);
      return;
    }

    _sleepTimerRemaining = duration;
    _sleepTimerController.add(_sleepTimerRemaining);

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_sleepTimerRemaining == null) {
        timer.cancel();
        return;
      }

      final next = _sleepTimerRemaining! - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        timer.cancel();
        _sleepTimerRemaining = null;
        _sleepTimerController.add(null);
        pause();
      } else {
        _sleepTimerRemaining = next;
        _sleepTimerController.add(_sleepTimerRemaining);
      }
    });
  }

  // --- Equalizer & Band Gains ---
  void setEqualizerBand(int bandIndex, double gain) {
    if (bandIndex >= 0 && bandIndex < _bandGains.length) {
      final clamped = gain.clamp(-10.0, 10.0);
      _bandGains[bandIndex] = clamped;
      _equalizerService.setBandGain(bandIndex, clamped);
    }
  }

  void setEqualizerEnabled(bool enabled) {
    _equalizerEnabled = enabled;
    _equalizerService.setEnabled(enabled);
  }

  void applyPreset(List<double> gains) {
    for (int i = 0; i < _bandGains.length && i < gains.length; i++) {
      _bandGains[i] = gains[i].clamp(-10.0, 10.0);
    }
    _equalizerService.setAllBands(_bandGains);
  }

  // --- Spatial Audio & Virtualization ---
  Future<void> setSpatialAudioEnabled(bool enabled) async {
    _spatialAudioEnabled = enabled;
    await _spatialAudioService.setEnabled(enabled);
  }

  Future<void> setSpatialAudioStrength(int strength) async {
    _spatialAudioStrength = strength;
    await _spatialAudioService.setStrength(strength);
  }

  Future<void> setSpatialAudioMode(String mode) async {
    _spatialAudioMode = mode;
    await _spatialAudioService.setMode(mode);
  }

  Future<void> customDispose() async {
    _sleepTimer?.cancel();
    _systemVolumeService.dispose();
    _equalizerService.dispose();
    _spatialAudioService.dispose();
    await _sleepTimerController.close();
    await _currentIndexController.close();
    await _player.dispose();
  }
}
