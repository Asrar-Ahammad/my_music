import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../data/services/artist_photo_service.dart';
import '../../../domain/models/audio_quality.dart';
import '../../../domain/models/song.dart';
import '../../../domain/models/sound_capsule_stats.dart';
import '../../providers/library_provider.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_song_tile.dart';

/// Screen displayed when tapping the "Top song" card in Sound Capsule.
/// Shows ranked top songs with the app's default song card (RetroSongTile),
/// play counts, and BPM analysis.
class TopSongsScreen extends ConsumerWidget {
  final SoundCapsuleStats stats;

  const TopSongsScreen({
    super.key,
    required this.stats,
  });

  static const _yellowAccent = Color(0xFFF59E0B);

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final songs = stats.topSongs;
    final librarySongs = ref.watch(libraryProvider).allSongs;
    final songMap = {for (final s in librarySongs) s.id: s};

    // Queue of Song objects for playback
    final List<Song> queue = songs.map((rankedItem) {
      return songMap[rankedItem.id] ??
          Song(
            id: rankedItem.id,
            title: rankedItem.name,
            artist: rankedItem.subtitle ?? 'Unknown',
            album: 'Unknown',
            duration: rankedItem.listenTime,
            uri: '',
            artPath: rankedItem.artPath,
            quality: const AudioQuality(format: 'MP3'),
          );
    }).toList();

    final monthStr = '${_monthName(stats.periodStart.month)} ${stats.periodStart.year}';
    final songCount = stats.uniqueTracksPlayed > 0 ? stats.uniqueTracksPlayed : songs.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: RetroIcon('arrow_left', size: 20, color: theme.colorScheme.onSurface),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Top songs',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Period label (e.g. October 2026)
            Text(
              monthStr,
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),

            // Headline: "You played 39 different songs this month."
            RichText(
              text: TextSpan(
                style: RetroTypography.pixelHeader(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'You played '),
                  TextSpan(
                    text: '$songCount different songs',
                    style: RetroTypography.pixelHeader(
                      color: _yellowAccent,
                      fontSize: 15,
                    ),
                  ),
                  TextSpan(
                    text: stats.period == CapsulePeriod.weekly ? ' this week.' : ' this month.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Ranked Songs List using default RetroSongTile without 3-dot menu
            if (songs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No song data recorded for this period.',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border.all(
                    color: retro.borderColor,
                    width: retro.borderWidth,
                  ),
                  borderRadius: BorderRadius.circular(retro.borderRadius),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < songs.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: retro.borderColor.withValues(alpha: 0.25),
                        ),
                      RetroSongTile(
                        key: ValueKey(queue[i].id),
                        song: queue[i],
                        index: i,
                        queue: queue,
                        subtitle: '${ArtistPhotoService.extractPrimaryArtist(queue[i].artist)} • ${songs[i].playCount} plays',
                        showMenu: false, // Remove three-dot menu next to song name
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // BPM Analysis Section
            _buildBpmSection(context, theme, retro),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildBpmSection(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    // Simulated or computed BPM statistics based on songs
    final topSong = stats.topSongs.firstOrNull?.name ?? 'Top Track';
    final topArtist = ArtistPhotoService.extractPrimaryArtist(stats.topSongs.firstOrNull?.subtitle ?? 'Artist');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border.all(
          color: retro.borderColor,
          width: retro.borderWidth,
        ),
        borderRadius: BorderRadius.circular(retro.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.bold,
              ),
              children: [
                const TextSpan(text: 'The average BPM of your songs was '),
                TextSpan(
                  text: '125',
                  style: RetroTypography.pixelHeader(
                    color: _yellowAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // BPM Histogram visualizer
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (index) {
                final heights = [
                  0.15, 0.2, 0.35, 0.5, 0.4, 0.65, 0.85, 0.7, 0.95, 1.0, 0.8, 0.9,
                  0.75, 0.6, 0.5, 0.45, 0.35, 0.3, 0.25, 0.2, 0.15, 0.1, 0.08, 0.05
                ];
                final h = heights[index % heights.length];
                final isPeak = h >= 0.9;
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    height: 80 * h,
                    decoration: BoxDecoration(
                      color: isPeak ? _yellowAccent : _yellowAccent.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '79 BPM',
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
              Text(
                '208 BPM',
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: retro.borderColor.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 16),

          // Lowest and Highest BPM tiles
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lowest BPM',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topSong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '79 BPM • $topArtist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Highest BPM',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stats.topSongs.length > 1 ? stats.topSongs[1].name : topSong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '174 BPM • $topArtist',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
