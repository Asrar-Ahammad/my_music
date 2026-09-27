import 'song.dart';

class Playlist {
  final String id;
  final String name;
  final List<String> songIds;
  final DateTime createdAt;
  final bool isSystem;
  final String? customArtPath;

  const Playlist({
    required this.id,
    required this.name,
    required this.songIds,
    required this.createdAt,
    this.isSystem = false,
    this.customArtPath,
  });

  Playlist copyWith({
    String? id,
    String? name,
    List<String>? songIds,
    DateTime? createdAt,
    bool? isSystem,
    String? customArtPath,
    bool clearCustomArt = false,
  }) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songIds: songIds ?? this.songIds,
      createdAt: createdAt ?? this.createdAt,
      isSystem: isSystem ?? this.isSystem,
      customArtPath: clearCustomArt ? null : (customArtPath ?? this.customArtPath),
    );
  }

  /// Resolves the effective cover art path for this playlist:
  /// 1. Uses [customArtPath] if user explicitly added a cover image and file exists (or is asset).
  /// 2. Resiliently looks up songs by ID, URI, or filename.
  /// 3. Returns the cover art of the first song with valid artwork.
  String? resolveArtPath(List<Song> librarySongs) {
    if (customArtPath != null && customArtPath!.trim().isNotEmpty) {
      return customArtPath!.trim();
    }

    if (librarySongs.isEmpty || songIds.isEmpty) {
      return (customArtPath != null && customArtPath!.trim().isNotEmpty)
          ? customArtPath!.trim()
          : null;
    }

    final idMap = <String, Song>{};
    final uriMap = <String, Song>{};
    final baseMap = <String, Song>{};

    for (final s in librarySongs) {
      idMap[s.id] = s;
      uriMap[s.uri] = s;
      final base = s.uri.split('/').last.split('\\').last;
      if (base.isNotEmpty) {
        baseMap[base] = s;
      }
    }

    // 1. Direct O(1) matching by ID, URI, or filename
    for (final songId in songIds) {
      final song = idMap[songId] ?? uriMap[songId] ?? baseMap[songId];
      if (song != null && song.artPath != null && song.artPath!.trim().isNotEmpty) {
        return song.artPath!.trim();
      }
    }

    // 2. Secondary fallback: endsWith or substring matching
    for (final songId in songIds) {
      for (final song in librarySongs) {
        if (song.id == songId ||
            song.uri == songId ||
            song.uri.endsWith(songId) ||
            songId.endsWith(song.uri)) {
          if (song.artPath != null && song.artPath!.trim().isNotEmpty) {
            return song.artPath!.trim();
          }
        }
      }
    }

    // If customArtPath was set but couldn't be checked synchronously, return it
    if (customArtPath != null && customArtPath!.trim().isNotEmpty) {
      return customArtPath!.trim();
    }

    return null;
  }

  /// Returns the number of valid tracks in this playlist that exist in [librarySongs].
  /// If the library is still in initial load, falls back to [songIds.length].
  int getValidSongCount(List<Song> librarySongs, {bool isLoading = false}) {
    if (isLoading && librarySongs.isEmpty) {
      return songIds.length;
    }
    if (librarySongs.isEmpty || songIds.isEmpty) {
      return 0;
    }

    final validIds = <String>{};
    final validUris = <String>{};
    final validBases = <String>{};
    for (final s in librarySongs) {
      validIds.add(s.id);
      validUris.add(s.uri);
      final base = s.uri.split('/').last.split('\\').last;
      if (base.isNotEmpty) validBases.add(base);
    }

    return songIds.where((id) {
      if (validIds.contains(id) || validUris.contains(id) || validBases.contains(id)) {
        return true;
      }
      return librarySongs.any((s) => s.uri.endsWith(id) || id.endsWith(s.uri));
    }).length;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'songIds': songIds,
        'createdAt': createdAt.toIso8601String(),
        'isSystem': isSystem,
        'customArtPath': customArtPath,
      };

  factory Playlist.fromMap(Map<String, dynamic> map) {
    return Playlist(
      id: (map['id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Untitled Playlist',
      songIds: (map['songIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSystem: (map['isSystem'] as bool?) ?? false,
      customArtPath: (map['customArtPath'] as String?) ??
          (map['coverArt'] as String?) ??
          (map['artPath'] as String?) ??
          (map['coverPath'] as String?),
    );
  }
}
