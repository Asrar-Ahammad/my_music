import 'audio_quality.dart';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final String uri;
  final bool isAsset;
  final String? artPath;
  final AudioQuality quality;
  final bool isFavorite;
  final String folderPath;
  final int? trackNumber;
  final DateTime? dateAdded;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.uri,
    this.isAsset = false,
    this.artPath,
    required this.quality,
    this.isFavorite = false,
    this.folderPath = '',
    this.trackNumber,
    this.dateAdded,
  });

  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    String? uri,
    bool? isAsset,
    String? artPath,
    AudioQuality? quality,
    bool? isFavorite,
    String? folderPath,
    int? trackNumber,
    DateTime? dateAdded,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      uri: uri ?? this.uri,
      isAsset: isAsset ?? this.isAsset,
      artPath: artPath ?? this.artPath,
      quality: quality ?? this.quality,
      isFavorite: isFavorite ?? this.isFavorite,
      folderPath: folderPath ?? this.folderPath,
      trackNumber: trackNumber ?? this.trackNumber,
      dateAdded: dateAdded ?? this.dateAdded,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'uri': uri,
        'isAsset': isAsset,
        'artPath': artPath,
        'quality': quality.toMap(),
        'isFavorite': isFavorite,
        'folderPath': folderPath,
        'trackNumber': trackNumber,
        'dateAdded': dateAdded?.millisecondsSinceEpoch,
      };

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: (map['id'] as String?) ?? '',
      title: (map['title'] as String?) ?? 'Unknown Title',
      artist: (map['artist'] as String?) ?? 'Unknown Artist',
      album: (map['album'] as String?) ?? 'Unknown Album',
      duration: Duration(milliseconds: (map['durationMs'] as int?) ?? 0),
      uri: (map['uri'] as String?) ?? '',
      isAsset: (map['isAsset'] as bool?) ?? false,
      artPath: map['artPath'] as String?,
      quality: map['quality'] != null
          ? AudioQuality.fromMap(Map<String, dynamic>.from(map['quality'] as Map))
          : const AudioQuality(format: 'MP3'),
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      folderPath: (map['folderPath'] as String?) ?? '',
      trackNumber: map['trackNumber'] as int?,
      dateAdded: map['dateAdded'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['dateAdded'] as int)
          : (map['dateModified'] != null
              ? DateTime.fromMillisecondsSinceEpoch(map['dateModified'] as int)
              : null),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
