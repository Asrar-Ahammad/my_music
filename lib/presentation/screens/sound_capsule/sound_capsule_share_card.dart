import 'package:flutter/material.dart';
import '../../../core/theme/retro_colors.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../data/services/share_capture_service.dart';
import '../../../domain/models/sound_capsule_stats.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_icon.dart';

/// The visual share card for the Sound Capsule feature.
/// Adapts strictly to the selected aspect ratio and uses the app's authentic RetroPaletteData.
class SoundCapsuleShareCard extends StatelessWidget {
  final SoundCapsuleStats stats;
  final RetroPaletteData palette;
  final ShareAspectRatio aspectRatio;

  const SoundCapsuleShareCard({
    super.key,
    required this.stats,
    required this.palette,
    this.aspectRatio = ShareAspectRatio.story,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: aspectRatio.canonicalWidth,
      height: aspectRatio.canonicalHeight,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: palette.bg,
        border: Border.all(
          color: palette.border,
          width: 3.5,
        ),
      ),
      child: Stack(
        children: [
          // Background subtle scanline effect or tint
          Positioned.fill(
            child: Container(
              color: palette.isDark
                  ? Colors.black.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: _getPadding(),
            child: _buildLayout(),
          ),
        ],
      ),
    );
  }

  EdgeInsets _getPadding() {
    switch (aspectRatio) {
      case ShareAspectRatio.story:
        return const EdgeInsets.all(24);
      case ShareAspectRatio.square:
        return const EdgeInsets.all(22);
      case ShareAspectRatio.wide:
        return const EdgeInsets.symmetric(horizontal: 24, vertical: 18);
    }
  }

  Widget _buildLayout() {
    switch (aspectRatio) {
      case ShareAspectRatio.story:
        return _buildStoryLayout();
      case ShareAspectRatio.square:
        return _buildSquareLayout();
      case ShareAspectRatio.wide:
        return _buildWideLayout();
    }
  }

  // ── 1. Story Layout (9:16 Vertical) ───────────────────────────────────────

  Widget _buildStoryLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Branding & Period
        _buildHeaderRow(isCompact: false),
        const SizedBox(height: 8),

        // Banner
        _buildBanner(),
        const Spacer(flex: 1),

        // Big Listening Time
        _buildHeroTime(fontSize: 44),
        const SizedBox(height: 8),

        // 3 Metric Tiles
        _buildMetricsRow(),
        const Spacer(flex: 2),

        // Featured Top Track (Cover Art of First Top Song)
        if (stats.topSongs.isNotEmpty) ...[
          _buildTopTrackTile(),
          const Spacer(flex: 2),
        ],

        // Top Artists
        _buildTopArtistsSection(maxItems: 4),
        const Spacer(flex: 2),

        // Additional Top Tracks if any
        if (stats.topSongs.length > 1) ...[
          _buildTopSongsSection(maxItems: 2, skipFirst: true),
          const Spacer(flex: 2),
        ],

        // Highlight & Insights
        _buildStoryInsights(),
        const Spacer(flex: 1),

        // Bottom Barcode & Footer
        _buildFooter(),
      ],
    );
  }

  // ── 2. Square Layout (1:1 Balanced) ───────────────────────────────────────

  Widget _buildSquareLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        _buildHeaderRow(isCompact: true),
        const SizedBox(height: 10),

        // Hero Row: Left (Time & Stats) + Right (Top Track & Highlight)
        Expanded(
          flex: 5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left: Hero Time + Stats
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.card,
                    border: Border.all(color: palette.border, width: 2.0),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        stats.formattedTotalTime,
                        style: RetroTypography.pixelHeader(
                          color: palette.primary,
                          fontSize: 32,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'TOTAL TIME LISTENED',
                        style: RetroTypography.pixelBadge(
                          color: palette.textSecondary,
                          fontSize: 8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatItem('${stats.totalTracksPlayed}', 'TRACKS'),
                          _buildStatItem('${stats.uniqueArtists}', 'ARTISTS'),
                          _buildStatItem('${stats.daysActive}', 'DAYS'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Right: Top Track & Highlight
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: stats.topSongs.isNotEmpty
                          ? _buildTopTrackTile(isFilled: true)
                          : Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: palette.card,
                                border: Border.all(color: palette.border, width: 2.0),
                              ),
                              child: Text(
                                'NO TRACKS YET',
                                style: RetroTypography.pixelBadge(
                                  color: palette.textSecondary,
                                  fontSize: 9,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    _buildHighlightBadge(),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Bottom Section: Two Columns (Top Artists on Left, Top Tracks on Right)
        Expanded(
          flex: 4,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildTopArtistsSection(maxItems: 3, isCompact: true),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: stats.topSongs.length > 1
                    ? _buildTopSongsSection(maxItems: 3, skipFirst: true, isCompact: true)
                    : _buildStoryInsights(isVertical: true),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Footer
        _buildFooter(),
      ],
    );
  }

  // ── 3. Wide Layout (1.9:1 Horizontal Split) ───────────────────────────────

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column (Branding, Time, Stats, Highlight)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeaderRow(isCompact: true),
              const SizedBox(height: 8),
              _buildBanner(),
              const Spacer(),
              _buildHeroTime(fontSize: 34),
              const SizedBox(height: 8),
              _buildMetricsRow(),
              const Spacer(),
              _buildStoryInsights(),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Vertical divider
        Container(
          width: 2,
          color: palette.border.withValues(alpha: 0.5),
        ),

        const SizedBox(width: 16),

        // Right Column (Top Track, Top Artists, Footer)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stats.topSongs.isNotEmpty) ...[
                _buildTopTrackTile(),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: _buildTopArtistsSection(maxItems: 3),
              ),
              const SizedBox(height: 8),
              _buildFooter(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sub-components ────────────────────────────────────────────────────────

  Widget _buildHeaderRow({required bool isCompact}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            RetroIcon('sound_capsule', size: isCompact ? 16 : 18, color: palette.primary),
            const SizedBox(width: 8),
            Text(
              'myMusic',
              style: RetroTypography.pixelHeader(
                color: palette.primary,
                fontSize: isCompact ? 12 : 13,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: palette.card,
            border: Border.all(color: palette.border, width: 1.5),
          ),
          child: Text(
            stats.periodLabel.toUpperCase(),
            style: RetroTypography.pixelBadge(
              color: palette.textPrimary,
              fontSize: 8.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.15),
        border: Border.all(color: palette.primary.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Text('✦ ', style: TextStyle(color: palette.yellow, fontSize: 11)),
          Text(
            'SOUND CAPSULE',
            style: RetroTypography.pixelHeader(
              color: palette.textPrimary,
              fontSize: 10.5,
            ),
          ),
          const Spacer(),
          Text(
            palette.name,
            style: RetroTypography.pixelBadge(
              color: palette.textSecondary,
              fontSize: 7.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroTime({required double fontSize}) {
    return Center(
      child: Column(
        children: [
          Text(
            stats.formattedTotalTime,
            style: RetroTypography.pixelHeader(
              color: palette.primary,
              fontSize: fontSize,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'TOTAL TIME LISTENED',
            style: RetroTypography.pixelBadge(
              color: palette.textSecondary,
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        _buildMetricBox('${stats.totalTracksPlayed}', 'TRACKS'),
        const SizedBox(width: 8),
        _buildMetricBox('${stats.uniqueArtists}', 'ARTISTS'),
        const SizedBox(width: 8),
        _buildMetricBox('${stats.daysActive}', 'ACTIVE DAYS'),
      ],
    );
  }

  Widget _buildMetricBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: palette.card,
          border: Border.all(color: palette.border, width: 1.5),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: RetroTypography.pixelHeader(
                color: palette.textPrimary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: RetroTypography.pixelBadge(
                color: palette.textSecondary,
                fontSize: 7.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: RetroTypography.pixelHeader(
              color: palette.textPrimary,
              fontSize: 12,
            ),
          ),
          Text(
            label,
            style: RetroTypography.pixelBadge(
              color: palette.textSecondary,
              fontSize: 7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopArtistsSection({required int maxItems, bool isCompact = false}) {
    final list = stats.topArtists.take(maxItems).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            RetroIcon('user', size: 11, color: palette.primary),
            const SizedBox(width: 5),
            Text(
              'TOP ARTISTS',
              style: RetroTypography.pixelHeader(
                color: palette.primary,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        if (list.isEmpty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.card,
              border: Border.all(color: palette.border, width: 1.5),
            ),
            child: Text(
              'NO ARTISTS YET',
              style: RetroTypography.pixelBadge(
                color: palette.textSecondary,
                fontSize: 8.5,
              ),
            ),
          )
        else
          for (int i = 0; i < list.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            _buildArtistRow(list[i], i, isCompact),
          ],
      ],
    );
  }

  Widget _buildArtistRow(RankedItem artist, int index, bool isCompact) {
    final isFirst = index == 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(
          color: isFirst ? palette.primary : palette.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            '#${index + 1}',
            style: RetroTypography.pixelHeader(
              color: isFirst ? palette.primary : palette.textSecondary,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              artist.name,
              style: RetroTypography.pixelBadge(
                color: palette.textPrimary,
                fontSize: 9,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${artist.playCount}x',
            style: RetroTypography.pixelBadge(
              color: palette.textSecondary,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSongsSection({
    required int maxItems,
    bool skipFirst = false,
    bool isCompact = false,
  }) {
    final source = skipFirst ? stats.topSongs.skip(1) : stats.topSongs;
    final list = source.take(maxItems).toList();
    if (list.isEmpty) return const SizedBox.shrink();

    final startIndex = skipFirst ? 1 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            RetroIcon('disc', size: 11, color: palette.primary),
            const SizedBox(width: 5),
            Text(
              'TOP TRACKS',
              style: RetroTypography.pixelHeader(
                color: palette.primary,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        for (int i = 0; i < list.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          _buildSongRow(list[i], startIndex + i, isCompact),
        ],
      ],
    );
  }

  Widget _buildSongRow(RankedItem song, int index, bool isCompact) {
    final isFirst = index == 0;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 6 : 8,
        vertical: isCompact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(
          color: isFirst ? palette.primary : palette.border,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            '#${index + 1}',
            style: RetroTypography.pixelHeader(
              color: isFirst ? palette.primary : palette.textSecondary,
              fontSize: 9.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  song.name,
                  style: RetroTypography.pixelBadge(
                    color: palette.textPrimary,
                    fontSize: 9,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.subtitle != null && song.subtitle!.isNotEmpty)
                  Text(
                    song.subtitle!,
                    style: RetroTypography.pixelBadge(
                      color: palette.textSecondary,
                      fontSize: 7.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (song.playCount > 0) ...[
            const SizedBox(width: 6),
            Text(
              '${song.playCount}x',
              style: RetroTypography.pixelBadge(
                color: palette.textSecondary,
                fontSize: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopTrackTile({bool isFilled = false}) {
    final song = stats.topSongs.first;
    if (isFilled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.card,
          border: Border.all(color: palette.border, width: 2.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                RetroIcon('disc', size: 14, color: palette.primary),
                const SizedBox(width: 6),
                Text(
                  'TOP TRACK',
                  style: RetroTypography.pixelBadge(
                    color: palette.primary,
                    fontSize: 8,
                  ),
                ),
                const Spacer(),
                if (song.playCount > 0)
                  Text(
                    '${song.playCount}x',
                    style: RetroTypography.pixelBadge(
                      color: palette.textSecondary,
                      fontSize: 8,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                RetroAlbumArt(
                  artPath: song.artPath,
                  title: song.name,
                  artist: song.subtitle,
                  width: 58,
                  height: 58,
                  borderRadius: BorderRadius.zero,
                  borderWidth: 1.5,
                  borderColor: palette.primary,
                  backgroundColor: palette.bg,
                  placeholderIconSize: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.name,
                        style: RetroTypography.pixelHeader(
                          color: palette.textPrimary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (song.subtitle != null && song.subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          song.subtitle!,
                          style: RetroTypography.pixelBadge(
                            color: palette.textSecondary,
                            fontSize: 8.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.card,
        border: Border.all(color: palette.border, width: 1.5),
      ),
      child: Row(
        children: [
          RetroAlbumArt(
            artPath: song.artPath,
            title: song.name,
            artist: song.subtitle,
            width: 44,
            height: 44,
            borderRadius: BorderRadius.zero,
            borderWidth: 1.5,
            borderColor: palette.primary,
            backgroundColor: palette.bg,
            placeholderIconSize: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'TOP TRACK',
                      style: RetroTypography.pixelBadge(
                        color: palette.primary,
                        fontSize: 7.5,
                      ),
                    ),
                    const Spacer(),
                    if (song.playCount > 0)
                      Text(
                        '${song.playCount}x',
                        style: RetroTypography.pixelBadge(
                          color: palette.textSecondary,
                          fontSize: 8,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  song.name,
                  style: RetroTypography.pixelHeader(
                    color: palette.textPrimary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (song.subtitle != null && song.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    song.subtitle!,
                    style: RetroTypography.pixelBadge(
                      color: palette.textSecondary,
                      fontSize: 7.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryInsights({bool isVertical = false}) {
    String highlightText;
    String highlightIcon;

    if (stats.longestStreak != null && stats.longestStreak!.days >= 2) {
      final s = stats.longestStreak!;
      highlightText = '${s.days}-DAY STREAK: ${s.artistName.toUpperCase()}';
      highlightIcon = 'sparkles';
    } else if (stats.mostActiveDay != null) {
      highlightText = 'MOST ACTIVE: ${stats.mostActiveDay!.label.toUpperCase()}S';
      highlightIcon = 'clock';
    } else {
      final hour = stats.peakHour;
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final amPm = hour < 12 ? 'AM' : 'PM';
      final persona = hour >= 22 || hour < 5 ? 'NIGHT OWL' : 'DAY TRIPPER';
      highlightText = 'PEAK: $displayHour $amPm ($persona)';
      highlightIcon = 'clock';
    }

    final topGenre = stats.topGenres.isNotEmpty ? stats.topGenres.first.name : null;

    final box1 = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.12),
        border: Border.all(color: palette.primary.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RetroIcon(highlightIcon, size: 12, color: palette.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              highlightText,
              style: RetroTypography.pixelBadge(
                color: palette.primary,
                fontSize: 8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    final box2 = topGenre != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: palette.card,
              border: Border.all(color: palette.border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RetroIcon('disc', size: 12, color: palette.yellow),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOP GENRE',
                        style: RetroTypography.pixelBadge(
                          color: palette.textSecondary,
                          fontSize: 6.5,
                        ),
                      ),
                      Text(
                        topGenre.toUpperCase(),
                        style: RetroTypography.pixelBadge(
                          color: palette.textPrimary,
                          fontSize: 7.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: palette.card,
              border: Border.all(color: palette.border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                RetroIcon('music', size: 12, color: palette.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${stats.uniqueAlbums} ALBUMS PLAYED',
                    style: RetroTypography.pixelBadge(
                      color: palette.textSecondary,
                      fontSize: 8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );

    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          box1,
          const SizedBox(height: 6),
          box2,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: box1),
        const SizedBox(width: 8),
        Expanded(child: box2),
      ],
    );
  }

  Widget _buildHighlightBadge() {
    String text;
    String iconName;

    if (stats.longestStreak != null && stats.longestStreak!.days >= 2) {
      final s = stats.longestStreak!;
      text = '${s.days}-DAY STREAK: ${s.artistName.toUpperCase()}';
      iconName = 'sparkles';
    } else if (stats.mostActiveDay != null) {
      text = 'MOST ACTIVE ON ${stats.mostActiveDay!.label.toUpperCase()}S';
      iconName = 'clock';
    } else {
      final hour = stats.peakHour;
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      final amPm = hour < 12 ? 'AM' : 'PM';
      final persona = hour >= 22 || hour < 5 ? 'NIGHT OWL' : 'DAY TRIPPER';
      text = 'PEAK HOUR: $displayHour $amPm ($persona)';
      iconName = 'clock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.12),
        border: Border.all(color: palette.primary.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RetroIcon(iconName, size: 12, color: palette.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: RetroTypography.pixelBadge(
                color: palette.primary,
                fontSize: 8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Row(
          children: List.generate(
            12,
            (index) => Container(
              width: (index % 3 == 0) ? 3 : (index % 2 == 0 ? 2 : 1),
              height: 10,
              margin: const EdgeInsets.only(right: 2.5),
              color: palette.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ),
        const Spacer(),
        Text(
          'RETRO AUDIO ARCHIVE',
          style: RetroTypography.pixelBadge(
            color: palette.textSecondary.withValues(alpha: 0.4),
            fontSize: 7.5,
          ),
        ),
      ],
    );
  }
}
