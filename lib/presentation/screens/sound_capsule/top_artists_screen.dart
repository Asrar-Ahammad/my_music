import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../domain/models/sound_capsule_stats.dart';
import '../../widgets/retro_circle_avatar.dart';
import '../../widgets/retro_icon.dart';

/// Screen displayed when tapping the "Top artist" card in Sound Capsule.
/// Matches the requested design with ranked artist list, clean rank numbers,
/// and artist profile photos taken from their top song's album art.
class TopArtistsScreen extends ConsumerWidget {
  final SoundCapsuleStats stats;

  const TopArtistsScreen({
    super.key,
    required this.stats,
  });

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
    final artists = stats.topArtists;

    final monthStr = '${_monthName(stats.periodStart.month)} ${stats.periodStart.year}';
    final artistCount = stats.uniqueArtists > 0 ? stats.uniqueArtists : artists.length;

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
          'Top artists',
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

            // Headline: "You listened to 60 artists this month."
            RichText(
              text: TextSpan(
                style: RetroTypography.pixelHeader(
                  color: theme.colorScheme.onSurface,
                  fontSize: 15,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'You listened to '),
                  TextSpan(
                    text: '$artistCount artists',
                    style: RetroTypography.pixelHeader(
                      color: theme.colorScheme.primary,
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

            // Artist Ranked List
            if (artists.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No artist data recorded for this period.',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
              )
            else
              ...artists.asMap().entries.map((entry) {
                final index = entry.key;
                final artist = entry.value;
                final rank = index + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: _buildArtistRow(context, rank, artist, theme, retro),
                );
              }),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistRow(
    BuildContext context,
    int rank,
    RankedItem artist,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final photoUrl = artist.artPath;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Rank Number
        SizedBox(
          width: 32,
          child: Text(
            '$rank',
            textAlign: TextAlign.center,
            style: RetroTypography.pixelHeader(
              color: theme.colorScheme.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Circular Artist Photo with Custom Retro Circle Border
        RetroCircleAvatar(
          artPath: photoUrl,
          fallbackText: artist.name,
          size: 62,
          accentColor: theme.colorScheme.primary,
          borderColor: retro.borderColor,
        ),

        const SizedBox(width: 16),

        // Artist Name & Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                artist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RetroTypography.pixelHeader(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (rank >= 2 && rank <= 5) ...[
                const SizedBox(height: 5),
                Text(
                  '1 month in top 5',
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 8.5,
                  ),
                ),
              ] else if (artist.playCount > 0) ...[
                const SizedBox(height: 5),
                Text(
                  '${artist.playCount} plays',
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 8.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
