import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/lyrics_service.dart';
import '../../domain/models/lrc_model.dart';
import '../../domain/models/song.dart';
import 'equalizer_provider.dart';
import 'player_provider.dart';

final lyricsServiceProvider = Provider<LyricsService>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return LyricsService(settingsRepository: repo);
});

class LyricsState {
  final LrcDocument? lyrics;
  final int activeLineIndex;
  final String? sourceName;
  final bool isLoading;
  final String? errorMessage;
  final String? songId;

  const LyricsState({
    this.lyrics,
    this.activeLineIndex = -1,
    this.sourceName,
    this.isLoading = false,
    this.errorMessage,
    this.songId,
  });

  LrcLine? get currentLine {
    if (lyrics != null && activeLineIndex >= 0 && activeLineIndex < lyrics!.lines.length) {
      return lyrics!.lines[activeLineIndex];
    }
    return null;
  }

  LyricsState copyWith({
    LrcDocument? lyrics,
    int? activeLineIndex,
    String? sourceName,
    bool? isLoading,
    String? errorMessage,
    String? songId,
    bool clearLyrics = false,
  }) {
    return LyricsState(
      lyrics: clearLyrics ? null : (lyrics ?? this.lyrics),
      activeLineIndex: activeLineIndex ?? this.activeLineIndex,
      sourceName: clearLyrics ? null : (sourceName ?? this.sourceName),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      songId: songId ?? (clearLyrics ? null : this.songId),
    );
  }
}

class LyricsNotifier extends Notifier<LyricsState> {
  String? _currentLoadedSongId;

  @override
  LyricsState build() {
    // Listen to changes in player state
    ref.listen<PlayerStateModel>(playerProvider, (previous, next) {
      final currentSong = next.currentSong;

      // If song changed, instantly reset and fetch new lyrics
      if (currentSong?.id != _currentLoadedSongId) {
        _currentLoadedSongId = currentSong?.id;
        if (currentSong != null) {
          state = LyricsState(isLoading: true, songId: currentSong.id);
          _fetchLyrics(currentSong);
        } else {
          state = const LyricsState();
        }
      } else if (state.lyrics != null && state.lyrics!.isSynced) {
        // Same song: update active line index based on playback position with anticipatory lead
        final newIndex = state.lyrics!.findLineIndexAt(
          next.position,
          anticipatoryLead: const Duration(milliseconds: 250),
        );
        if (newIndex != state.activeLineIndex) {
          state = state.copyWith(activeLineIndex: newIndex);
        }
      }
    });

    final initialSong = ref.read(playerProvider).currentSong;
    if (initialSong != null) {
      _currentLoadedSongId = initialSong.id;
      // Schedule initial load
      Future.microtask(() => _fetchLyrics(initialSong));
    }

    return const LyricsState();
  }

  Future<void> _fetchLyrics(Song song) async {
    state = LyricsState(
      isLoading: true,
      songId: song.id,
    );

    try {
      final service = ref.read(lyricsServiceProvider);
      final result = await service.getLyrics(song);

      // Verify song didn't change while awaiting
      if (_currentLoadedSongId != song.id) return;
      final currentPlaying = ref.read(playerProvider).currentSong;
      if (currentPlaying?.id != song.id) return;

      if (result != null) {
        int initialIdx = -1;
        if (result.document.isSynced) {
          final currentPos = ref.read(playerProvider).position;
          initialIdx = result.document.findLineIndexAt(
            currentPos,
            anticipatoryLead: const Duration(milliseconds: 250),
          );
        }
        state = LyricsState(
          lyrics: result.document,
          activeLineIndex: initialIdx,
          sourceName: result.sourceName,
          isLoading: false,
          songId: song.id,
        );
      } else {
        state = LyricsState(
          isLoading: false,
          songId: song.id,
          errorMessage: 'No lyrics found for this track',
        );
      }
    } catch (e) {
      if (_currentLoadedSongId == song.id) {
        state = LyricsState(
          isLoading: false,
          songId: song.id,
          errorMessage: 'Failed to load lyrics: $e',
        );
      }
    }
  }

  /// Manually refresh lyrics for the currently playing song
  Future<void> refreshLyrics() async {
    final currentSong = ref.read(playerProvider).currentSong;
    if (currentSong != null) {
      await _fetchLyrics(currentSong);
    }
  }

  /// Sets directly aligned or custom lyrics document
  void setCustomLyrics(LrcDocument document, String sourceName) {
    final currentPos = ref.read(playerProvider).position;
    final initialIdx = document.isSynced
        ? document.findLineIndexAt(currentPos, anticipatoryLead: const Duration(milliseconds: 250))
        : -1;
    state = state.copyWith(
      lyrics: document,
      activeLineIndex: initialIdx,
      sourceName: sourceName,
      isLoading: false,
      errorMessage: null,
    );
  }
}

final lyricsProvider = NotifierProvider<LyricsNotifier, LyricsState>(LyricsNotifier.new);
