import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/library_tagger_service.dart';
import '../../domain/models/ai_song_tags.dart';
import '../../domain/models/song.dart';
import 'library_provider.dart';
import 'player_provider.dart';

class LibraryTaggerState {
  final bool isScanning;
  final int scannedCount;
  final int totalCount;
  final String? currentSongTitle;
  final Map<String, AiSongTags> taggedSongs; // songId → AiSongTags
  final bool isComplete;
  final String? errorMessage;

  const LibraryTaggerState({
    this.isScanning = false,
    this.scannedCount = 0,
    this.totalCount = 0,
    this.currentSongTitle,
    this.taggedSongs = const {},
    this.isComplete = false,
    this.errorMessage,
  });

  double get progress => totalCount > 0 ? scannedCount / totalCount : 0.0;

  /// Distinct moods from tagged songs (for filter chips).
  Set<String> get availableMoods =>
      taggedSongs.values.map((t) => t.mood).whereType<String>().toSet();

  /// Distinct genres from tagged songs.
  Set<String> get availableGenres =>
      taggedSongs.values.map((t) => t.genre).whereType<String>().toSet();

  LibraryTaggerState copyWith({
    bool? isScanning,
    int? scannedCount,
    int? totalCount,
    String? currentSongTitle,
    Map<String, AiSongTags>? taggedSongs,
    bool? isComplete,
    String? errorMessage,
  }) {
    return LibraryTaggerState(
      isScanning: isScanning ?? this.isScanning,
      scannedCount: scannedCount ?? this.scannedCount,
      totalCount: totalCount ?? this.totalCount,
      currentSongTitle: currentSongTitle ?? this.currentSongTitle,
      taggedSongs: taggedSongs ?? this.taggedSongs,
      isComplete: isComplete ?? this.isComplete,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class LibraryTaggerNotifier extends Notifier<LibraryTaggerState> {
  final LibraryTaggerService _service = LibraryTaggerService();
  StreamSubscription<LibraryTaggerScanProgress>? _scanSubscription;

  @override
  LibraryTaggerState build() {
    ref.onDispose(() {
      _scanSubscription?.cancel();
    });
    // Load already-cached tags from Hive immediately
    Future.microtask(() => _loadCachedTags());
    return const LibraryTaggerState();
  }

  void _loadCachedTags() {
    final cached = _service.loadAllCachedTags();
    if (cached.isNotEmpty) {
      state = state.copyWith(taggedSongs: cached);
    }
  }

  /// Full rescan: clears ALL existing tags then re-analyses every song.
  /// Use this only when the user explicitly wants to wipe and redo everything.
  Future<void> rescan(List<Song> songs) async {
    await startScan(songs, forceRescan: true);
  }

  /// Incremental scan: only processes songs that have NO tag in the cache yet.
  /// Already-tagged songs are skipped; the existing tag store is untouched.
  Future<void> scanUncategorized(List<Song> allSongs) async {
    if (state.isScanning) return;

    final existingIds = state.taggedSongs.keys.toSet();
    final untagged = allSongs.where((s) => !existingIds.contains(s.id)).toList();

    if (untagged.isEmpty) {
      // Nothing new to tag — update isComplete flag so UI reflects this.
      state = state.copyWith(isComplete: true);
      return;
    }

    // Pass untagged list directly; service's onlyUntagged guard is redundant
    // here but safe to keep as a double-check.
    await startScan(untagged, forceRescan: false);
  }

  Future<void> startScan(List<Song> songs, {bool forceRescan = false}) async {
    if (state.isScanning) return;

    final targetSongs = songs.isNotEmpty ? songs : ref.read(libraryProvider).allSongs;
    if (targetSongs.isEmpty) return;

    await _scanSubscription?.cancel();

    if (forceRescan) {
      await _service.clearAllTags();
      state = state.copyWith(taggedSongs: {});
    }

    state = state.copyWith(
      isScanning: true,
      scannedCount: 0,
      totalCount: targetSongs.length,
      isComplete: false,
      errorMessage: null,
    );

    // Subscribe to progress events BEFORE starting scan
    _scanSubscription = _service.progressStream.listen((progress) {
      final currentTags = Map<String, AiSongTags>.from(state.taggedSongs);

      // Reload tags from Hive to keep state in sync
      final fresh = _service.loadAllCachedTags();
      currentTags.addAll(fresh);

      state = state.copyWith(
        isScanning: !progress.isComplete,
        scannedCount: progress.scanned,
        totalCount: progress.total > 0 ? progress.total : targetSongs.length,
        currentSongTitle: progress.currentSongTitle,
        taggedSongs: currentTags,
        isComplete: progress.isComplete,
        errorMessage: progress.error,
      );
    });

    // Determine whether audio is playing for throttle callback
    final playerHandler = ref.read(audioHandlerProvider);
    await _service.scanLibrary(
      targetSongs,
      isPlayingCallback: () => playerHandler.isPlaying,
      onlyUntagged: !forceRescan,
    );
  }

  void cancelScan() {
    _service.cancelScan();
    state = state.copyWith(isScanning: false, currentSongTitle: null);
  }

  Future<void> clearAllTags() async {
    await _service.clearAllTags();
    state = state.copyWith(taggedSongs: {}, isComplete: false);
  }

  /// Returns the tags for a specific song, or null.
  AiSongTags? getTagsForSong(String songId) {
    return state.taggedSongs[songId] ?? _service.getCachedTags(songId);
  }
}

final libraryTaggerProvider =
    NotifierProvider<LibraryTaggerNotifier, LibraryTaggerState>(LibraryTaggerNotifier.new);
