import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../data/services/share_capture_service.dart';
import '../../../domain/models/sound_capsule_stats.dart';
import '../../providers/sound_capsule_provider.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_toast.dart';
import 'sound_capsule_share_card.dart';

/// The primary Sound Capsule screen displaying aggregated listening statistics,
/// retro chart visualizations, and shareable summaries.
class SoundCapsuleScreen extends ConsumerStatefulWidget {
  const SoundCapsuleScreen({super.key});

  @override
  ConsumerState<SoundCapsuleScreen> createState() => _SoundCapsuleScreenState();
}

class _SoundCapsuleScreenState extends ConsumerState<SoundCapsuleScreen> {
  final GlobalKey _shareCardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(soundCapsuleProvider);
    final notifier = ref.read(soundCapsuleProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'SOUND CAPSULE',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
        ),
        leading: IconButton(
          icon: RetroIcon('arrow_left', size: 18, color: theme.colorScheme.onSurface),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (state.stats != null && state.stats!.hasData)
            IconButton(
              icon: RetroIcon('sound_capsule', size: 20, color: theme.colorScheme.primary),
              tooltip: 'Share Capsule',
              onPressed: () => _openShareSheet(context, state.stats!),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Period Selector & Navigation Header
            _buildPeriodControls(state, notifier, theme, retro),

            // Main Content Area
            Expanded(
              child: _buildBody(state, notifier, theme, retro),
            ),
          ],
        ),
      ),
    );
  }

  // ── Period & Navigation Controls ──────────────────────────────────────────

  Widget _buildPeriodControls(
    SoundCapsuleState state,
    SoundCapsuleNotifier notifier,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border(
          bottom: BorderSide(color: retro.borderColor, width: retro.borderWidth),
        ),
      ),
      child: Column(
        children: [
          // Period Toggle (Monthly vs Weekly)
          Row(
            children: [
              Expanded(
                child: _buildPeriodTab(
                  label: 'MONTHLY',
                  isSelected: state.selectedPeriod == CapsulePeriod.monthly,
                  onTap: () => notifier.switchPeriod(CapsulePeriod.monthly),
                  theme: theme,
                  retro: retro,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPeriodTab(
                  label: 'WEEKLY',
                  isSelected: state.selectedPeriod == CapsulePeriod.weekly,
                  onTap: () => notifier.switchPeriod(CapsulePeriod.weekly),
                  theme: theme,
                  retro: retro,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Date Navigator Row (< OCT 2026 >)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: RetroIcon('chevron_left', size: 16, color: theme.colorScheme.onSurface),
                tooltip: 'Previous Period',
                onPressed: notifier.goToPreviousPeriod,
              ),
              Expanded(
                child: Text(
                  state.stats?.periodLabel.toUpperCase() ??
                      (state.selectedPeriod == CapsulePeriod.monthly
                          ? '${_monthName(state.selectedDate.month)} ${state.selectedDate.year}'
                          : 'THIS WEEK'),
                  textAlign: TextAlign.center,
                  style: RetroTypography.pixelHeader(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: RetroIcon(
                  'chevron_right',
                  size: 16,
                  color: notifier.canGoNext ? theme.colorScheme.onSurface : Colors.white24,
                ),
                tooltip: 'Next Period',
                onPressed: notifier.canGoNext ? notifier.goToNextPeriod : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ThemeData theme,
    required RetroThemeTokens retro,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : retro.borderColor,
            width: retro.borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: RetroTypography.pixelBadge(
            color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
            fontSize: 9.5,
          ),
        ),
      ),
    );
  }

  // ── Body Switcher ─────────────────────────────────────────────────────────

  Widget _buildBody(
    SoundCapsuleState state,
    SoundCapsuleNotifier notifier,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RetroIcon('sound_capsule', size: 36, color: Color(0xFF00FFCC)),
            const SizedBox(height: 16),
            Text(
              'COMPUTING SOUND CAPSULE...',
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RetroIcon('close', size: 32, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: RetroTypography.pixelBadge(
                  color: Colors.redAccent,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 16),
              RetroButton(
                label: 'RETRY',
                onPressed: notifier.loadStats,
              ),
            ],
          ),
        ),
      );
    }

    final stats = state.stats;
    if (stats == null || !stats.hasData) {
      return _buildEmptyState(theme, retro);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 1. Hero Listening Time Card
        _buildHeroCard(stats, theme, retro),

        const SizedBox(height: 16),

        // 2. Top Artists Card
        _buildTopArtistsCard(stats, theme, retro),

        const SizedBox(height: 16),

        // 3. Top Songs Card
        _buildTopSongsCard(stats, theme, retro),

        const SizedBox(height: 16),

        // 4. Daily Activity Bar Chart
        if (stats.dailyStats.isNotEmpty) ...[
          _buildActivityChartCard(stats, theme, retro),
          const SizedBox(height: 16),
        ],

        // 5. Vibe & Insights Card
        _buildInsightsCard(stats, theme, retro),

        const SizedBox(height: 24),

        // 6. Share Capsule Button
        RetroButton(
          label: 'SHARE SOUND CAPSULE',
          icon: const RetroIcon('sound_capsule', size: 16, color: Colors.black),
          backgroundColor: const Color(0xFF00FFCC),
          textColor: Colors.black,
          onPressed: () => _openShareSheet(context, stats),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── 1. Hero Card ──────────────────────────────────────────────────────────

  Widget _buildHeroCard(
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    return RetroCard(
      title: 'TOTAL LISTEN TIME',
      titleTrailing: const RetroIcon('clock', size: 12),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Center(
            child: Text(
              stats.formattedTotalTime,
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.primary,
                fontSize: 34,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricTile(
                value: '${stats.totalTracksPlayed}',
                label: 'TRACKS',
                icon: 'disc',
                theme: theme,
                retro: retro,
              ),
              const SizedBox(width: 8),
              _buildMetricTile(
                value: '${stats.uniqueArtists}',
                label: 'ARTISTS',
                icon: 'user',
                theme: theme,
                retro: retro,
              ),
              const SizedBox(width: 8),
              _buildMetricTile(
                value: '${stats.daysActive}',
                label: 'ACTIVE DAYS',
                icon: 'sparkles',
                theme: theme,
                retro: retro,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String value,
    required String label,
    required String icon,
    required ThemeData theme,
    required RetroThemeTokens retro,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: retro.cardColor,
          border: Border.all(color: retro.borderColor, width: retro.borderWidth),
        ),
        child: Column(
          children: [
            RetroIcon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              value,
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 2. Top Artists Card ───────────────────────────────────────────────────

  Widget _buildTopArtistsCard(
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final topArtists = stats.topArtists.take(5).toList();
    final maxListenSeconds = topArtists.isEmpty
        ? 1
        : max(1, topArtists.first.listenTime.inSeconds);

    return RetroCard(
      title: 'TOP ARTISTS',
      titleTrailing: Text(
        '${stats.uniqueArtists} TOTAL',
        style: RetroTypography.pixelBadge(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          fontSize: 8,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < topArtists.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _buildArtistRow(topArtists[i], i + 1, maxListenSeconds, theme, retro),
          ],
        ],
      ),
    );
  }

  Widget _buildArtistRow(
    RankedItem artist,
    int rank,
    int maxListenSeconds,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final progress = (artist.listenTime.inSeconds / maxListenSeconds).clamp(0.05, 1.0);
    final rankColor = rank == 1
        ? const Color(0xFFFFB800)
        : (rank == 2 ? const Color(0xFFC0C0C0) : (rank == 3 ? const Color(0xFFCD7F32) : theme.colorScheme.onSurface));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: rank == 1 ? rankColor.withValues(alpha: 0.2) : Colors.transparent,
                border: Border.all(color: rankColor, width: 1.5),
              ),
              child: Text(
                '#$rank',
                style: RetroTypography.pixelBadge(
                  color: rankColor,
                  fontSize: 8.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            RetroAlbumArt(
              artPath: artist.artPath,
              title: artist.name,
              artist: artist.name,
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    artist.name,
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${artist.playCount} plays • ${_formatDuration(artist.listenTime)}',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Progress visualizer
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: retro.borderColor.withValues(alpha: 0.3),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              color: rank == 1 ? const Color(0xFFFFB800) : theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ── 3. Top Songs Card ─────────────────────────────────────────────────────

  Widget _buildTopSongsCard(
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final topSongs = stats.topSongs.take(5).toList();

    return RetroCard(
      title: 'TOP SONGS',
      titleTrailing: const RetroIcon('music', size: 12),
      child: Column(
        children: [
          for (int i = 0; i < topSongs.length; i++) ...[
            if (i > 0)
              Divider(
                color: retro.borderColor.withValues(alpha: 0.4),
                height: 16,
                thickness: 1,
              ),
            _buildSongRow(topSongs[i], i + 1, theme, retro),
          ],
        ],
      ),
    );
  }

  Widget _buildSongRow(
    RankedItem song,
    int rank,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    return Row(
      children: [
        Text(
          '#$rank',
          style: RetroTypography.pixelBadge(
            color: rank == 1 ? const Color(0xFFFFB800) : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 9,
          ),
        ),
        const SizedBox(width: 10),
        RetroAlbumArt(
          artPath: song.artPath,
          title: song.name,
          artist: song.subtitle,
          width: 30,
          height: 30,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.name,
                style: RetroTypography.pixelBadge(
                  color: theme.colorScheme.onSurface,
                  fontSize: 9.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (song.subtitle != null)
                Text(
                  song.subtitle!,
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        Text(
          '${song.playCount}x',
          style: RetroTypography.pixelBadge(
            color: theme.colorScheme.primary,
            fontSize: 8.5,
          ),
        ),
      ],
    );
  }

  // ── 4. Daily Activity Bar Chart ───────────────────────────────────────────

  Widget _buildActivityChartCard(
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final dailyList = stats.dailyStats;
    double maxMinutes = 0;
    for (final d in dailyList) {
      final m = d.totalTime.inMinutes.toDouble();
      if (m > maxMinutes) maxMinutes = m;
    }
    if (maxMinutes == 0) maxMinutes = 60;

    return RetroCard(
      title: 'LISTENING ACTIVITY (MINUTES / DAY)',
      titleTrailing: const RetroIcon('equalizer', size: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxMinutes * 1.15,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: retro.borderColor.withValues(alpha: 0.2),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value >= maxMinutes) {
                          return Text(
                            '${value.toInt()}m',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              fontSize: 8,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 18,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= dailyList.length) return const SizedBox.shrink();
                        // For monthly view, show day every 5 days; for weekly view, show all
                        if (stats.period == CapsulePeriod.monthly && index % 5 != 0 && index != dailyList.length - 1) {
                          return const SizedBox.shrink();
                        }
                        final dayNum = dailyList[index].date.day;
                        return Text(
                          '$dayNum',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 8,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < dailyList.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: dailyList[i].totalTime.inMinutes.toDouble(),
                          color: dailyList[i].totalTime.inMinutes > 0
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                          width: stats.period == CapsulePeriod.monthly ? 4 : 14,
                          borderRadius: BorderRadius.zero,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Vibe & Insights Card ───────────────────────────────────────────────

  Widget _buildInsightsCard(
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final hour = stats.peakHour;
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    final amPm = hour < 12 ? 'AM' : 'PM';
    final persona = hour >= 22 || hour < 5
        ? 'Night Owl 🌙'
        : (hour < 12 ? 'Early Bird 🌅' : 'Day Groover ⚡');

    return RetroCard(
      title: 'VIBES & INSIGHTS',
      titleTrailing: const RetroIcon('sparkles', size: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildInsightTile(
            icon: 'clock',
            title: 'PEAK LISTENING HOUR',
            value: '$displayHour:00 $amPm — $persona',
            theme: theme,
            retro: retro,
          ),
          if (stats.mostActiveDay != null) ...[
            const SizedBox(height: 8),
            _buildInsightTile(
              icon: 'sparkles',
              title: 'FAVORITE DAY TO LISTEN',
              value: stats.mostActiveDay!.label,
              theme: theme,
              retro: retro,
            ),
          ],
          if (stats.longestStreak != null && stats.longestStreak!.days >= 2) ...[
            const SizedBox(height: 8),
            _buildInsightTile(
              icon: 'repeat',
              title: 'ARTIST STREAK',
              value: '${stats.longestStreak!.days} consecutive days of ${stats.longestStreak!.artistName}',
              theme: theme,
              retro: retro,
            ),
          ],
          if (stats.unlikelyCombos.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildInsightTile(
              icon: 'disc',
              title: 'ECLECTIC MIX',
              value: '${stats.unlikelyCombos.first.genreA} + ${stats.unlikelyCombos.first.genreB}',
              theme: theme,
              retro: retro,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsightTile({
    required String icon,
    required String title,
    required String value,
    required ThemeData theme,
    required RetroThemeTokens retro,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border.all(color: retro.borderColor, width: retro.borderWidth),
      ),
      child: Row(
        children: [
          RetroIcon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 7.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState(ThemeData theme, RetroThemeTokens retro) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const RetroIcon('sound_capsule', size: 48, color: Colors.white24),
            const SizedBox(height: 16),
            Text(
              'CAPSULE EMPTY',
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Play tracks for 30+ seconds to fill your capsule with listening stats.',
              textAlign: TextAlign.center,
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 9,
              ).copyWith(height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  // ── Share Bottom Sheet ────────────────────────────────────────────────────

  void _openShareSheet(BuildContext context, SoundCapsuleStats stats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShareModal(
        stats: stats,
        repaintKey: _shareCardKey,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  String _monthName(int month) {
    const names = [
      'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
      'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
    ];
    return names[month - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share Modal with Preview, Theme Selector, and Actions
// ─────────────────────────────────────────────────────────────────────────────

class _ShareModal extends StatefulWidget {
  final SoundCapsuleStats stats;
  final GlobalKey repaintKey;

  const _ShareModal({required this.stats, required this.repaintKey});

  @override
  State<_ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends State<_ShareModal> {
  ShareCardTheme _selectedTheme = ShareCardTheme.neon;
  ShareAspectRatio _selectedRatio = ShareAspectRatio.story;
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border(
          top: BorderSide(color: retro.borderColor, width: retro.borderWidth),
        ),
      ),
      child: Column(
        children: [
          // Drag handle & Title
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: retro.borderColor, width: retro.borderWidth),
              ),
            ),
            child: Row(
              children: [
                const RetroIcon('sound_capsule', size: 16, color: Color(0xFF00FFCC)),
                const SizedBox(width: 8),
                Text(
                  'EXPORT SOUND CAPSULE',
                  style: RetroTypography.pixelHeader(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: RetroIcon('close', size: 16, color: theme.colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Live Card Preview (wrapped in RepaintBoundary for capture)
                  Center(
                    child: SizedBox(
                      width: 260,
                      child: RepaintBoundary(
                        key: widget.repaintKey,
                        child: SoundCapsuleShareCard(
                          stats: widget.stats,
                          cardTheme: _selectedTheme,
                          aspectRatio: _selectedRatio,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Theme Palette Picker
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'SELECT PALETTE',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ShareCardTheme.values.map((t) {
                      final isSelected = t == _selectedTheme;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedTheme = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: t.colors),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF00FFCC) : Colors.white24,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Text(
                            t.label.toUpperCase(),
                            style: RetroTypography.pixelBadge(
                              color: Colors.white,
                              fontSize: 8.5,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Aspect Ratio Picker
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ASPECT RATIO',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ShareAspectRatio.values.map((r) {
                      final isSelected = r == _selectedRatio;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => _selectedRatio = r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                border: Border.all(
                                  color: isSelected ? theme.colorScheme.primary : retro.borderColor,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                r.label.toUpperCase(),
                                style: RetroTypography.pixelBadge(
                                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Action Buttons
                  if (_isCapturing) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      'GENERATING IMAGE...',
                      style: RetroTypography.pixelBadge(
                        color: theme.colorScheme.onSurface,
                        fontSize: 9,
                      ),
                    ),
                  ] else ...[
                    RetroButton(
                      label: 'SHARE IMAGE',
                      icon: const RetroIcon('sound_capsule', size: 14, color: Colors.black),
                      backgroundColor: const Color(0xFF00FFCC),
                      textColor: Colors.black,
                      onPressed: _handleShare,
                    ),
                    const SizedBox(height: 8),
                    RetroButton(
                      label: 'SAVE TO GALLERY',
                      icon: const RetroIcon('check', size: 14),
                      onPressed: _handleSaveToGallery,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleShare() async {
    setState(() => _isCapturing = true);
    try {
      await ShareCaptureService.shareCard(
        repaintKey: widget.repaintKey,
        cardName: widget.stats.periodLabel.replaceAll(' ', '_'),
        shareText: '🎧 My ${widget.stats.periodLabel} Sound Capsule on myMusic!',
      );
    } catch (e) {
      if (mounted) {
        RetroToast.show(context, 'Failed to share: $e', icon: 'close');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _handleSaveToGallery() async {
    setState(() => _isCapturing = true);
    try {
      await ShareCaptureService.saveToGallery(
        repaintKey: widget.repaintKey,
        cardName: widget.stats.periodLabel.replaceAll(' ', '_'),
      );
      if (mounted) {
        RetroToast.show(context, 'Saved to gallery!', icon: 'check');
      }
    } catch (e) {
      if (mounted) {
        RetroToast.show(context, 'Failed to save: $e', icon: 'close');
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }
}
