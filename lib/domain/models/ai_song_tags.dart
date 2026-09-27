/// Lightweight immutable value object for AI-generated song tags.
/// Stored in the dedicated `ai_song_tags_box` Hive box, keyed by [songId].
class AiSongTags {
  final String songId;

  /// Emotional mood: 'Chill', 'Melancholy', 'High Energy', 'Euphoric', 'Focus'
  final String? mood;

  /// Genre: 'Lo-Fi', 'Synthwave', 'Acoustic', 'Hip-Hop', 'Rock', 'Electronic', 'Classical'
  final String? genre;

  /// Energy level: 'Low', 'Medium', 'High'
  final String? energyLevel;

  /// Estimated beats per minute (rough estimate from zero-crossing rate analysis).
  final int? estimatedBpm;

  /// When these tags were generated.
  final DateTime? taggedAt;

  const AiSongTags({
    required this.songId,
    this.mood,
    this.genre,
    this.energyLevel,
    this.estimatedBpm,
    this.taggedAt,
  });

  Map<String, dynamic> toMap() => {
        'songId': songId,
        'mood': mood,
        'genre': genre,
        'energyLevel': energyLevel,
        'estimatedBpm': estimatedBpm,
        'taggedAt': taggedAt?.millisecondsSinceEpoch,
      };

  factory AiSongTags.fromMap(Map<String, dynamic> map) {
    return AiSongTags(
      songId: (map['songId'] as String?) ?? '',
      mood: map['mood'] as String?,
      genre: map['genre'] as String?,
      energyLevel: map['energyLevel'] as String?,
      estimatedBpm: map['estimatedBpm'] as int?,
      taggedAt: map['taggedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['taggedAt'] as int)
          : null,
    );
  }

  AiSongTags copyWith({
    String? mood,
    String? genre,
    String? energyLevel,
    int? estimatedBpm,
    DateTime? taggedAt,
  }) {
    return AiSongTags(
      songId: songId,
      mood: mood ?? this.mood,
      genre: genre ?? this.genre,
      energyLevel: energyLevel ?? this.energyLevel,
      estimatedBpm: estimatedBpm ?? this.estimatedBpm,
      taggedAt: taggedAt ?? this.taggedAt,
    );
  }

  @override
  String toString() =>
      'AiSongTags(songId: $songId, mood: $mood, genre: $genre, energyLevel: $energyLevel, bpm: $estimatedBpm)';
}
