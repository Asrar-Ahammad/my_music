enum RecentItemType { album, artist, playlist }

class RecentlyPlayedItem {
  final String id;
  final String title;
  final String subtitle;
  final RecentItemType type;
  final String? artUri;
  final DateTime playedAt;

  const RecentlyPlayedItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    this.artUri,
    required this.playedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'type': type.name,
        'artUri': artUri,
        'playedAt': playedAt.millisecondsSinceEpoch,
      };

  factory RecentlyPlayedItem.fromJson(Map<String, dynamic> json) =>
      RecentlyPlayedItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        type: RecentItemType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => RecentItemType.album,
        ),
        artUri: json['artUri'] as String?,
        playedAt: json['playedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['playedAt'] as int)
            : DateTime.now(),
      );

  RecentlyPlayedItem copyWith({
    String? id,
    String? title,
    String? subtitle,
    RecentItemType? type,
    String? artUri,
    DateTime? playedAt,
  }) {
    return RecentlyPlayedItem(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      artUri: artUri ?? this.artUri,
      playedAt: playedAt ?? this.playedAt,
    );
  }
}
