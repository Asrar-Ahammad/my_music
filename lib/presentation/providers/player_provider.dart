import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../data/services/audio_player_handler.dart';
import '../../data/services/listening_history_service.dart';
import '../../data/services/storage_service.dart';
import '../../domain/models/listening_event.dart';
import '../../domain/models/song.dart';
import 'library_provider.dart';
import 'playlist_provider.dart';
import 'recently_played_provider.dart';

class PlayerStateModel {
  final Song? currentSong;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final List<Song> queue;
  final int currentIndex;
  final RetroLoopMode loopMode;
  final bool isShuffle;
  final Duration? sleepTimerRemaining;
  final double volume;
  final String? currentPlaylistId;
  final int userQueueCount;

  const PlayerStateModel({
    this.currentSong,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.queue = const [],
    this.currentIndex = -1,
    this.loopMode = RetroLoopMode.off,
    this.isShuffle = false,
    this.sleepTimerRemaining,
    this.volume = 1.0,
    this.currentPlaylistId,
    this.userQueueCount = 0,
  });

  PlayerStateModel copyWith({
    Song? currentSong,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    List<Song>? queue,
    int? currentIndex,
    RetroLoopMode? loopMode,
    bool? isShuffle,
    Duration? sleepTimerRemaining,
    double? volume,
    String? currentPlaylistId,
    int? userQueueCount,
    bool clearSleepTimer = false,
    bool clearPlaylistId = false,
  }) {
    return PlayerStateModel(
      currentSong: currentSong ?? this.currentSong,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      queue: queue ?? this.queue,
      currentIndex: currentIndex ?? this.currentIndex,
      loopMode: loopMode ?? this.loopMode,
      isShuffle: isShuffle ?? this.isShuffle,
      sleepTimerRemaining: clearSleepTimer ? null : (sleepTimerRemaining ?? this.sleepTimerRemaining),
      volume: volume ?? this.volume,
      currentPlaylistId: clearPlaylistId ? null : (currentPlaylistId ?? this.currentPlaylistId),
      userQueueCount: userQueueCount ?? this.userQueueCount,
    );
  }
}

class PlayerNotifier extends Notifier<PlayerStateModel> {
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _indexSub;
  StreamSubscription? _sleepSub;
  StreamSubscription? _volumeSub;
  StreamSubscription? _playbackSub;

  // ── Listening history tracking ────────────────────────────────────────────
  final _historyService = ListeningHistoryService();
  Song? _trackingSession;      // song we started tracking
  DateTime? _trackingStart;    // when it started

  final StorageService _storage = StorageService();

  AudioPlayerHandler get _handler => ref.read(audioHandlerProvider);

  @override
  PlayerStateModel build() {
    final handler = ref.watch(audioHandlerProvider);
    _initListeners(handler);

    ref.onDispose(() {
      _posSub?.cancel();
      _durSub?.cancel();
      _stateSub?.cancel();
      _indexSub?.cancel();
      _sleepSub?.cancel();
      _volumeSub?.cancel();
      _playbackSub?.cancel();
      _flushCurrentSession(handler);
    });

    return PlayerStateModel(
      currentSong: handler.currentSong,
      isPlaying: handler.isPlaying,
      queue: handler.songQueue,
      currentIndex: handler.currentIndex,
      volume: handler.volume,
      isShuffle: handler.isShuffle,
      loopMode: handler.loopMode,
      position: handler.playbackPosition,
      duration: handler.currentDuration ?? handler.currentSong?.duration ?? Duration.zero,
      currentPlaylistId: handler.currentPlaylistId,
    );
  }

  void _initListeners(AudioPlayerHandler handler) {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _indexSub?.cancel();
    _sleepSub?.cancel();
    _volumeSub?.cancel();
    _playbackSub?.cancel();

    _posSub = handler.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });

    _durSub = handler.durationStream.listen((dur) {
      if (dur != null) {
        state = state.copyWith(duration: dur);
      }
    });

    _stateSub = handler.playerStateStream.listen((ps) {
      final isPlaying = ps.playing && ps.processingState != ProcessingState.completed;
      state = state.copyWith(
        isPlaying: isPlaying,
        currentSong: handler.currentSong ?? state.currentSong,
        currentIndex: handler.currentIndex >= 0 ? handler.currentIndex : state.currentIndex,
        queue: handler.songQueue.isNotEmpty ? handler.songQueue : state.queue,
      );
    });

    _indexSub = handler.currentIndexStream.listen((idx) {
      // ── Record listening event for the PREVIOUS song ──────────────────────
      _flushCurrentSession(handler);

      if (idx != null && idx >= 0 && idx < handler.songQueue.length) {
        state = state.copyWith(
          currentIndex: idx,
          currentSong: handler.songQueue[idx],
          queue: handler.songQueue,
        );
        // ── Start tracking the NEW song ───────────────────────────────────
        _startSession(handler.songQueue[idx]);
      } else if (handler.currentSong != null) {
        state = state.copyWith(
          currentSong: handler.currentSong,
          queue: handler.songQueue,
        );
        _startSession(handler.currentSong!);
      }
    });

    _sleepSub = handler.sleepTimerStream.listen((rem) {
      state = state.copyWith(
        sleepTimerRemaining: rem,
        clearSleepTimer: rem == null,
      );
    });

    _volumeSub = handler.volumeStream.listen((vol) {
      state = state.copyWith(volume: vol);
    });

      _playbackSub = handler.playbackState.listen((ps) {
      final isShuffle = ps.shuffleMode == AudioServiceShuffleMode.all;
      final loopMode = switch (ps.repeatMode) {
        AudioServiceRepeatMode.one => RetroLoopMode.one,
        AudioServiceRepeatMode.all || AudioServiceRepeatMode.group => RetroLoopMode.all,
        _ => RetroLoopMode.off,
      };
      state = state.copyWith(
        isShuffle: isShuffle,
        loopMode: loopMode,
      );
    });
  }

  // ── Listening history session helpers ─────────────────────────────────────

  void _startSession(Song song) {
    _trackingSession = song;
    _trackingStart = DateTime.now();
  }

  void _flushCurrentSession(AudioPlayerHandler handler) {
    final song = _trackingSession;
    final start = _trackingStart;
    if (song == null || start == null) return;

    final elapsed = DateTime.now().difference(start);
    // Only count time up to song duration
    var listened = elapsed;
    if (song.duration > Duration.zero && listened > song.duration) {
      listened = song.duration;
    } else if (listened > const Duration(minutes: 30)) {
      listened = const Duration(minutes: 30);
    }
    final event = ListeningEvent(
      songId: song.id,
      songTitle: song.title,
      artist: song.artist,
      album: song.album,
      genre: null,
      artPath: song.artPath?.isNotEmpty == true ? song.artPath : null,
      listenedDuration: listened,
      songDuration: song.duration,
      timestamp: start,
      playlistId: state.currentPlaylistId,
    );

    _historyService.recordPlay(event);
    _trackingSession = null;
    _trackingStart = null;
  }

  Future<void> playSong(
    Song song, {
    List<Song>? queue,
    List<Song>? originalQueue,
    String? playlistId,
    bool? isShuffle,
  }) async {
    final effectiveShuffle = isShuffle ?? state.isShuffle;
    final list = queue ?? [song];
    final original = originalQueue ?? list;

    List<Song> playQueue;
    int targetIndex = 0;

    if (effectiveShuffle && list.length > 1) {
      final others = List<Song>.from(original)
        ..removeWhere((s) => s.id == song.id)
        ..shuffle();
      playQueue = [song, ...others];
      targetIndex = 0;
    } else {
      playQueue = list;
      final index = playQueue.indexWhere((s) => s.id == song.id);
      targetIndex = index != -1 ? index : 0;
    }

    state = state.copyWith(
      currentSong: song,
      queue: playQueue,
      currentIndex: targetIndex,
      position: Duration.zero,
      duration: song.duration,
      currentPlaylistId: playlistId,
      clearPlaylistId: playlistId == null,
      isShuffle: effectiveShuffle,
    );

    ref.read(recentlyPlayedProvider.notifier).recordTrack(song, playlistId: playlistId);
    await _handler.setQueueAndPlay(
      playQueue,
      targetIndex,
      originalList: original,
      isShuffle: effectiveShuffle,
      playlistId: playlistId,
    );
  }

  Future<void> shuffleList(
    List<Song> songs, {
    String? playlistId,
  }) async {
    if (songs.isEmpty) return;
    final shuffled = List<Song>.from(songs)..shuffle();
    await _handler.setShuffle(true);
    await playSong(
      shuffled.first,
      queue: shuffled,
      originalQueue: songs,
      playlistId: playlistId,
      isShuffle: true,
    );
  }

  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await _handler.pause();
    } else {
      if (state.currentSong == null && state.queue.isNotEmpty) {
        await playSong(state.queue.first, queue: state.queue);
      } else {
        await _handler.play();
        _syncQueueState();
      }
    }
  }

  Future<void> seek(Duration position) async {
    state = state.copyWith(position: position);
    await _handler.seek(position);
  }

  Future<void> skipToNext() async {
    await _handler.skipToNext();
    _syncQueueState();
  }

  Future<void> skipToPrevious() async {
    await _handler.skipToPrevious();
    _syncQueueState();
  }

  Future<void> playAtIndex(int index) async {
    await _handler.playAtIndex(index);
    _syncQueueState();
  }

  void addToQueue(Song song) {
    _handler.addSongToQueue(song);
    _syncQueueState();
  }

  void addNext(Song song) {
    _handler.addSongNext(song);
    _syncQueueState();
  }

  void removeQueueAt(int index) {
    _handler.removeQueueAt(index);
    _syncQueueState();
  }

  void reorderQueue(int oldIndex, int newIndex) {
    _handler.reorderQueue(oldIndex, newIndex);
    _syncQueueState();
  }

  Future<void> clearQueue() async {
    // Optimistically update state immediately so UI clears instantly with zero delay
    if (state.currentSong != null) {
      state = state.copyWith(
        queue: [state.currentSong!],
        currentIndex: 0,
      );
    } else {
      state = state.copyWith(
        queue: [],
        currentIndex: -1,
        currentSong: null,
        isPlaying: false,
        position: Duration.zero,
      );
    }

    await _handler.clearQueue();
    if (_handler.currentSong != null) {
      _syncQueueState();
    }
  }

  Future<void> toggleLoop() async {
    await _handler.toggleLoopMode();
    state = state.copyWith(loopMode: _handler.loopMode);
    _saveCurrentPlaylistSettings();
  }

  Future<void> toggleShuffle() async {
    await _handler.toggleShuffle();
    state = state.copyWith(
      isShuffle: _handler.isShuffle,
      queue: _handler.songQueue,
      currentIndex: _handler.currentIndex,
      currentSong: _handler.currentSong,
    );
    _saveCurrentPlaylistSettings();
  }

  void _saveCurrentPlaylistSettings() {
    final playlistId = state.currentPlaylistId;
    if (playlistId != null) {
      _storage.savePlaylistPlaybackSettings(
        playlistId,
        isShuffle: state.isShuffle,
        loopMode: state.loopMode.name,
      );
    }
  }

  Future<void> playPlaylist({
    required String playlistId,
    required List<Song> songs,
    Song? initialSong,
    bool? forceShuffle,
  }) async {
    if (songs.isEmpty) return;

    // 1. Retrieve stored preferences for this playlist
    final settings = _storage.getPlaylistPlaybackSettings(playlistId);
    final savedShuffle = settings['isShuffle'] as bool? ?? false;
    final savedLoopStr = settings['loopMode'] as String? ?? 'off';
    final savedLoop = RetroLoopMode.values.firstWhere(
      (e) => e.name == savedLoopStr,
      orElse: () => RetroLoopMode.off,
    );

    // 2. Determine target shuffle & loop modes
    final targetShuffle = forceShuffle ?? savedShuffle;
    final targetLoop = savedLoop;

    // 3. Apply loop mode to handler (shuffle is set via setQueueAndPlay)
    await _handler.setRetroLoopMode(targetLoop);

    // 4. Save settings if forceShuffle was specified or updated
    if (forceShuffle != null) {
      _storage.savePlaylistPlaybackSettings(
        playlistId,
        isShuffle: targetShuffle,
        loopMode: targetLoop.name,
      );
    }

    // 5. Construct play queue and select start track
    List<Song> playQueue;
    int targetIndex = 0;

    if (targetShuffle) {
      if (initialSong != null) {
        final otherSongs = List<Song>.from(songs)
          ..removeWhere((s) => s.id == initialSong.id)
          ..shuffle();
        playQueue = [initialSong, ...otherSongs];
        targetIndex = 0;
      } else {
        playQueue = List<Song>.from(songs)..shuffle();
        targetIndex = 0;
      }
    } else {
      playQueue = List<Song>.from(songs);
      if (initialSong != null) {
        final idx = playQueue.indexWhere((s) => s.id == initialSong.id);
        targetIndex = idx != -1 ? idx : 0;
      } else {
        targetIndex = 0;
      }
    }

    final startSong = playQueue[targetIndex];

    state = state.copyWith(
      currentSong: startSong,
      queue: playQueue,
      currentIndex: targetIndex,
      position: Duration.zero,
      duration: startSong.duration,
      currentPlaylistId: playlistId,
      isShuffle: targetShuffle,
      loopMode: targetLoop,
    );

    final playlists = ref.read(playlistProvider).playlists;
    final pl = playlists.where((p) => p.id == playlistId).firstOrNull;
    if (pl != null) {
      final librarySongs = ref.read(libraryProvider).allSongs;
      final coverArt = pl.resolveArtPath(librarySongs);
      ref.read(recentlyPlayedProvider.notifier).recordPlaylist(
            id: pl.id,
            name: pl.name,
            coverArtPath: coverArt,
            songCount: pl.getValidSongCount(librarySongs),
          );
    }

    await _handler.setQueueAndPlay(
      playQueue,
      targetIndex,
      originalList: songs,
      isShuffle: targetShuffle,
      playlistId: playlistId,
    );
  }

  Future<void> reshuffleQueue() async {
    if (state.queue.length <= 1) return;
    await _handler.reshuffleQueue();
    state = state.copyWith(
      isShuffle: true,
      queue: _handler.songQueue,
      currentIndex: _handler.currentIndex,
      currentSong: _handler.currentSong,
    );
    _saveCurrentPlaylistSettings();
  }

  void shuffleAll(List<Song> allSongs) {
    if (allSongs.isEmpty) return;
    final shuffled = List<Song>.from(allSongs)..shuffle();
    if (!_handler.isShuffle) {
      _handler.setShuffle(true);
      state = state.copyWith(isShuffle: true);
    }
    playSong(shuffled.first, queue: shuffled, originalQueue: allSongs, isShuffle: true);
  }

  void shuffleAlbum(List<Song> allSongs, String albumName) {
    final albumSongs = allSongs
        .where((s) => s.album.toLowerCase() == albumName.toLowerCase())
        .toList();
    if (albumSongs.isEmpty) return;
    final shuffled = List<Song>.from(albumSongs)..shuffle();
    if (!_handler.isShuffle) {
      _handler.setShuffle(true);
      state = state.copyWith(isShuffle: true);
    }
    playSong(shuffled.first, queue: shuffled, originalQueue: albumSongs, isShuffle: true);
  }

  void shuffleArtist(List<Song> allSongs, String artistName) {
    final artistSongs = allSongs
        .where((s) => s.artist.toLowerCase() == artistName.toLowerCase())
        .toList();
    if (artistSongs.isEmpty) return;
    final shuffled = List<Song>.from(artistSongs)..shuffle();
    if (!_handler.isShuffle) {
      _handler.setShuffle(true);
      state = state.copyWith(isShuffle: true);
    }
    playSong(shuffled.first, queue: shuffled, originalQueue: artistSongs, isShuffle: true);
  }

  void setSleepTimer(Duration? duration) {
    _handler.setSleepTimer(duration);
  }

  void setVolume(double volume) {
    final clamped = volume.clamp(0.0, 1.0);
    _handler.setVolume(clamped);
    state = state.copyWith(volume: clamped);
  }

  void updateSongFavorite(String songId, bool isFavorite) {
    _handler.updateSongInQueue(songId, isFavorite: isFavorite);

    Song? updatedCurrent = state.currentSong;
    if (updatedCurrent != null && updatedCurrent.id == songId) {
      updatedCurrent = updatedCurrent.copyWith(isFavorite: isFavorite);
    }
    final updatedQueue = state.queue.map((s) {
      if (s.id == songId) {
        return s.copyWith(isFavorite: isFavorite);
      }
      return s;
    }).toList();

    state = state.copyWith(
      currentSong: updatedCurrent,
      queue: updatedQueue,
    );
  }

  void _syncQueueState() {
    state = state.copyWith(
      queue: _handler.songQueue,
      currentIndex: _handler.currentIndex,
      currentSong: _handler.currentSong,
      userQueueCount: _handler.userQueueCount,
    );
  }
}

final audioHandlerProvider = Provider<AudioPlayerHandler>((ref) {
  return AudioPlayerHandler();
});

final playerProvider = NotifierProvider<PlayerNotifier, PlayerStateModel>(PlayerNotifier.new);
