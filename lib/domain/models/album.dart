import 'song.dart';

class Album {
  final String title;
  final String artist;
  final List<Song> songs;
  final String? artPath;

  const Album({
    required this.title,
    required this.artist,
    required this.songs,
    this.artPath,
  });

  int get trackCount => songs.length;
  Duration get totalDuration => songs.fold(
        Duration.zero,
        (prev, s) => prev + s.duration,
      );

  /// Returns explicit artPath or falls back to the first song with valid artPath
  String? get effectiveArtPath {
    if (artPath != null && artPath!.trim().isNotEmpty) {
      return artPath!.trim();
    }
    for (final song in songs) {
      if (song.artPath != null && song.artPath!.trim().isNotEmpty) {
        return song.artPath!.trim();
      }
    }
    return null;
  }
}
