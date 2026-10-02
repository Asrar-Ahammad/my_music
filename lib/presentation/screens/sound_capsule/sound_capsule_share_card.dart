import 'package:flutter/material.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../data/services/share_capture_service.dart';
import '../../../domain/models/sound_capsule_stats.dart';
import '../../widgets/retro_icon.dart';

/// The visual share card for the Sound Capsule feature.
/// Can be rendered inside a preview sheet or off-screen for RepaintBoundary capture.
class SoundCapsuleShareCard extends StatelessWidget {
  final SoundCapsuleStats stats;
  final ShareCardTheme cardTheme;
  final ShareAspectRatio aspectRatio;

  const SoundCapsuleShareCard({
    super.key,
    required this.stats,
    this.cardTheme = ShareCardTheme.neon,
    this.aspectRatio = ShareAspectRatio.story,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio.aspectValue,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cardTheme.colors,
          ),
          border: Border.all(
            color: const Color(0xFF00FFCC).withValues(alpha: 0.7),
            width: 3.0,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: Branding & Period
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const RetroIcon('sound_capsule', size: 18, color: Color(0xFF00FFCC)),
                    const SizedBox(width: 8),
                    Text(
                      'myMusic',
                      style: RetroTypography.pixelHeader(
                        color: const Color(0xFF00FFCC),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Text(
                    stats.periodLabel.toUpperCase(),
                    style: RetroTypography.pixelBadge(
                      color: Colors.white,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Sound Capsule Title Banner
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              color: const Color(0xFF00FFCC).withValues(alpha: 0.15),
              child: Row(
                children: [
                  const Text('✦ ', style: TextStyle(color: Color(0xFFFFB800), fontSize: 12)),
                  Text(
                    'SOUND CAPSULE',
                    style: RetroTypography.pixelHeader(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'VER. 1.0',
                    style: RetroTypography.pixelBadge(
                      color: Colors.white38,
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Hero Stat: Total Listen Time
            Center(
              child: Column(
                children: [
                  Text(
                    stats.formattedTotalTime,
                    style: RetroTypography.pixelHeader(
                      color: const Color(0xFFFFB800),
                      fontSize: 32,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TOTAL TIME LISTENED',
                    style: RetroTypography.pixelBadge(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 3-Stat Summary Grid
            Row(
              children: [
                _buildStatTile('${stats.totalTracksPlayed}', 'TRACKS'),
                const SizedBox(width: 8),
                _buildStatTile('${stats.uniqueArtists}', 'ARTISTS'),
                const SizedBox(width: 8),
                _buildStatTile('${stats.daysActive}', 'ACTIVE DAYS'),
              ],
            ),

            const SizedBox(height: 16),

            // Top Artists Section
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOP ARTISTS',
                    style: RetroTypography.pixelHeader(
                      color: const Color(0xFF00FFCC),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: stats.topArtists.isEmpty
                        ? Center(
                            child: Text(
                              'NO ARTISTS YET',
                              style: RetroTypography.pixelBadge(
                                color: Colors.white38,
                                fontSize: 9,
                              ),
                            ),
                          )
                        : ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: stats.topArtists.take(5).length,
                            separatorBuilder: (context, index) => const SizedBox(height: 6),
                            itemBuilder: (context, i) {
                              final artist = stats.topArtists[i];
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  border: Border.all(
                                    color: i == 0 ? const Color(0xFFFFB800) : Colors.white12,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      '#${i + 1}',
                                      style: RetroTypography.pixelHeader(
                                        color: i == 0 ? const Color(0xFFFFB800) : Colors.white54,
                                        fontSize: 10,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        artist.name,
                                        style: RetroTypography.pixelBadge(
                                          color: Colors.white,
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${artist.playCount} plays',
                                      style: RetroTypography.pixelBadge(
                                        color: Colors.white54,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Top Song (if available)
            if (stats.topSongs.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  border: Border.all(color: Colors.white12, width: 1.5),
                ),
                child: Row(
                  children: [
                    const RetroIcon('disc', size: 14, color: Color(0xFFFF3366)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOP TRACK',
                            style: RetroTypography.pixelBadge(
                              color: const Color(0xFFFF3366),
                              fontSize: 7.5,
                            ),
                          ),
                          Text(
                            stats.topSongs.first.name,
                            style: RetroTypography.pixelBadge(
                              color: Colors.white,
                              fontSize: 9.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      stats.topSongs.first.subtitle ?? '',
                      style: RetroTypography.pixelBadge(
                        color: Colors.white38,
                        fontSize: 8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Fun Vibe / Insight Snippet
            _buildHighlightBadge(),

            const SizedBox(height: 14),

            // Bottom decorative barcode & watermark
            Row(
              children: [
                // Simulated retro barcode / waveform
                Row(
                  children: List.generate(
                    16,
                    (index) => Container(
                      width: (index % 3 == 0) ? 3 : (index % 2 == 0 ? 2 : 1),
                      height: 14,
                      margin: const EdgeInsets.only(right: 2.5),
                      color: Colors.white24,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  'RETRO AUDIO ARCHIVE',
                  style: RetroTypography.pixelBadge(
                    color: Colors.white24,
                    fontSize: 7.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: Colors.white12, width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: RetroTypography.pixelHeader(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: RetroTypography.pixelBadge(
                color: Colors.white54,
                fontSize: 7.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightBadge() {
    String highlightText;
    Color accentColor;
    String iconName;

    if (stats.longestStreak != null && stats.longestStreak!.days >= 2) {
      final streak = stats.longestStreak!;
      highlightText = '${streak.days}-DAY STREAK: ${streak.artistName.toUpperCase()}';
      accentColor = const Color(0xFFFFB800);
      iconName = 'sparkles';
    } else if (stats.mostActiveDay != null) {
      highlightText = 'MOST ACTIVE ON ${stats.mostActiveDay!.label.toUpperCase()}S';
      accentColor = const Color(0xFF00FFCC);
      iconName = 'clock';
    } else {
      final hour = stats.peakHour;
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final amPm = hour < 12 ? 'AM' : 'PM';
      final persona = hour >= 22 || hour < 5 ? 'NIGHT OWL' : 'DAY TRIPPER';
      highlightText = 'PEAK HOUR: $displayHour $amPm ($persona)';
      accentColor = const Color(0xFFFF3366);
      iconName = 'clock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RetroIcon(iconName, size: 12, color: accentColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              highlightText,
              style: RetroTypography.pixelBadge(
                color: accentColor,
                fontSize: 8.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
