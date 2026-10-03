import '../../domain/models/listening_event.dart';
import '../../domain/models/sound_capsule_stats.dart';
import '../services/artist_photo_service.dart';
import '../services/listening_history_service.dart';

/// Aggregates raw [ListeningEvent]s into [SoundCapsuleStats] for a given period.
class SoundCapsuleRepository {
  SoundCapsuleRepository({ListeningHistoryService? service})
      : _service = service ?? ListeningHistoryService();

  final ListeningHistoryService _service;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Stats for the current calendar month.
  SoundCapsuleStats getCurrentMonthStats() {
    final now = DateTime.now();
    return getMonthlyStats(now.year, now.month);
  }

  /// Stats for any past calendar month.
  SoundCapsuleStats getMonthlyStats(int year, int month) {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1)
        .subtract(const Duration(microseconds: 1));
    final events = _service.getEventsInRange(start, end);
    return _aggregate(events, start, end, CapsulePeriod.monthly);
  }

  /// Stats for the ISO week containing [weekStart] (any day of the week).
  SoundCapsuleStats getWeeklyStats(DateTime weekStart) {
    final monday = weekStart.subtract(
        Duration(days: weekStart.weekday - DateTime.monday));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = start.add(const Duration(days: 6, hours: 23, minutes: 59,
        seconds: 59));
    final events = _service.getEventsInRange(start, end);
    return _aggregate(events, start, end, CapsulePeriod.weekly);
  }

  /// Months that have at least one listen event, most recent first.
  List<DateTime> getAvailableMonths() => _service.getAvailableMonths();

  // ── Aggregation core ───────────────────────────────────────────────────────

  SoundCapsuleStats _aggregate(
    List<ListeningEvent> events,
    DateTime start,
    DateTime end,
    CapsulePeriod period,
  ) {
    if (events.isEmpty) return SoundCapsuleStats.empty(start, end, period);

    // ── Basic counters ───────────────────────────────────────────────────────
    Duration totalTime = Duration.zero;
    final uniqueSongs = <String>{};
    final uniqueArtists = <String>{};
    final uniqueAlbums = <String>{};
    final activeDays = <String>{};

    // ── Accumulator maps ─────────────────────────────────────────────────────
    final artistTime = <String, Duration>{};
    final artistCount = <String, int>{};
    final artistArt = <String, String?>{};
    final artistSongTime = <String, Map<String, Duration>>{};
    final artistSongArt = <String, Map<String, String?>>{};

    final songTime = <String, Duration>{};
    final songCount = <String, int>{};
    final songMeta = <String, ListeningEvent>{};

    final albumTime = <String, Duration>{};
    final albumCount = <String, int>{};
    final albumArt = <String, String?>{};
    final albumArtist = <String, String>{};

    final genreTime = <String, Duration>{};
    final genreCount = <String, int>{};

    // ── Daily buckets for heatmap & peak-hour ────────────────────────────────
    final hourCount = <int, int>{};
    final dayCount = <int, Duration>{}; // weekday 1-7 → time

    // ── Artist streak tracking ───────────────────────────────────────────────
    final artistByDay = <String, Set<String>>{}; // dateStr → set of artist ids

    for (final e in events) {
      Duration duration = e.listenedDuration;
      if (e.songDuration > Duration.zero && duration > e.songDuration) {
        duration = e.songDuration;
      } else if (duration > const Duration(minutes: 30)) {
        duration = const Duration(minutes: 30);
      }

      final primaryArtist = ArtistPhotoService.extractPrimaryArtist(e.artist);

      totalTime += duration;
      uniqueSongs.add(e.songId);
      uniqueArtists.add(primaryArtist);
      uniqueAlbums.add(e.album);

      final dayStr = _dayKey(e.timestamp);
      activeDays.add(dayStr);

      // Artist
      artistTime[primaryArtist] =
          (artistTime[primaryArtist] ?? Duration.zero) + duration;
      artistCount[primaryArtist] = (artistCount[primaryArtist] ?? 0) + 1;

      // Artist song tracking for top song cover art
      artistSongTime.putIfAbsent(primaryArtist, () => {});
      artistSongTime[primaryArtist]![e.songId] =
          (artistSongTime[primaryArtist]![e.songId] ?? Duration.zero) + duration;
      if (e.artPath != null && e.artPath!.isNotEmpty) {
        artistSongArt.putIfAbsent(primaryArtist, () => {});
        artistSongArt[primaryArtist]![e.songId] = e.artPath;
      }

      // Song
      songTime[e.songId] =
          (songTime[e.songId] ?? Duration.zero) + duration;
      songCount[e.songId] = (songCount[e.songId] ?? 0) + 1;
      songMeta.putIfAbsent(e.songId, () => e);

      // Album
      albumTime[e.album] =
          (albumTime[e.album] ?? Duration.zero) + duration;
      albumCount[e.album] = (albumCount[e.album] ?? 0) + 1;
      albumArt.putIfAbsent(e.album, () => e.artPath);
      albumArtist.putIfAbsent(e.album, () => primaryArtist);

      // Genre
      if (e.genre != null && e.genre!.isNotEmpty) {
        genreTime[e.genre!] =
            (genreTime[e.genre!] ?? Duration.zero) + duration;
        genreCount[e.genre!] = (genreCount[e.genre!] ?? 0) + 1;
      }

      // Hour
      hourCount[e.timestamp.hour] =
          (hourCount[e.timestamp.hour] ?? 0) + 1;

      // Day of week
      dayCount[e.timestamp.weekday] =
          (dayCount[e.timestamp.weekday] ?? Duration.zero) + duration;

      // Artist streak data
      artistByDay.putIfAbsent(dayStr, () => {});
      artistByDay[dayStr]!.add(primaryArtist);
    }

    // Pick top song's cover art as the artist profile photo
    for (final artist in artistTime.keys) {
      final songs = artistSongTime[artist];
      if (songs != null && songs.isNotEmpty) {
        final sortedSongIds = songs.keys.toList()
          ..sort((a, b) => songs[b]!.compareTo(songs[a]!));
        for (final songId in sortedSongIds) {
          final art = artistSongArt[artist]?[songId];
          if (art != null && art.isNotEmpty) {
            artistArt[artist] = art;
            break;
          }
        }
      }
    }

    // ── Build ranked lists ───────────────────────────────────────────────────
    final topArtists = _rankArtists(artistTime, artistCount, artistArt);
    final topSongs = _rankSongs(songTime, songCount, songMeta);
    final topAlbums =
        _rankAlbums(albumTime, albumCount, albumArt, albumArtist);
    final topGenres = _rankGenres(genreTime, genreCount);

    // ── Peak hour ────────────────────────────────────────────────────────────
    int peakHour = 0;
    int peakHourCount = 0;
    hourCount.forEach((h, c) {
      if (c > peakHourCount) {
        peakHourCount = c;
        peakHour = h;
      }
    });

    // ── Most active day of week ──────────────────────────────────────────────
    DayOfWeek? mostActiveDay;
    Duration maxDayTime = Duration.zero;
    dayCount.forEach((wd, t) {
      if (t > maxDayTime) {
        maxDayTime = t;
        mostActiveDay = DayOfWeek.values[wd - 1]; // weekday 1=Mon
      }
    });

    // ── Longest artist streak ────────────────────────────────────────────────
    final streak = _computeLongestStreak(artistByDay, start, end, artistArt);

    // ── Unlikely combos ──────────────────────────────────────────────────────
    final unlikelyCombos = _findUnlikelyCombos(topGenres);

    // ── Throwbacks (songs from >60 days ago replayed this period) ────────────
    final throwbacks = _findThrowbacks(events, start);

    // ── Daily stats for heatmap ──────────────────────────────────────────────
    final dailyStats = _buildDailyStats(events, start, end);

    return SoundCapsuleStats(
      periodStart: start,
      periodEnd: end,
      period: period,
      totalListeningTime: totalTime,
      totalTracksPlayed: events.length,
      uniqueTracksPlayed: uniqueSongs.length,
      uniqueArtists: uniqueArtists.length,
      uniqueAlbums: uniqueAlbums.length,
      daysActive: activeDays.length,
      topArtists: topArtists,
      topSongs: topSongs,
      topAlbums: topAlbums,
      topGenres: topGenres,
      longestStreak: streak,
      unlikelyCombos: unlikelyCombos,
      throwbacks: throwbacks,
      mostActiveDay: mostActiveDay,
      peakHour: peakHour,
      dailyStats: dailyStats,
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  String _dayKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';

  List<RankedItem> _rankArtists(
    Map<String, Duration> timeMap,
    Map<String, int> countMap,
    Map<String, String?> artMap,
  ) {
    final entries = timeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).toList().asMap().entries.map((e) {
      final name = e.value.key;
      return RankedItem(
        id: name,
        name: name,
        artPath: artMap[name],
        playCount: countMap[name] ?? 0,
        listenTime: e.value.value,
        rank: e.key + 1,
      );
    }).toList();
  }

  List<RankedItem> _rankSongs(
    Map<String, Duration> timeMap,
    Map<String, int> countMap,
    Map<String, ListeningEvent> meta,
  ) {
    final entries = timeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).toList().asMap().entries.map((e) {
      final id = e.value.key;
      final m = meta[id];
      return RankedItem(
        id: id,
        name: m?.songTitle ?? id,
        subtitle: m?.artist,
        artPath: m?.artPath,
        playCount: countMap[id] ?? 0,
        listenTime: e.value.value,
        rank: e.key + 1,
      );
    }).toList();
  }

  List<RankedItem> _rankAlbums(
    Map<String, Duration> timeMap,
    Map<String, int> countMap,
    Map<String, String?> artMap,
    Map<String, String> artistMap,
  ) {
    final entries = timeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(10).toList().asMap().entries.map((e) {
      final title = e.value.key;
      return RankedItem(
        id: title,
        name: title,
        subtitle: artistMap[title],
        artPath: artMap[title],
        playCount: countMap[title] ?? 0,
        listenTime: e.value.value,
        rank: e.key + 1,
      );
    }).toList();
  }

  List<RankedItem> _rankGenres(
    Map<String, Duration> timeMap,
    Map<String, int> countMap,
  ) {
    final entries = timeMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList().asMap().entries.map((e) {
      final genre = e.value.key;
      return RankedItem(
        id: genre,
        name: genre,
        playCount: countMap[genre] ?? 0,
        listenTime: e.value.value,
        rank: e.key + 1,
      );
    }).toList();
  }

  ArtistStreak? _computeLongestStreak(
    Map<String, Set<String>> artistByDay,
    DateTime start,
    DateTime end,
    Map<String, String?> artMap,
  ) {
    // For every artist, count maximum consecutive days played.
    final artistStreaks = <String, int>{};
    final artistStreakStart = <String, DateTime>{};
    final artistStreakEnd = <String, DateTime>{};

    final allArtists = artistByDay.values.expand((s) => s).toSet();

    for (final artist in allArtists) {
      int current = 0;
      int best = 0;
      DateTime? bestStart;
      DateTime? bestEnd;
      DateTime? runStart;

      // Walk every day in the period
      DateTime day = DateTime(start.year, start.month, start.day);
      while (!day.isAfter(end)) {
        final key = _dayKey(day);
        if (artistByDay[key]?.contains(artist) == true) {
          if (current == 0) runStart = day;
          current++;
          if (current > best) {
            best = current;
            bestStart = runStart;
            bestEnd = day;
          }
        } else {
          current = 0;
          runStart = null;
        }
        day = day.add(const Duration(days: 1));
      }

      if (best > 1) {
        artistStreaks[artist] = best;
        artistStreakStart[artist] = bestStart!;
        artistStreakEnd[artist] = bestEnd!;
      }
    }

    if (artistStreaks.isEmpty) return null;

    final best = artistStreaks.entries.reduce(
        (a, b) => a.value >= b.value ? a : b);
    return ArtistStreak(
      artistName: best.key,
      artPath: artMap[best.key],
      days: best.value,
      startDate: artistStreakStart[best.key]!,
      endDate: artistStreakEnd[best.key]!,
    );
  }

  List<UnlikelyCombo> _findUnlikelyCombos(List<RankedItem> topGenres) {
    if (topGenres.length < 2) return [];
    // Pair genres that are "unlikely" based on simple heuristics
    const opposites = {
      'classical': ['metal', 'hip-hop', 'punk', 'rap', 'edm'],
      'metal': ['classical', 'jazz', 'folk', 'country'],
      'jazz': ['metal', 'punk', 'dubstep', 'trap'],
      'country': ['metal', 'punk', 'dubstep'],
      'punk': ['classical', 'jazz', 'ambient'],
      'ambient': ['metal', 'punk', 'rap'],
    };
    final genres = topGenres.map((g) => g.name.toLowerCase()).toList();
    for (final g in genres) {
      final oppositeList = opposites[g];
      if (oppositeList == null) continue;
      for (final other in genres) {
        if (other != g && oppositeList.contains(other)) {
          return [
            UnlikelyCombo(
              genreA: g[0].toUpperCase() + g.substring(1),
              genreB: other[0].toUpperCase() + other.substring(1),
            )
          ];
        }
      }
    }
    return [];
  }

  List<RankedItem> _findThrowbacks(List<ListeningEvent> events, DateTime periodStart) {
    // Songs that hadn't been played in the 60 days before this period.
    // We use the service's full history to find the previous play date.
    final cutoff = periodStart.subtract(const Duration(days: 60));
    final recentSongs = <String, bool>{};

    final allHistory = ListeningHistoryService().getAllEvents();
    for (final e in allHistory) {
      if (e.timestamp.isBefore(periodStart) && e.timestamp.isAfter(cutoff)) {
        recentSongs[e.songId] = true;
      }
    }

    // Throwbacks: songs in the period that have NO record in the 60-day window.
    final throwbackEvents = <String, ListeningEvent>{};
    for (final e in events) {
      if (!recentSongs.containsKey(e.songId)) {
        throwbackEvents.putIfAbsent(e.songId, () => e);
      }
    }

    return throwbackEvents.values.take(5).toList().asMap().entries.map((e) {
      final ev = e.value;
      return RankedItem(
        id: ev.songId,
        name: ev.songTitle,
        subtitle: ev.artist,
        artPath: ev.artPath,
        playCount: 1,
        listenTime: ev.listenedDuration,
        rank: e.key + 1,
      );
    }).toList();
  }

  List<DailyListeningStats> _buildDailyStats(
      List<ListeningEvent> events, DateTime start, DateTime end) {
    final dayMap = <String, Duration>{};
    final dayCountMap = <String, int>{};

    for (final e in events) {
      Duration duration = e.listenedDuration;
      if (e.songDuration > Duration.zero && duration > e.songDuration) {
        duration = e.songDuration;
      } else if (duration > const Duration(minutes: 30)) {
        duration = const Duration(minutes: 30);
      }
      final k = _dayKey(e.timestamp);
      dayMap[k] = (dayMap[k] ?? Duration.zero) + duration;
      dayCountMap[k] = (dayCountMap[k] ?? 0) + 1;
    }

    final days = <DailyListeningStats>[];
    DateTime day = DateTime(start.year, start.month, start.day);
    while (!day.isAfter(end)) {
      final k = _dayKey(day);
      days.add(DailyListeningStats(
        date: day,
        totalTime: dayMap[k] ?? Duration.zero,
        trackCount: dayCountMap[k] ?? 0,
      ));
      day = day.add(const Duration(days: 1));
    }
    return days;
  }
}
