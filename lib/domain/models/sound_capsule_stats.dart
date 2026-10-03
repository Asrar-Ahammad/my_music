/// Period granularity for a Sound Capsule.
enum CapsulePeriod { weekly, monthly }

/// Day of week enum for peak activity analysis.
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get label => name[0].toUpperCase() + name.substring(1);
  String get shortLabel => name.substring(0, 3).toUpperCase();
}

/// A ranked item in a top-N list (artist, song, album, genre).
class RankedItem {
  final String id;
  final String name;
  final String? subtitle;
  final String? artPath;
  final int playCount;
  final Duration listenTime;
  final int rank;

  const RankedItem({
    required this.id,
    required this.name,
    this.subtitle,
    this.artPath,
    required this.playCount,
    required this.listenTime,
    required this.rank,
  });
}

/// An artist streak: consecutive days listening to a single artist.
class ArtistStreak {
  final String artistName;
  final String? artPath;
  final int days;
  final DateTime startDate;
  final DateTime endDate;

  const ArtistStreak({
    required this.artistName,
    this.artPath,
    required this.days,
    required this.startDate,
    required this.endDate,
  });
}

/// An eclectic genre pairing found in the user's listening history.
class UnlikelyCombo {
  final String genreA;
  final String genreB;

  const UnlikelyCombo({required this.genreA, required this.genreB});
}

/// Daily listening stats for the activity heatmap.
class DailyListeningStats {
  final DateTime date;
  final Duration totalTime;
  final int trackCount;

  const DailyListeningStats({
    required this.date,
    required this.totalTime,
    required this.trackCount,
  });

  /// Intensity 0.0–1.0 relative to the max day in the period.
  double intensityRelativeTo(Duration maxDayDuration) {
    if (maxDayDuration.inSeconds == 0) return 0;
    return (totalTime.inSeconds / maxDayDuration.inSeconds).clamp(0.0, 1.0);
  }
}

/// The full aggregated statistics for a Sound Capsule period.
class SoundCapsuleStats {
  final DateTime periodStart;
  final DateTime periodEnd;
  final CapsulePeriod period;

  // ── Core metrics ──────────────────────────────────────────────────────────
  final Duration totalListeningTime;
  final int totalTracksPlayed;
  final int uniqueTracksPlayed;
  final int uniqueArtists;
  final int uniqueAlbums;
  final int daysActive;

  // ── Rankings ──────────────────────────────────────────────────────────────
  final List<RankedItem> topArtists;
  final List<RankedItem> topSongs;
  final List<RankedItem> topAlbums;
  final List<RankedItem> topGenres;

  // ── Fun insights ──────────────────────────────────────────────────────────
  final ArtistStreak? longestStreak;
  final List<UnlikelyCombo> unlikelyCombos;
  final List<RankedItem> throwbacks;
  final DayOfWeek? mostActiveDay;
  final int peakHour; // 0–23

  // ── Activity heatmap ──────────────────────────────────────────────────────
  final List<DailyListeningStats> dailyStats;

  // ── Audio quality ─────────────────────────────────────────────────────────
  final Map<String, Duration> qualityBreakdown;

  const SoundCapsuleStats({
    required this.periodStart,
    required this.periodEnd,
    required this.period,
    required this.totalListeningTime,
    required this.totalTracksPlayed,
    required this.uniqueTracksPlayed,
    required this.uniqueArtists,
    required this.uniqueAlbums,
    required this.daysActive,
    required this.topArtists,
    required this.topSongs,
    required this.topAlbums,
    required this.topGenres,
    this.longestStreak,
    this.unlikelyCombos = const [],
    this.throwbacks = const [],
    this.mostActiveDay,
    this.peakHour = 0,
    this.dailyStats = const [],
    this.qualityBreakdown = const {},
  });

  /// Whether this capsule has enough data to be useful.
  bool get hasData => totalTracksPlayed >= 1;

  SoundCapsuleStats copyWith({
    DateTime? periodStart,
    DateTime? periodEnd,
    CapsulePeriod? period,
    Duration? totalListeningTime,
    int? totalTracksPlayed,
    int? uniqueTracksPlayed,
    int? uniqueArtists,
    int? uniqueAlbums,
    int? daysActive,
    List<RankedItem>? topArtists,
    List<RankedItem>? topSongs,
    List<RankedItem>? topAlbums,
    List<RankedItem>? topGenres,
    ArtistStreak? longestStreak,
    List<UnlikelyCombo>? unlikelyCombos,
    List<RankedItem>? throwbacks,
    DayOfWeek? mostActiveDay,
    int? peakHour,
    List<DailyListeningStats>? dailyStats,
    Map<String, Duration>? qualityBreakdown,
  }) {
    return SoundCapsuleStats(
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      period: period ?? this.period,
      totalListeningTime: totalListeningTime ?? this.totalListeningTime,
      totalTracksPlayed: totalTracksPlayed ?? this.totalTracksPlayed,
      uniqueTracksPlayed: uniqueTracksPlayed ?? this.uniqueTracksPlayed,
      uniqueArtists: uniqueArtists ?? this.uniqueArtists,
      uniqueAlbums: uniqueAlbums ?? this.uniqueAlbums,
      daysActive: daysActive ?? this.daysActive,
      topArtists: topArtists ?? this.topArtists,
      topSongs: topSongs ?? this.topSongs,
      topAlbums: topAlbums ?? this.topAlbums,
      topGenres: topGenres ?? this.topGenres,
      longestStreak: longestStreak ?? this.longestStreak,
      unlikelyCombos: unlikelyCombos ?? this.unlikelyCombos,
      throwbacks: throwbacks ?? this.throwbacks,
      mostActiveDay: mostActiveDay ?? this.mostActiveDay,
      peakHour: peakHour ?? this.peakHour,
      dailyStats: dailyStats ?? this.dailyStats,
      qualityBreakdown: qualityBreakdown ?? this.qualityBreakdown,
    );
  }

  /// Human-readable total time, e.g. "2h 34m" or "47 min".
  String get formattedTotalTime {
    final h = totalListeningTime.inHours;
    final m = totalListeningTime.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${totalListeningTime.inMinutes}m';
  }

  /// Period label, e.g. "October 2026" or "Sep 29 – Oct 5".
  String get periodLabel {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    if (period == CapsulePeriod.monthly) {
      return '${months[periodStart.month - 1]} ${periodStart.year}';
    } else {
      final sm = months[periodStart.month - 1].substring(0, 3);
      final em = months[periodEnd.month - 1].substring(0, 3);
      return '$sm ${periodStart.day} – $em ${periodEnd.day}';
    }
  }

  static SoundCapsuleStats empty(DateTime periodStart, DateTime periodEnd,
      CapsulePeriod period) {
    return SoundCapsuleStats(
      periodStart: periodStart,
      periodEnd: periodEnd,
      period: period,
      totalListeningTime: Duration.zero,
      totalTracksPlayed: 0,
      uniqueTracksPlayed: 0,
      uniqueArtists: 0,
      uniqueAlbums: 0,
      daysActive: 0,
      topArtists: const [],
      topSongs: const [],
      topAlbums: const [],
      topGenres: const [],
    );
  }
}
