/// A single playback event recorded when a song is played.
/// Persisted in the listening_history Hive box for Sound Capsule analytics.
class ListeningEvent {
  final String songId;
  final String songTitle;
  final String artist;
  final String album;
  final String? genre;
  final String? artPath;

  /// How long the user actually listened (may be less than [songDuration] on skip).
  final Duration listenedDuration;

  /// Total duration of the song.
  final Duration songDuration;

  /// When playback of this song began.
  final DateTime timestamp;

  final String? playlistId;
  final String? folderPath;

  const ListeningEvent({
    required this.songId,
    required this.songTitle,
    required this.artist,
    required this.album,
    this.genre,
    this.artPath,
    required this.listenedDuration,
    required this.songDuration,
    required this.timestamp,
    this.playlistId,
    this.folderPath,
  });

  /// Whether this listen counts as a valid play (≥30 s or ≥50% of song).
  bool get countsAsPlay {
    if (listenedDuration.inSeconds >= 30) return true;
    if (songDuration.inSeconds > 0) {
      return listenedDuration.inSeconds / songDuration.inSeconds >= 0.5;
    }
    return false;
  }

  Map<String, dynamic> toMap() => {
        'songId': songId,
        'songTitle': songTitle,
        'artist': artist,
        'album': album,
        'genre': genre,
        'artPath': artPath,
        'listenedMs': listenedDuration.inMilliseconds,
        'songDurationMs': songDuration.inMilliseconds,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'playlistId': playlistId,
        'folderPath': folderPath,
      };

  factory ListeningEvent.fromMap(Map<dynamic, dynamic> map) {
    return ListeningEvent(
      songId: (map['songId'] as String?) ?? '',
      songTitle: (map['songTitle'] as String?) ?? 'Unknown',
      artist: (map['artist'] as String?) ?? 'Unknown Artist',
      album: (map['album'] as String?) ?? 'Unknown Album',
      genre: map['genre'] as String?,
      artPath: map['artPath'] as String?,
      listenedDuration:
          Duration(milliseconds: (map['listenedMs'] as int?) ?? 0),
      songDuration:
          Duration(milliseconds: (map['songDurationMs'] as int?) ?? 0),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      playlistId: map['playlistId'] as String?,
      folderPath: map['folderPath'] as String?,
    );
  }
}
