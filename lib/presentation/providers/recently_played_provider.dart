import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository.dart';
import '../../domain/models/recently_played_item.dart';
import '../../domain/models/song.dart';
import 'equalizer_provider.dart';

class RecentlyPlayedNotifier extends Notifier<List<RecentlyPlayedItem>> {
  SettingsRepository get _settingsRepository => ref.read(settingsRepositoryProvider);

  @override
  List<RecentlyPlayedItem> build() {
    try {
      final repo = ref.watch(settingsRepositoryProvider);
      final rawList = repo.getRecentlyPlayed();
      return rawList.map((m) => RecentlyPlayedItem.fromJson(m)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveToStorage(List<RecentlyPlayedItem> items) async {
    state = items;
    try {
      final serialized = items.map((i) => i.toJson()).toList();
      await _settingsRepository.saveRecentlyPlayed(serialized);
    } catch (_) {}
  }

  /// Records an album into recently played
  void recordAlbum({
    required String title,
    required String artist,
    String? artUri,
    String? id,
  }) {
    if (title.trim().isEmpty || title.toLowerCase() == 'unknown') return;
    final item = RecentlyPlayedItem(
      id: id ?? title,
      title: title,
      subtitle: artist.isNotEmpty && artist.toLowerCase() != 'unknown'
          ? artist
          : 'ALBUM',
      type: RecentItemType.album,
      artUri: artUri,
      playedAt: DateTime.now(),
    );
    _pushItem(item);
  }

  /// Records an artist into recently played
  void recordArtist({
    required String name,
    String? artUri,
    int songCount = 0,
  }) {
    if (name.trim().isEmpty || name.toLowerCase() == 'unknown') return;
    final item = RecentlyPlayedItem(
      id: name,
      title: name,
      subtitle: songCount > 0 ? '$songCount TRACKS' : 'ARTIST',
      type: RecentItemType.artist,
      artUri: artUri,
      playedAt: DateTime.now(),
    );
    _pushItem(item);
  }

  /// Records a playlist into recently played
  void recordPlaylist({
    required String id,
    required String name,
    String? coverArtPath,
    int songCount = 0,
  }) {
    if (id.trim().isEmpty || name.trim().isEmpty) return;
    final item = RecentlyPlayedItem(
      id: id,
      title: name,
      subtitle: songCount > 0 ? '$songCount TRACKS' : 'PLAYLIST',
      type: RecentItemType.playlist,
      artUri: coverArtPath,
      playedAt: DateTime.now(),
    );
    _pushItem(item);
  }

  /// Automatically deduces and records entities from a playing track
  void recordTrack(Song song, {String? playlistId}) {
    if (song.album.isNotEmpty && song.album.toLowerCase() != 'unknown') {
      recordAlbum(
        title: song.album,
        artist: song.artist,
        artUri: song.artPath,
      );
    } else if (song.artist.isNotEmpty && song.artist.toLowerCase() != 'unknown') {
      recordArtist(
        name: song.artist,
        artUri: song.artPath,
      );
    }
  }

  void _pushItem(RecentlyPlayedItem newItem) {
    final updated = List<RecentlyPlayedItem>.from(state);
    // Remove if same type and same id/title exists
    updated.removeWhere((i) =>
        i.type == newItem.type &&
        (i.id.toLowerCase() == newItem.id.toLowerCase() ||
            i.title.toLowerCase() == newItem.title.toLowerCase()));

    // Insert at front
    updated.insert(0, newItem);

    // Keep at most 20 recent items in persistence
    if (updated.length > 20) {
      updated.removeRange(20, updated.length);
    }

    _saveToStorage(updated);
  }

  /// Removes a playlist from recently played items and saves to storage
  void removePlaylist(String playlistId, [String? playlistName]) {
    final updated = List<RecentlyPlayedItem>.from(state);
    final targetId = playlistId.trim().toLowerCase();
    final targetName = playlistName?.trim().toLowerCase();
    updated.removeWhere((item) {
      if (item.type != RecentItemType.playlist) return false;
      final itemId = item.id.trim().toLowerCase();
      final itemTitle = item.title.trim().toLowerCase();
      return itemId == targetId ||
          (targetName != null && targetName.isNotEmpty && itemTitle == targetName) ||
          itemTitle == targetId;
    });

    if (updated.length != state.length) {
      _saveToStorage(updated);
    }
  }

  Future<void> clearRecents() async {
    await _saveToStorage([]);
  }
}

final recentlyPlayedProvider =
    NotifierProvider<RecentlyPlayedNotifier, List<RecentlyPlayedItem>>(
  RecentlyPlayedNotifier.new,
);
