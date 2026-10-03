import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/retro_colors.dart';
import '../../../core/theme/retro_theme.dart';
import '../../../core/theme/retro_typography.dart';
import '../../../data/services/share_capture_service.dart';
import '../../../domain/models/sound_capsule_stats.dart';
import '../../providers/palette_provider.dart';
import '../../providers/sound_capsule_provider.dart';
import '../../widgets/retro_album_art.dart';
import '../../widgets/retro_button.dart';
import '../../widgets/retro_card.dart';
import '../../widgets/retro_circle_avatar.dart';
import '../../widgets/retro_icon.dart';
import '../../widgets/retro_toast.dart';
import 'sound_capsule_share_card.dart';
import 'top_artists_screen.dart';
import 'top_songs_screen.dart';

/// The primary Sound Capsule screen displaying aggregated listening statistics,
/// retro chart visualizations, and shareable summaries.
class SoundCapsuleScreen extends ConsumerStatefulWidget {
  const SoundCapsuleScreen({super.key});

  @override
  ConsumerState<SoundCapsuleScreen> createState() => _SoundCapsuleScreenState();
}

class _SoundCapsuleScreenState extends ConsumerState<SoundCapsuleScreen> {
  final GlobalKey _shareCardKey = GlobalKey();
  final Set<String> _expandedMonths = {};

  late final ScrollController _scrollController;
  bool _isScrolling = false;
  double _scrollProgress = 0.0;
  String _activeMonthLabel = '';
  Timer? _scrollFadeTimer;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollFadeTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final progress = (_scrollController.offset / maxScroll).clamp(0.0, 1.0);
    final capsules = ref.read(soundCapsuleProvider).monthlyCapsules;
    String label = '';
    if (capsules.isNotEmpty) {
      final index = (progress * (capsules.length - 1)).round().clamp(0, capsules.length - 1);
      final c = capsules[index];
      label = '${c.periodLabel}, ${c.periodStart.year}';
    }

    setState(() {
      _isScrolling = true;
      _scrollProgress = progress;
      if (label.isNotEmpty) _activeMonthLabel = label;
    });

    _scrollFadeTimer?.cancel();
    _scrollFadeTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _isScrolling = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(soundCapsuleProvider);
    final notifier = ref.read(soundCapsuleProvider.notifier);
    final theme = Theme.of(context);
    final retro = context.retro;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'YOUR SOUND CAPSULE',
          style: RetroTypography.pixelHeader(
            color: theme.colorScheme.onSurface,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
        leading: IconButton(
          icon: RetroIcon('arrow_left', size: 18, color: theme.colorScheme.onSurface),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: RetroIcon('info', size: 18, color: theme.colorScheme.onSurface),
            tooltip: 'About Sound Capsule',
            onPressed: () => _showAboutDialog(context, theme, retro),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _buildBody(state, notifier, theme, retro),
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
            RetroIcon('sound_capsule', size: 36, color: retro.accentGreen),
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

    final capsules = state.monthlyCapsules;
    if (capsules.isEmpty) {
      if (state.stats != null) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            _buildMonthSection(context, state.stats!, theme, retro),
          ],
        );
      }
      return _buildEmptyState(theme, retro);
    }

    final hasAnyData = capsules.any((c) => c.hasData);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final pillTop = ((availableHeight - 50) * _scrollProgress).clamp(10.0, availableHeight - 50);

        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: capsules.length + (hasAnyData ? 0 : 1),
              itemBuilder: (context, index) {
                if (index < capsules.length) {
                  final monthStats = capsules[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: _buildMonthSection(context, monthStats, theme, retro),
                  );
                } else {
                  return _buildListeningHintBanner(theme, retro);
                }
              },
            ),

            // Floating Scrollbar Tooltip Pill (matching reference image)
            if (capsules.length > 1 && _activeMonthLabel.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 50),
                right: 8,
                top: pillTop,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isScrolling ? 1.0 : 0.0,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (!_scrollController.hasClients) return;
                      final maxScroll = _scrollController.position.maxScrollExtent;
                      if (maxScroll <= 0) return;
                      final newTop = (pillTop + details.delta.dy).clamp(10.0, availableHeight - 50);
                      final newProgress = (newTop - 10) / (availableHeight - 60);
                      final targetOffset = newProgress * maxScroll;
                      _scrollController.jumpTo(targetOffset.clamp(0.0, maxScroll));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161B22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: retro.borderColor.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _activeMonthLabel,
                            style: RetroTypography.pixelBadge(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.unfold_more_rounded,
                            size: 15,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ── Month Capsule Section ──────────────────────────────────────────────────

  Widget _buildMonthSection(
    BuildContext context,
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month Header Row: "October 2026 ?" + Share
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Row(
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${_monthName(stats.periodStart.month)} ',
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: '${stats.periodStart.year}',
                      style: RetroTypography.pixelHeader(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openMonthDetails(context, stats, theme, retro),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    '?',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: RetroIcon(
                  'share',
                  size: 18,
                  color: theme.colorScheme.onSurface,
                ),
                tooltip: 'Share Capsule',
                onPressed: () => _openShareSheet(context, stats),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Time Listened Card (Accordion toggle)
        Builder(
          builder: (context) {
            final monthKey = '${stats.periodStart.year}-${stats.periodStart.month}';
            final isExpanded = _expandedMonths.contains(monthKey);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedMonths.remove(monthKey);
                      } else {
                        _expandedMonths.add(monthKey);
                      }
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
                        Row(
                          children: [
                            Text(
                              'Time listened',
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontSize: 9,
                              ),
                            ),
                            const Spacer(),
                            AnimatedRotation(
                              turns: isExpanded ? 0.25 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: RetroIcon(
                                'chevron_right',
                                size: 14,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${NumberFormat('#,###').format(stats.totalListeningTime.inMinutes)} minutes',
                          style: RetroTypography.pixelHeader(
                            color: retro.accentGreen,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Inline Accordion Graph
                if (isExpanded) ...[
                  const SizedBox(height: 8),
                  _buildTimeListenedAccordion(context, stats, theme, retro),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: 12),

        // Side-by-side Top Artist and Top Song cards
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTopArtistCard(context, stats, theme, retro),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTopSongCard(context, stats, theme, retro),
            ),
          ],
        ),
      ],
    );
  }

  // ── Time Listened Accordion ────────────────────────────────────────────────

  Widget _buildTimeListenedAccordion(
    BuildContext context,
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final dailyStats = stats.dailyStats;
    final totalMin = stats.totalListeningTime.inMinutes;
    final daysActive = stats.daysActive;
    final avgMin = daysActive > 0 ? (totalMin / daysActive).round() : 0;

    double maxMinutes = 0;
    for (final d in dailyStats) {
      if (d.totalTime.inMinutes > maxMinutes) {
        maxMinutes = d.totalTime.inMinutes.toDouble();
      }
    }
    if (maxMinutes <= 0) maxMinutes = 60;
    final effectiveMax = (maxMinutes * 1.15).ceilToDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          Text(
            '${_monthName(stats.periodStart.month)} ${stats.periodStart.year}',
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 13,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'You listened to music for '),
                TextSpan(
                  text: '$totalMin minutes',
                  style: RetroTypography.pixelHeader(
                    color: retro.accentGreen,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                TextSpan(
                  text: stats.period == CapsulePeriod.weekly ? ' this week.' : ' this month.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Daily average: $avgMin min',
            style: RetroTypography.pixelBadge(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 9,
            ),
          ),
          const SizedBox(height: 24),

          // Daily Listening Bar Chart
          SizedBox(
            height: 130,
            child: Stack(
              children: [
                // Horizontal lines: Max and Average
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final chartH = constraints.maxHeight - 20;
                      final avgY = chartH - (avgMin / effectiveMax * chartH).clamp(0.0, chartH);

                      return Stack(
                        children: [
                          // Max line at top
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 40,
                            child: Container(
                              height: 1,
                              color: Colors.white12,
                            ),
                          ),
                          // Average line with badge
                          if (avgMin > 0) ...[
                            Positioned(
                              top: avgY,
                              left: 0,
                              right: 40,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: Colors.white24,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$avgMin min',
                                      style: RetroTypography.pixelBadge(
                                        color: Colors.black,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          // Baseline
                          Positioned(
                            top: chartH,
                            left: 0,
                            right: 40,
                            child: Container(
                              height: 1,
                              color: Colors.white12,
                            ),
                          ),
                          // Right Y-axis labels
                          Positioned(
                            top: 0,
                            right: 0,
                            width: 36,
                            child: Text(
                              '${effectiveMax.toInt()}',
                              textAlign: TextAlign.right,
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                          Positioned(
                            top: chartH - 12,
                            right: 0,
                            width: 36,
                            child: Text(
                              '0',
                              textAlign: TextAlign.right,
                              style: RetroTypography.pixelBadge(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 8.5,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Bars
                Positioned(
                  left: 0,
                  right: 40,
                  top: 0,
                  bottom: 20,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int i = 0; i < (dailyStats.isNotEmpty ? dailyStats.length : 30); i++) ...[
                        Builder(
                          builder: (context) {
                            final stat = i < dailyStats.length ? dailyStats[i] : null;
                            final min = stat?.totalTime.inMinutes ?? 0;
                            final fraction = (min / effectiveMax).clamp(0.03, 1.0);

                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 1.0),
                                height: 110 * fraction,
                                decoration: BoxDecoration(
                                  color: min > 0
                                      ? retro.accentGreen
                                      : retro.accentGreen.withValues(alpha: 0.15),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // X-axis Day labels (1, 8, 15, 22, 29)
                Positioned(
                  left: 0,
                  right: 40,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1', style: RetroTypography.pixelBadge(color: Colors.white54, fontSize: 8.5)),
                      Text('8', style: RetroTypography.pixelBadge(color: Colors.white54, fontSize: 8.5)),
                      Text('15', style: RetroTypography.pixelBadge(color: Colors.white54, fontSize: 8.5)),
                      Text('22', style: RetroTypography.pixelBadge(color: Colors.white54, fontSize: 8.5)),
                      Text('29', style: RetroTypography.pixelBadge(color: Colors.white54, fontSize: 8.5)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top Artist Card ────────────────────────────────────────────────────────

  Widget _buildTopArtistCard(
    BuildContext context,
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final topArtist = stats.topArtists.firstOrNull;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopArtistsScreen(stats: stats),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
            Row(
              children: [
                Text(
                  'Top artist',
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 8.5,
                  ),
                ),
                const Spacer(),
                RetroIcon(
                  'chevron_right',
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              topArtist != null ? topArtist.name : 'No artist',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.primary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: RetroCircleAvatar(
                artPath: topArtist?.artPath,
                fallbackText: topArtist?.name,
                size: 114,
                accentColor: theme.colorScheme.primary,
                borderColor: retro.borderColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Song Card ──────────────────────────────────────────────────────────

  Widget _buildTopSongCard(
    BuildContext context,
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    final topSong = stats.topSongs.firstOrNull;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TopSongsScreen(stats: stats),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
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
            Row(
              children: [
                Text(
                  'Top song',
                  style: RetroTypography.pixelBadge(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 8.5,
                  ),
                ),
                const Spacer(),
                RetroIcon(
                  'chevron_right',
                  size: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              topSong != null ? topSong.name : 'No song',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RetroTypography.pixelHeader(
                color: retro.accentYellow,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                width: 114,
                height: 114,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: retro.borderColor,
                    width: 2.0,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: topSong?.artPath != null
                    ? RetroAlbumArt(
                        artPath: topSong!.artPath,
                        title: topSong.name,
                        artist: topSong.subtitle,
                        width: 114,
                        height: 114,
                        borderRadius: BorderRadius.zero,
                      )
                    : Container(
                        color: theme.colorScheme.surface,
                        alignment: Alignment.center,
                        child: RetroIcon(
                          'disc',
                          size: 38,
                          color: retro.accentYellow,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningHintBanner(ThemeData theme, RetroThemeTokens retro) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 8, bottom: 24),
      decoration: BoxDecoration(
        color: retro.cardColor,
        border: Border.all(color: retro.borderColor, width: retro.borderWidth),
        borderRadius: BorderRadius.circular(retro.borderRadius),
      ),
      child: Row(
        children: [
          RetroIcon('sound_capsule', size: 28, color: retro.accentGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Play tracks for 30+ seconds to fill your capsules with authentic listening metrics!',
              style: RetroTypography.pixelBadge(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontSize: 8.5,
              ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
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
            RetroCircleAvatar(
              artPath: artist.artPath,
              fallbackText: artist.name,
              size: 32,
              accentColor: rankColor,
              borderColor: retro.borderColor,
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

  // ── Month Breakdown Details Sheet ─────────────────────────────────────────

  void _openMonthDetails(
    BuildContext context,
    SoundCapsuleStats stats,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: true,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.88,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(
              top: BorderSide(color: retro.borderColor, width: retro.borderWidth),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Top Title Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: retro.cardColor,
                  border: Border(
                    bottom: BorderSide(color: retro.borderColor, width: retro.borderWidth),
                  ),
                ),
              child: Row(
                children: [
                  RetroIcon('sound_capsule', size: 16, color: retro.accentGreen),
                  const SizedBox(width: 8),
                  Text(
                    '${stats.periodLabel.toUpperCase()} DETAILS',
                    style: RetroTypography.pixelHeader(
                      color: theme.colorScheme.onSurface,
                      fontSize: 11,
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeroCard(stats, theme, retro),
                  const SizedBox(height: 16),
                  if (stats.topArtists.isNotEmpty) ...[
                    _buildTopArtistsCard(stats, theme, retro),
                    const SizedBox(height: 16),
                  ],
                  if (stats.topSongs.isNotEmpty) ...[
                    _buildTopSongsCard(stats, theme, retro),
                    const SizedBox(height: 16),
                  ],
                  if (stats.dailyStats.isNotEmpty) ...[
                    _buildActivityChartCard(stats, theme, retro),
                    const SizedBox(height: 16),
                  ],
                  _buildInsightsCard(stats, theme, retro),
                  const SizedBox(height: 20),
                  RetroButton(
                    label: 'SHARE THIS CAPSULE',
                    icon: const RetroIcon('share', size: 14, color: Colors.black),
                    backgroundColor: theme.colorScheme.primary,
                    textColor: theme.colorScheme.onPrimary,
                    onPressed: () {
                      Navigator.pop(context);
                      _openShareSheet(context, stats);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ── About Sound Capsule Dialog ────────────────────────────────────────────

  void _showAboutDialog(
    BuildContext context,
    ThemeData theme,
    RetroThemeTokens retro,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: retro.cardColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: retro.borderColor, width: retro.borderWidth),
          borderRadius: BorderRadius.circular(retro.borderRadius),
        ),
        title: Row(
          children: [
            RetroIcon('sound_capsule', size: 18, color: retro.accentGreen),
            const SizedBox(width: 8),
            Text(
              'SOUND CAPSULE',
              style: RetroTypography.pixelHeader(
                color: theme.colorScheme.onSurface,
                fontSize: 12,
              ),
            ),
          ],
        ),
        content: Text(
          'Sound Capsule creates a monthly musical snapshot of your listening habits, total minutes played, top artists, and most replayed tracks.\n\nPlay tracks for 30+ seconds to fill your capsules and explore your listening evolution month by month.',
          style: RetroTypography.retroMono(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          RetroButton(
            label: 'GOT IT',
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month - 1];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Share Modal with Preview, Theme Selector, and Actions
// ─────────────────────────────────────────────────────────────────────────────

class _ShareModal extends ConsumerStatefulWidget {
  final SoundCapsuleStats stats;
  final GlobalKey repaintKey;

  const _ShareModal({required this.stats, required this.repaintKey});

  @override
  ConsumerState<_ShareModal> createState() => _ShareModalState();
}

class _ShareModalState extends ConsumerState<_ShareModal> {
  RetroPaletteData? _selectedPalette;
  ShareAspectRatio _selectedRatio = ShareAspectRatio.story;
  bool _isCapturing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final retro = context.retro;
    final paletteState = ref.watch(paletteProvider);
    final isDark = theme.brightness == Brightness.dark;

    final defaultPalette = isDark
        ? RetroColors.getDarkPalette(paletteState.darkPaletteId)
        : RetroColors.getLightPalette(paletteState.lightPaletteId);

    final activePalette = _selectedPalette ?? defaultPalette;
    final allPalettes = [...RetroColors.darkPalettes, ...RetroColors.lightPalettes];

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
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
                RetroIcon('share', size: 16, color: theme.colorScheme.primary),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Live Card Preview: firmly bounded in 290px container with FittedBox
                  Container(
                    height: 290,
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: _selectedRatio.canonicalWidth,
                        height: _selectedRatio.canonicalHeight,
                        child: RepaintBoundary(
                          key: widget.repaintKey,
                          child: SoundCapsuleShareCard(
                            stats: widget.stats,
                            palette: activePalette,
                            aspectRatio: _selectedRatio,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Theme Palette Picker (App Palettes)
                  Text(
                    'APP PALETTE THEME',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 8.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: allPalettes.map((p) {
                      final isSelected = p.id == activePalette.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPalette = p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: p.card,
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : retro.borderColor,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: p.swatchColors
                                    .map((c) => Container(
                                          width: 9,
                                          height: 9,
                                          margin: const EdgeInsets.only(right: 2),
                                          decoration: BoxDecoration(
                                            color: c,
                                            border: Border.all(color: Colors.black26, width: 0.5),
                                          ),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                p.name,
                                style: RetroTypography.pixelBadge(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : p.textPrimary,
                                  fontSize: 8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Aspect Ratio Picker
                  Text(
                    'ASPECT RATIO',
                    style: RetroTypography.pixelBadge(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 8.5,
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
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'GENERATING IMAGE...',
                        style: RetroTypography.pixelBadge(
                          color: theme.colorScheme.onSurface,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ] else ...[
                    RetroButton(
                      label: 'SHARE IMAGE',
                      icon: const RetroIcon('share', size: 14, color: Colors.black),
                      backgroundColor: theme.colorScheme.primary,
                      textColor: theme.colorScheme.onPrimary,
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
        pixelRatio: 2.4,
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
        pixelRatio: 2.4,
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
