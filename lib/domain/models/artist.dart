import 'song.dart';

class Artist {
  final String name;
  final List<Song> songs;

  const Artist({
    required this.name,
    required this.songs,
  });

  int get trackCount => songs.length;
  int get albumCount => songs.map((s) => s.album).toSet().length;

  String? get artPath {
    for (final s in songs) {
      if (s.artPath != null && s.artPath!.trim().isNotEmpty) {
        return s.artPath!.trim();
      }
    }
    return null;
  }
}
